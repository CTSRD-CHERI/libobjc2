.set noreorder

.macro dump_and_crash reg
nop
move   $a0, \reg
ld     $25, %got_disp(logInt)($t8) 
jalr   $25
nop
lw     $zero, ($zero)
.endm
#define CAP_BYTES (_MIPS_SZCAP/8)
#if _MIPS_SZCAP == 256
#define CAP_SHIFT 5
#elif _MIPS_SZCAP == 128
#define CAP_SHIFT 4
#elif _MIPS_SZCAP == 64
#define CAP_SHIFT 3
#else
#error Unknown capability size
#endif

#ifndef __mips_soft_float
#error Hard-float not yet implemented for CHERI!
#else
#define SAVE_SIZE      ((9*CAP_BYTES)+(8*8)+(CAP_BYTES))
#endif


.macro MSGSEND receiver, sel
0:
	.cfi_startproc                          # Start emitting unwind data.  We
	                                        # don't actually care about any of
	                                        # the stuff except the slow call,
	                                        # because that's the only one that
	                                        # can throw.
	cgetoffset $t9, $c12
	lui        $t8, %hi(%neg(%gp_rel(0b)))  # Load the GOT address that we use for relocations into $t8
	daddu      $t8, $t8, $t9
	cbtu       \receiver,  6f
	daddiu     $t8, $t8, %lo(%neg(%gp_rel(0b)))

	clc        $c12, $zero, 0(\receiver)    # Load the class.  By this
	                                        # point, we have a non-nil capability to a large object.
1:
	clc        $c13, $zero, 0(\sel)         # Load the selector into $t1
	cgetoffset $t1, $c13
	clc        $c12, $zero, DTABLE_OFFSET($c12) # Load the dtable from the class
	clw        $t2, $zero, SHIFT_OFFSET($c12) # Load the shift (dtable size (uint32_t)
	                                        # $c12 = dtable, $t1 = sel index, $t2 = dtable_size

	beq        $0, $t2, 3f                  # If this is a small dtable, jump to the small dtable handlers
	daddi      $v0, $t2, -8

	beq        $0, $v0, 2f
	lui        $t2, 0x00ff                  # The mask for a big dtable won't fit in an and immediate

	and        $t2, $t2, $t1                # mask the selector
	srl        $t2, $t2, (16-CAP_SHIFT)     # Right shift 16, but then left shift by pointer size
	clc        $c12, $t2, DATA_OFFSET($c12) # Load the next layer of dtable
2:	                                        # dtable16:
	andi       $t2, $t1, 0xff00             # mask the selector
	dsrl       $t2, $t2, (8-CAP_SHIFT)      # Right shift 8, but then left shift by pointer size
	clc        $c12, $t2, DATA_OFFSET($c12) # Load the next layer of dtable
3:	                                        # dtable8:
	andi       $t2, $t1, 0xff               # mask the selector
	dsll       $t2, $t2, CAP_SHIFT          # Left shift by pointer size
	clc        $c12, $t2, DATA_OFFSET($c12) # Load the next layer of dtable


	cbtu       $c12, 5f                      # Nil slot - invoke some kind of forwarding mechanism
	nop

	clc        $c12, $zero, SLOT_OFFSET($c12)
	cjr        $c12
	nop
4:	                                        # returnNil:
	                                        # All of the return registers are
	                                        # callee-save, so we can
	                                        # return 0 in both in the same code:
	cfromptr   $c3, $c0, $zero              # Return null as a capability
	daddi      $v0, $0, 0                   # Return 0 as an integer
	cjr        $c17
	daddi      $v1, $0, 0
