#include "common.S"
#include "asmconstants.h"

#define SAVE_SIZE              (8*8 + 1*CAP_BYTES + 8*CAP_BYTES)

.set noreorder

.globl objc_msgSend_plane
TYPE_DIRECTIVE(objc_msgSend_plane, @function)
objc_msgSend_plane:                           # aka objc_msgSend_plane_0
	daddiu     $t1, $t8, %got_disp(CDECL(objc_msgSend_plane_1))
	cfromptr   $c12, $c0, $t1
	cld        $t1, $zero, 0($c12)
	cgetpcc    $c12
	csetoffset $c12, $c12, $t1
	daddiu     $sp, $sp, -SAVE_SIZE           # Save return capability and
	                                          # Stack capability arguments for passing them to the system call
	csd        $a0, $sp, 0($c11)
	csd        $a1, $sp, 8($c11)
	csd        $a2, $sp, 16($c11)
	csd        $a3, $sp, 24($c11)
	csd        $a4, $sp, 32($c11)             # XXX: are these required or just temporary regs?
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

	csetoffset $c5, $c11, $sp                 # Pass in saved non-capability arguments
	daddiu     $t1, $sp, (64 + CAP_BYTES*1)
	cjalr      $c12, $c17                     # Call C function
	csetoffset $c6, $c11, $t1                 # Pass in saved capability arguments (delay slot)

	clc        $c17, $sp, 64($c11)
	cld        $v0, $sp, 0($c11)              # Retrieve the return registers' values
	cld        $v1, $sp, 8($c11)
	clc        $c3, $sp, (64 + CAP_BYTES*1)($c11)

	cjr        $c17                           # Return to caller
	daddiu     $sp, $sp, SAVE_SIZE            # Restore the stack pointer (delay slot)

#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
