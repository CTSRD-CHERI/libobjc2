/*-
 * Copyright (c) 2017 Lucian Paul-Trifu
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#define SAVE_SIZE     3*CAP_BYTES

# void sendMessage_0(id receiver, SEL selector, register_t *msg_noncap_args, __uintcap_t *msg_cap_args)

.set noreorder

.globl CDECL(sendMessage_0)
.hidden CDECL(sendMessage_0)
TYPE_DIRECTIVE(CDECL(sendMessage_0), @function)
CDECL(sendMessage_0):
0:
	cgetoffset $t9, $c12
	lui        $t8, %hi(%neg(%gp_rel(0b)))        # Load the GOT address that we use for relocations into $t8
	daddu      $t8, $t8, $t9
	daddiu     $t8, $t8, %lo(%neg(%gp_rel(0b)))
	daddiu     $t1, $t8, %got_disp(CDECL(objc_msgSend))

	cfromptr   $c12, $c0, $t1
	cld        $t1, $zero, 0($c12)
	cgetpcc    $c12
	csetoffset $c12, $c12, $t1

	daddiu     $sp, $sp, -SAVE_SIZE               # Push return address and message arguments pointers
	csc        $c17, $sp, 0($c11)
	csc        $c5, $sp, CAP_BYTES*1($c11)
	csc        $c6, $sp, CAP_BYTES*2($c11)

	cld        $a0, $zero, 0($c5)                 # Load non-capability arguments
	cld        $a1, $zero, 8($c5)
	cld        $a2, $zero, 16($c5)
	cld        $a3, $zero, 24($c5)
	cld        $a4, $zero, 32($c5)
	cld        $a5, $zero, 40($c5)
	cld        $a6, $zero, 48($c5)
	cld        $a7, $zero, 56($c5)

	clc        $c5, $zero, CAP_BYTES*2($c6)       # Load capability arguments
	clc        $c7, $zero, CAP_BYTES*4($c6)       # c3, c4 already contain receiver, selector.  They have
	clc        $c8, $zero, CAP_BYTES*5($c6)       # possibly been updated by the object plane
	clc        $c9, $zero, CAP_BYTES*6($c6)
	clc        $c10, $zero, CAP_BYTES*7($c6)

	cjalr      $c12, $c17                         # Call objc_msgSend
	clc        $c6, $zero, CAP_BYTES*3($c6)       # Load c6 in the delay slot (Overwrite)

    clc        $c17, $sp, 0($c11)                 # Pop return address and message arguments pointers
	clc        $c5, $sp, CAP_BYTES*1($c11)
	clc        $c6, $sp, CAP_BYTES*2($c11)
	daddiu     $sp, $sp, SAVE_SIZE

	csd        $v0, $zero, 0($c5)                 # Save the return registers' values, reusing the slots for
	csd        $v1, $zero, 8($c5)                 # the message arguments passed initially
	cjr        $c17                               # Return to caller
	csc        $c3, $zero, 0($c6)
