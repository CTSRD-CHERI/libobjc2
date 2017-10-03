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

#include <stdio.h>        // printf
#include <assert.h>

#include <machine/cherireg.h>
#include <machine/sysarch.h>
#include <cheri/cheric.h>
#include <cheri/cheri_type.h>

#include "objc/runtime.h"
#include "objc/ObjectPlane.h"       // sendMessage_t

#define MAX_PLANES 10
#define	CHERI_CAP_PRINT(cap) do {					\
	printf(#cap " v:%lu s:%lu p:%08jx b:%016jx l:%016jx o:%jx t:%jx\n",	\
	    (uintmax_t)cheri_gettag(cap),				\
	    (uintmax_t)cheri_getsealed(cap),				\
	    (uintmax_t)cheri_getperm(cap),				\
	    (uintmax_t)cheri_getbase(cap),				\
	    (uintmax_t)cheri_getlen(cap),				\
	    (uintmax_t)cheri_getoffset(cap),				\
	    (uintmax_t)cheri_gettype(cap));				\
} while (0)

#define OBJECT_GET_IVAR(obj, ivar_type, ivar_name) ({ \
	ivar_type *ivar_name##_ptr;   \
	object_getInstanceVariable((obj), #ivar_name, (void**)&ivar_name##_ptr);   \
	*ivar_name##_ptr; })


/**
 * This file contains the trusted intermediary for object planes.  In a secure
 * implementation the intermediary would be protected.
 *
 * In a CheriOS-based environment, this would be factored into the microkernel
 * as a kernel object that implements the plane-related system calls.
 *
 * See ctsrd/reports/ctsrd/reports/20170929-lmp53-internship-report.
 */

struct plane {
	id plane_obj;
	id plane_obj_sealed;
	BOOL valid;
};

static struct plane planes[MAX_PLANES];
static int plane_count = 0;
static struct plane *plane_cur;

static void * __capability plane_ref_seal;

static int init_entered = 0;


static void plane_init(void)
{
	printf("plane_init()\n");
	// Required due to the ObjectPlane.alloc dependency: plane_init() cannot be a
	// C-constructor because ObjC classes are not loaded at that point.  plane_create()
	// checks this flag and calls plane_init() instead.
	init_entered = 1;

	// Initialize type used for system plane references
	plane_ref_seal = cheri_type_alloc();
	printf("cheri_type_alloc() "); CHERI_CAP_PRINT(plane_ref_seal);

	// Allocate the global plane
	id objplane_cls = objc_getClass("ObjectPlane");
	assert(objplane_cls != nil);
	SEL alloc = sel_getUid("alloc");
	id plane = objc_msgSend(objplane_cls, alloc);
	assert(plane != nil);
	assert(plane_count == 1);

	// Set the initial plane to the global plane
	uintmax_t ptype = cheri_gettype(plane);
	plane_cur = &planes[ptype];
}

Plane plane_create(id plane_obj)
{
	if (init_entered == 0)
		plane_init();

	assert(plane_count < MAX_PLANES);
	assert(cheri_getsealed(plane_obj) == 0);

	// Allocate a new type capability and set it in the plane object provided.
	// This assigns plane_id = plane_type and uses ID as index.  This would ensure
	// a linear type range or would use an other fast lookup other than indexing.
	void *__capability pseal = cheri_type_alloc();
	printf("plane_create() "); CHERI_CAP_PRINT(pseal);
	uintmax_t pid = cheri_getbase(pseal) + cheri_getoffset(pseal);
	assert(pid < MAX_PLANES);
	object_setInstanceVariable(plane_obj, "plane_seal", &pseal);

	// Allocate a new plane
	planes[pid].plane_obj = plane_obj;
	planes[pid].plane_obj_sealed = cheri_seal(plane_obj, pseal);
	planes[pid].valid = YES;
	plane_count++;

	// Return a plane system reference
	Plane pref = cheri_setoffset(plane_ref_seal, pid);
	pref = cheri_seal(pref, plane_ref_seal);
	return pref;
}

void plane_destroy(Plane pref)
{
	// Extract plane id from reference
	uintmax_t pref_type = cheri_getbase(plane_ref_seal) + cheri_getoffset(plane_ref_seal);
	assert(cheri_gettype(pref) == pref_type);
	pref = cheri_unseal(pref, plane_ref_seal);
	uintmax_t pid = cheri_getoffset(pref);

	// Destroy the plane.  This would deallocate the plane object
	assert(pid < MAX_PLANES);
	struct plane *plane = &planes[pid];
	assert(plane->valid == YES);
	plane->valid = NO;
	plane_count--;
}

/**
 * Accepts pointers to arrays of argument registers to simplify the ABI dependency.
 * Assumes a message that returns values in registers.
 */
void objc_msgSend_plane_1(id receiver, SEL _cmd,
                        register_t *msg_noncap_args, __uintcap_t *msg_cap_args)
{
	assert(cheri_getsealed(receiver) != 0);

	// Save the sender's plane.  Saving would need an alternative in presence of
	// more than a single context.
	struct plane *senders_plane = plane_cur;
	assert(senders_plane->valid == YES);

	// Seal unsealed argument object references using the sender's plane seal
	void *__capability splane_seal = OBJECT_GET_IVAR(senders_plane->plane_obj,
	                                                 void *__capability, plane_seal);
	assert((cheri_getperm(splane_seal) & CHERI_PERM_SEAL) != 0);
	for (int i = 0; i < 8; i++)
		// XXX: Find and only seal Objective-C object references
		if (cheri_gettag(msg_cap_args[i]) != 0 && cheri_getsealed(msg_cap_args[i]) == 0)
			msg_cap_args[i] = (__uintcap_t)cheri_seal(msg_cap_args[i], splane_seal);

	// Get the receiver's plane
	uintmax_t ptype = cheri_gettype(receiver);
	assert(ptype < MAX_PLANES);
	struct plane *receivers_plane = &planes[ptype];

	// Change the current plane to the receiver's plane
	assert(receivers_plane->valid == YES);
	plane_cur = receivers_plane;

	// Ask the receiver's plane(s) to send the message.  Copy over the arguments.
	// The message sending would be scheduled for a different context.
	SEL send = sel_getUid(sendMessage_sel_name);
	assert(send != NULL);
	printf("About to sendMessage\n");
	objc_msgSend_stret_sendMessage_t objc_msgSend_stret_sendMessage =
	                       (objc_msgSend_stret_sendMessage_t)objc_msgSend_stret;
	struct retval_regs ret = objc_msgSend_stret_sendMessage(
	                                  receivers_plane->plane_obj, send,
	                                  receiver, _cmd, senders_plane->plane_obj_sealed,
	                                  msg_noncap_args[0], msg_noncap_args[1],
						              msg_noncap_args[2], msg_noncap_args[3],
	                                  msg_noncap_args[4], msg_noncap_args[5],
						              msg_noncap_args[6], msg_noncap_args[7],
	                                  msg_cap_args[0], msg_cap_args[1],
						              msg_cap_args[2], msg_cap_args[3],
	                                  msg_cap_args[4], msg_cap_args[5],
						              msg_cap_args[6], msg_cap_args[7]);
	printf("objc_msgSend_stret_sendMessage():\n"
	       "\tret.noncap_one=%lx\n"
	       "\tret.noncap_other=%lx\n\t", ret.v0, ret.v1);
	CHERI_CAP_PRINT(ret.c3);

	// Seal unsealed return object reference using the receiver's plane seal
	// XXX: Find and only seal Objective-C object references
	void *__capability rplane_seal = OBJECT_GET_IVAR(receivers_plane->plane_obj,
	                                                 void *__capability, plane_seal);
	assert((cheri_getperm(rplane_seal) & CHERI_PERM_SEAL) != 0);
	if (cheri_gettag(ret.c3) != 0 && cheri_getsealed(ret.c3) == 0)
		ret.c3 = (__uintcap_t)cheri_seal(ret.c3, rplane_seal);

	// Change the current plane back to the sender's plane.
	plane_cur = senders_plane;

	// Return the result of the message
	register_t *msg_noncap_retval = msg_noncap_args;
	__uintcap_t *msg_cap_retval = msg_cap_args;
	msg_noncap_retval[0] = ret.v0;
	msg_noncap_retval[1] = ret.v1;
	msg_cap_retval[0] = ret.c3;
}