5:                                          # slowSend:
	# Load the address of the slow lookup function now, so that we don't get
	# pipeline stalls on the jump.  This is more important on CHERI than proper
	# MIPS implementations.
	# Note: A better linker ought to be able to turn this into a single
	# jump-immediate, so revisit this decision later...

	daddiu     $t1, $t8, %got_disp(CDECL(slowMsgLookup))
	cfromptr   $c12, $c0, $t1
	cld        $t1, $zero, 0($c12)
	cgetpcc    $c12
	csetoffset $c12, $c12, $t1

	daddiu     $sp, $sp, -SAVE_SIZE             # We need to preserve all registers that may contain arguments:

	csd        $a0, $sp, 0($c11)
	csd        $a1, $sp, 8($c11)
	csd        $a2, $sp, 16($c11)
	csd        $a3, $sp, 24($c11)
	csd        $a4, $sp, 32($c11)
	csd        $a5, $sp, 40($c11)
	csd        $a6, $sp, 48($c11)
	csd        $a7, $sp, 56($c11)

	csc        $c17, $sp, 64($c11)
	csc        $c3, $sp, (64 + CAP_BYTES*1)($c11)
	csc        $c4, $sp, (64 + CAP_BYTES*2)($c11)
	csc        $c5, $sp, (64 + CAP_BYTES*3)($c11)
	csc        $c6, $sp, (64 + CAP_BYTES*4)($c11)
	csc        $c7, $sp, (64 + CAP_BYTES*5)($c11)
	csc        $c8, $sp, (64 + CAP_BYTES*6)($c11)
	csc        $c9, $sp, (64 + CAP_BYTES*7)($c11)
	csc        $c10, $sp, (64 + CAP_BYTES*8)($c11)

	# We're (potentially) modifying the self argument with the lookup.  Use the
	# address of the stack save slot for the address so that when we reload it
	# we get the old or new version automatically.  Note that we must reload it
	# anyway, because argument registers are not guaranteed to be preserved
	# across calls.
.ifc "\receiver", "$c3"
	daddiu     $t1, $sp, (64 + CAP_BYTES*1)   # replace self with &self in $c3
	csetoffset $c3, $c11, $t1
.else
	daddiu     $t1, $sp, (64 + CAP_BYTES*2)   # replace self with &self in $c3
	cmove      $c4, $c5                       # replace self with _cmd in $c4
.endif

	.cfi_def_cfa_offset SAVE_SIZE
	.cfi_offset 81, (64 - SAVE_SIZE)
	cjalr      $c12, $c17                     # Call the slow lookup function
	csetoffset $c3, $c11, $t1

	cmove      $c12, $c3                      # Move the return value to $c12 for use with the call


	cld        $a0, $sp, 0($c11)
	cld        $a1, $sp, 8($c11)
	cld        $a2, $sp, 16($c11)
	cld        $a3, $sp, 24($c11)
	cld        $a4, $sp, 32($c11)
	cld        $a5, $sp, 40($c11)
	cld        $a6, $sp, 48($c11)
	cld        $a7, $sp, 56($c11)
	
	clc        $c17, $sp, 64($c11)
	clc        $c3, $sp, (64 + CAP_BYTES*1)($c11)
	clc        $c4, $sp, (64 + CAP_BYTES*2)($c11)
	clc        $c5, $sp, (64 + CAP_BYTES*3)($c11)
	clc        $c6, $sp, (64 + CAP_BYTES*4)($c11)
	clc        $c7, $sp, (64 + CAP_BYTES*5)($c11)
	clc        $c8, $sp, (64 + CAP_BYTES*6)($c11)
	clc        $c9, $sp, (64 + CAP_BYTES*7)($c11)
	clc        $c10, $sp, (64 + CAP_BYTES*8)($c11)


	cjr        $c12                          # Tail-call the method
	daddiu     $sp, $sp, SAVE_SIZE           # Restore the stack pointer (delay slot)

6:	                                         # smallObject:
	cfromptr   $c12, $c0, $zero
	ceq        $t1, $c12, \receiver
	bne        $t1, $zero, 4b
	daddiu     $t1, $t8, %got_disp(SmallObjectClasses) # Delay slot, ignored in 4:
	cfromptr   $c12, $c0, $t1
	cld        $t1, $zero, 0($c12)
	cfromptr   $c12, $c0, $t1
	cgetoffset $t2, $c3
	andi       $t2, $t2, 7                  # Note: We could have a lot more small objects!
	dsll       $t2, $t2, CAP_SHIFT
	b          1b
	clc        $c12, $t2, 0($c12)              # Delay slot, load the class into $c12
	.cfi_endproc
.endm
.globl CDECL(objc_msgSend)
TYPE_DIRECTIVE(CDECL(objc_msgSend), @function)
.globl CDECL(objc_msgSend_fpret)
TYPE_DIRECTIVE(CDECL(objc_msgSend_fpret), @function)
CDECL(objc_msgSend_fpret):
CDECL(objc_msgSend):
	MSGSEND $c3, $c4
.globl CDECL(objc_msgSend_stret)
TYPE_DIRECTIVE(CDECL(objc_msgSend_stret), @function)
CDECL(objc_msgSend_stret):
	MSGSEND $c4, $c5
