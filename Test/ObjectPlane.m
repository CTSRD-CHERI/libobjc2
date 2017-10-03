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

#include <stdio.h>
#include <assert.h>

#include <cheri/cheric.h>

#import <objc/ObjectPlane.h>

/**
 * This file implements a test for the CHERI Object Planes.
 *
 * See ctsrd/reports/20170929-lmp53-internship-report.
 */


@interface ExclusivePlane : ObjectPlane
- (id)getClue;
@end

@interface SelectPlane : ObjectPlane
- (int)speak;
- (id)getClue :(ExclusivePlane*)exp :(int)goodness;
@end


@implementation ExclusivePlane : ObjectPlane

- (void)doEnter :(id*)receiver :(SEL*)selector :(ObjectPlane*)senders_plane
                :(register_t*)msg_noncap_args :(__uintcap_t*)msg_cap_args
{
	if ([senders_plane speak] != 31337)
		*receiver = nil;
}

- (void)doExit :(id)receiver :(SEL)selector :(ObjectPlane*)senders_plane
               :(struct retval_regs*)ret
{
	if ([senders_plane speak] != 31337) {
		ret->v0 = 0;
		ret->v1 = 0;
		ret->c3 = 0;
	}
}

- (id)getClue
{
	return self;
}
@end


@implementation SelectPlane : ObjectPlane

- (int)speak
{
	return 31337;
}

- (id)getClue :(ExclusivePlane*)exp :(int)goodness
{
	return [exp getClue];
}
@end


int main()
{
	printf("About to alloc plane object\n");
	id plane = [ObjectPlane alloc];
	printf("Alloc'd plane object %p\n", plane);
	assert(cheri_getsealed(plane) != 0);
	id ret = [plane init];
	printf("Init'd plane object\n");
	assert(ret == plane);
	assert([plane sum :1 :1 :2 :3 :5 :8 :13 :21] == 55 - 1);

	printf("About to alloc object within plane\n");
	id plane_nested = [plane allocObject :objc_getRequiredClass("ObjectPlane")];
	assert(plane_nested != nil);
	printf("Alloc'd nested plane object %p\n", plane_nested);
	[plane_nested dealloc];
	printf("Dealloc'd nested plane object %p\n", plane_nested);
	[plane dealloc];
	printf("Dealloc'd plane object %p\n", plane);

	id exp = [ExclusivePlane alloc];
	id selp = [SelectPlane alloc];
	printf("About to ask ExclusivePlane for clue\n");
	id clue = [exp getClue];
	printf("Asked ExclusivePlane for clue: got %p\n", clue);
	assert(clue == nil);
	clue = [selp getClue :exp :1];
	printf("Asked SelectPlane for clue: got %p\n", clue);
	assert(clue == exp);

	return 0;
}
