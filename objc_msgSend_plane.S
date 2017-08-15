#include "common.S"
#include "asmconstants.h"
# TODO: This has no point, planes exist only on CHERI.  This is a system call, so
# it has its own ABI regardless of the C-language ABI.
#if defined(__CHERI_PURE_CAPABILITY__)
#include "objc_msgSend_plane.cheri.S"
#else
#warning objc_msgSend_plane() not implemented for your architecture
#endif
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
