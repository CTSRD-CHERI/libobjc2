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
