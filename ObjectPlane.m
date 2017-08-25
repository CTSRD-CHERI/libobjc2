#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include <machine/cherireg.h>
#include <cheri/cheri_type.h>
#include <cheri/cheric.h>

#import "objc/runtime.h"
#import "objc/ObjectPlane.h"

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
 * This file implements the Objective-C ObjectPlane assuming a trusted intermediary that provides
 * the object reference protection.
 */

@implementation ObjectPlane

/**
 * Allocates an object plane within the Objective-C runtime.  Returns a sealed ObjectPlane reference.
 * XXX: Note that the first alloc call is reentered via plane_create().
 */
+ (id)alloc
{
	// Allocate the plane object
	void * __capability plane_obj = calloc(1, class_getInstanceSize(self));
	printf("calloc(1, %zx): %p\n", class_getInstanceSize(self), plane_obj);
	if (plane_obj == NULL)
		return nil;
	object_setClass(plane_obj, self);

	// Ask the system to create a plane.  This should be a system call
	Plane plane_sysref = plane_create(plane_obj);
	object_setInstanceVariable(plane_obj, "plane_sysref", &plane_sysref);

	// The plane object is part of the plane represented.  Seal the plane reference using
	// the sealing capability alloc'd by the system
	__uintcap_t *plane_seal_ptr;
	object_getInstanceVariable(plane_obj, "plane_seal", (void**)&plane_seal_ptr);
	__uintcap_t plane_seal = *plane_seal_ptr;
	return cheri_seal(plane_obj, plane_seal);
}

- (void)dealloc
{
	printf("%s() self=%p\n", __func__, self);
	// Ask the system to destroy the plane
	plane_destroy(plane_sysref);

	// Free calloc'd memory.  XXX: Is free available for CHERI caps?
	free(self);
}

/**
 * Initialize the plane object.
 */
- (id)init
{
	printf("%s() self=%p\n", __func__, self);
	// self does not need sealing because init() is a normal method call whose return
	// values are sealed upon exit from the plane
	return self;
}

/**
 * Allocate an object within this plane.  Returns a sealed object reference.
 *
 * XXX: can I receive the allocating method as argument (selector? HOM?)
 */
- (id)allocObject: (Class)class
{
	id obj = [class alloc];
	if (cheri_gettag(obj) != 0 && cheri_getsealed(obj) == 0)
		obj = cheri_seal(obj, plane_seal);
	return obj;
}

// TODO: echo() method test

/**
 * Assumes a message that returns values in registers
 */
void sendMessage_0(id receiver, SEL selector, register_t *msg_noncap_args, __uintcap_t *msg_cap_args);


/**
 * Send a message to an object within this object plane.  Copy over the result
 * upon return.
 *
 * Assumes a message that returns values in registers
 */
- (struct retval_regs)sendMessage :(id)receiver :(SEL)selector :(id)senders_plane
                  :(register_t)a0 :(register_t)a1 :(register_t)a2 :(register_t)a3
				  :(register_t)a4 :(register_t)a5 :(register_t)a6 :(register_t)a7
				  :(__uintcap_t)c3 :(__uintcap_t)c4 :(__uintcap_t)c5 :(__uintcap_t)c6
				  :(__uintcap_t)c7 :(__uintcap_t)c8 :(__uintcap_t)c9 :(__uintcap_t)c10
{
	printf("%s(receiver= _, selector=%s)\n", __func__, sel_getName(selector));
	register_t msg_noncap_args[8] = {a0, a1, a2, a3, a4, a5, a6, a7};
	__uintcap_t msg_cap_args[8] = {c3, c4, c5, c6, c7, c8, c9, c10};

	// Unseal receiver and argument object refs that belong to this plane.
	uintmax_t ptype = cheri_getbase(plane_seal) + cheri_getoffset(plane_seal);
	assert(cheri_gettype(receiver) == ptype);
	receiver = cheri_unseal(receiver, plane_seal);
	printf("\treceiver=%s\n", object_getClassName(receiver));
	for (int i = 0; i < 8; i++)
		// XXX: Find and only unseal Objective-C object references
		if (cheri_getsealed(msg_cap_args[i]) != 0 && cheri_gettype(msg_cap_args[i]) == ptype)
			msg_cap_args[i] = (__uintcap_t)cheri_unseal(msg_cap_args[i], plane_seal);

	// Hook the enter method TODO
	//[self doEnter :&receiver :&selector :senders_plane :msg_noncap_args :msg_cap_args];

	// Send message to the receiving object
	sendMessage_0(receiver, selector, msg_noncap_args, msg_cap_args);
	register_t *msg_noncap_retval = msg_noncap_args;
	__uintcap_t *msg_cap_retval = msg_cap_args;
	struct retval_regs ret = {.v0 = msg_noncap_retval[0],
	                          .v1 = msg_noncap_retval[1],
	                          .c3 = msg_cap_args[0]};
	printf("sendMessage_0:\n"
	       "\tret.noncap_one=%lx\n"
	       "\tret.noncap_other=%lx\n\t", ret.v0, ret.v1);
	CHERI_CAP_PRINT(ret.c3);

	// Hook the exit method TODO
	//[self doExit :receiver :selector :senders_plane];

	// Return the result of the message
	return ret;
}

@end
