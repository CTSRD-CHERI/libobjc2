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


/**
 * This file contains the privileged/supervisor side for object planes.  In a CheriOS-based
 * environment, this would be factored into the microkernel as a kernel object.
 */

struct plane {
	id plane_obj;
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

	// Allocate a new type capability and set it in the plane object provided.
	// This assigns plane_id = plane_type and uses ID as index.  This would ensure
	// a linear type range or use an other fast lookup other than indexing.
	void *__capability pseal = cheri_type_alloc();
	printf("plane_create() "); CHERI_CAP_PRINT(pseal);
	uintmax_t pid = cheri_getbase(pseal) + cheri_getoffset(pseal);
	assert(pid < MAX_PLANES);
	object_setInstanceVariable(plane_obj, "plane_seal", &pseal);

	// Allocate a new plane
	planes[pid].plane_obj = plane_obj;
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
	assert(cheri_gettype(pref) == cheri_gettype(plane_ref_seal));
	pref = cheri_unseal(pref, plane_ref_seal);
	int pid = cheri_getoffset(pref);

	// Invalidate plane.  TODO: decrement plane_count and adjust array
	assert(pid < MAX_PLANES);
	struct plane *plane = &planes[pid];
	assert(plane->valid == YES);
	plane->valid = NO;
}

// XXX: Is this reentrant? e.g. sendMessage could look at the sealed sender's plane, retriggering the
// plane changing mechanism
id objc_msgSend_plane_1(id receiver, SEL _cmd,
                        register_t *msg_noncap_args, __uintcap_t *msg_cap_args)
{
	assert(cheri_getsealed(receiver) != 0);

	// Seal unsealed argument object references using the current plane's seal.
	void * __capability *pcur_seal_ptr;
	object_getInstanceVariable(plane_cur->plane_obj, "plane_seal", (void**)&pcur_seal_ptr);
	void * __capability pcur_seal = *pcur_seal_ptr;
	assert((cheri_getperm(pcur_seal) & CHERI_PERM_SEAL) != 0);
	for (int i = 0; i < 8; i++)
		// XXX: Find and only seal Objective-C object references
		if (cheri_gettag(msg_cap_args[i]) != 0 && cheri_getsealed(msg_cap_args[i]) == 0)
			msg_cap_args[i] = (__uintcap_t)cheri_seal(msg_cap_args[i], pcur_seal);

	// Get the receiver's plane
	uintmax_t ptype = cheri_gettype(receiver);
	assert(ptype < MAX_PLANES);
	struct plane *receivers_plane = &planes[ptype];

	// Change the current plane to the receiver's plane
	struct plane *senders_plane = plane_cur;
	plane_cur = receivers_plane;
	assert(plane_cur->valid == YES);

	// Ask the receiver's plane(s) to send the message.  Copy over the arguments.
	// TODO: senders_plane->plane_obj should be sealed
	SEL send = sel_getUid("sendMessage:::::::::::::::::::");
	assert(send != NULL);
	printf("About to sendMessage\n");
	objc_msgSend_sendMessage_t objc_msgSend_sendMessage =
	                                   (objc_msgSend_sendMessage_t)objc_msgSend;
	id ret = objc_msgSend_sendMessage(receivers_plane->plane_obj, send,
	                                  receiver, _cmd, senders_plane->plane_obj,
	                                  msg_noncap_args[0], msg_noncap_args[1],
						              msg_noncap_args[2], msg_noncap_args[3],
	                                  msg_noncap_args[4], msg_noncap_args[5],
						              msg_noncap_args[6], msg_noncap_args[7],
	                                  msg_cap_args[0], msg_cap_args[1],
						              msg_cap_args[2], msg_cap_args[3],
	                                  msg_cap_args[4], msg_cap_args[5],
						              msg_cap_args[6], msg_cap_args[7]);

	// Change the current plane back to the sender's plane
	plane_cur = senders_plane;

	// Return the result of the message
	return ret;
}
