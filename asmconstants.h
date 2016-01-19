#ifdef __CHERI_PURE_CAPABILITY__
#define SIZEOF_PTR     (_MIPS_SZCAP / 8)
#define DTABLE_OFFSET  (SIZEOF_PTR * 6)
#define SMALLOBJ_BITS  3
#define SHIFT_OFFSET   0
#define DATA_OFFSET    (SIZEOF_PTR)
#define SLOT_OFFSET    (4 * SIZEOF_PTR)
#elif defined(__LP64__)
#define DTABLE_OFFSET  64
#define SMALLOBJ_BITS  3
#define SHIFT_OFFSET   0
#define DATA_OFFSET    8
#define SLOT_OFFSET    32
#else
#define DTABLE_OFFSET  32
#define SMALLOBJ_BITS  1
#define SHIFT_OFFSET   0
#define DATA_OFFSET    8
#define SLOT_OFFSET    16
#endif
#define SMALLOBJ_MASK  ((1<<SMALLOBJ_BITS) - 1)
