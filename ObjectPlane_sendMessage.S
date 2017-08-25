#include "common.S"
#include "asmconstants.h"

#if defined(__CHERI_PURE_CAPABILITY__)
#include "ObjectPlane_sendMessage.cheri.s"
#else
#warning ObjectPlane.sendMessage_0() not implemented for your ABI
#endif
#ifdef __ELF__
.section .note.GNU-stack,"",%progbits
#endif
