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

#import <objc/ObjectPlane.h>

/**
 * This file implements a test for the CHERI Object Planes.
 *
 * See ctsrd/reports/20170929-lmp53-internship-report.
 */

int main()
{
	printf("About to alloc plane object\n");
	id plane = [ObjectPlane alloc];
	printf("Alloc'd plane object %p\n", plane);
	id ret = [plane init];
	printf("Init'd plane object\n");
	assert(ret == plane);
	assert([plane sum :1 :1 :2 :3 :5 :8 :13 :21] == 55 - 1);

	id plane_nested = [plane allocObject :objc_getRequiredClass("ObjectPlane")];
	assert(plane_nested != nil);
	printf("Alloc'd nested plane object %p\n", plane_nested);

	[plane_nested dealloc];
	printf("Dealloc'd nested plane object %p\n", plane_nested);
	[plane dealloc];
	printf("Dealloc'd plane object %p\n", plane);

	return 0;
}
