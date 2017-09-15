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

#ifndef __OBJC_OBJECTPLANE_H_INCLUDED__
#include <objc/runtime.h>

struct retval_regs {
	register_t v0, v1;
	__uintcap_t c3;
};

#ifdef __OBJC__
#import "Object.h"

@interface ObjectPlane : Object
{
	@private
	void * __capability plane_seal;
	Plane plane_sysref;
}
+ (id)alloc;
- (void)dealloc;
- (id)init;
- (id)allocObject :(Class)cls;

// If you change the sendMessage signature, update it in the macro and
// typedef below too
- (struct retval_regs)sendMessage :(id)receiver :(SEL)selector :(id)senders_plane
                  :(register_t)a0 :(register_t)a1 :(register_t)a2 :(register_t)a3
                  :(register_t)a4 :(register_t)a5 :(register_t)a6 :(register_t)a7
                  :(__uintcap_t)c3 :(__uintcap_t)c4 :(__uintcap_t)c5 :(__uintcap_t)c6
                  :(__uintcap_t)c7 :(__uintcap_t)c8 :(__uintcap_t)c9 :(__uintcap_t)c10;

- (int)sum :(int)a0 :(int)a1 :(int)a2 :(int)a3
           :(int)a4 :(int)a5 :(int)a6 :(int)a7;

@end
#else

// sendMessage arguments denoted by the colons
#define sendMessage_sel_name    "sendMessage:::::::::::::::::::"

typedef struct retval_regs (*objc_msgSend_stret_sendMessage_t)(id, SEL,
					        // sendMessage arguments below
                            id, SEL, id,
                            register_t, register_t, register_t, register_t,
                            register_t, register_t, register_t, register_t,
                            __uintcap_t, __uintcap_t, __uintcap_t, __uintcap_t,
                            __uintcap_t, __uintcap_t, __uintcap_t, __uintcap_t);
#endif  /* __OBJC__ */
#endif  /* __OBJC_OBJECTPLANE_H_INCLUDED__ */
