#include <objc/runtime.h>

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
- (id)init: (BOOL)nest;
- (id)allocObject: (Class)cls;
// If you change the sendMessage signature, update it below too
- (id)sendMessage :(id)receiver :(SEL)selector :(id)senders_plane
                  :(register_t)a0 :(register_t)a1 :(register_t)a2 :(register_t)a3
                  :(register_t)a4 :(register_t)a5 :(register_t)a6 :(register_t)a7
                  :(__uintcap_t)c3 :(__uintcap_t)c4 :(__uintcap_t)c5 :(__uintcap_t)c6
                  :(__uintcap_t)c7 :(__uintcap_t)c8 :(__uintcap_t)c9 :(__uintcap_t)c10;

@end
#else
typedef id (*objc_msgSend_sendMessage_t)(id, SEL,
					    // sendMessage arguments below
                        id, SEL, id,
                        register_t, register_t, register_t, register_t,
                        register_t, register_t, register_t, register_t,
                        __uintcap_t, __uintcap_t, __uintcap_t, __uintcap_t,
                        __uintcap_t, __uintcap_t, __uintcap_t, __uintcap_t);
#endif  /* __OBJC__ */
