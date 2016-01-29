// On some platforms, we need _GNU_SOURCE to expose asprintf()
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/mman.h>
#include "objc/runtime.h"
#include "objc/blocks_runtime.h"
#include "blocks_runtime.h"
#include "lock.h"
#include "visibility.h"

#ifndef __has_builtin
#define __has_builtin(x) 0
#endif
#if __has_builtin(__builtin___clear_cache)
#	define clear_cache __builtin___clear_cache
#else
void __clear_cache(void* start, void* end);
#	define clear_cache __clear_cache
#endif


/* QNX needs a special header for asprintf() */
#ifdef __QNXNTO__
#include <nbutil.h>
#endif

#define PAGE_SIZE 4096

#ifdef __CHERI__
#define valloc(x) fake_valloc(x)
void *fake_valloc(size_t size)
{
	if (size % PAGE_SIZE)
	{
		size = (size % PAGE_SIZE) + PAGE_SIZE;
	}
	return mmap(0, size, PROT_READ| PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
}
#endif

struct block_header
{
	void *block;
	void(*fnptr)(void);
	/**
	 * On 64-bit platforms, we have 16 bytes for instructions, which ought to
	 * be enough without padding.  On MIPS, we need 
	 * Note: If we add too much padding, then we waste space but have no other
	 * ill effects.  If we get this too small, then the assert in
	 * `init_trampolines` will fire on library load.
	 */
#if defined(__i386__) || (defined(__mips__) && !defined(__mips_n64))
	uint64_t padding[3];
#elif defined(__mips__) && !defined(__CHERI_SANDBOX__)
	uint64_t padding[2];
#elif defined(__arm__)
	uint64_t padding;
#endif
};

#define HEADERS_PER_PAGE (PAGE_SIZE/sizeof(struct block_header))

/**
 * Structure containing a two pages of block trampolines.  Each trampoline
 * loads its block and target method address from the corresponding
 * block_header (one page before the start of the block structure).
 */
struct trampoline_buffers
{
	struct block_header  headers[HEADERS_PER_PAGE];
	char                 rx_buffer[PAGE_SIZE];
};
_Static_assert(__builtin_offsetof(struct trampoline_buffers, rx_buffer) == PAGE_SIZE,
	"Incorrect offset for read-execute buffer");
_Static_assert(sizeof(struct trampoline_buffers) == 2*PAGE_SIZE,
	"Incorrect size for trampoline buffers");

struct trampoline_set
{
	struct trampoline_buffers *buffers;
	struct trampoline_set     *next;
	int first_free;
};

static mutex_t trampoline_lock;

struct wx_buffer
{
	void *w;
	void *x;
};
extern char __objc_block_trampoline;
extern char __objc_block_trampoline_end;
extern char __objc_block_trampoline_sret;
extern char __objc_block_trampoline_end_sret;

PRIVATE void init_trampolines(void)
{
	assert(&__objc_block_trampoline_end - &__objc_block_trampoline <= sizeof(struct block_header));
	assert(&__objc_block_trampoline_end_sret - &__objc_block_trampoline_sret <= sizeof(struct block_header));
	INIT_LOCK(trampoline_lock);
}

static id invalid(id self, SEL _cmd)
{
	fprintf(stderr, "Invalid block method called for [%s %s]\n",
			class_getName(object_getClass(self)), sel_getName(_cmd));
	return nil;
}

static struct trampoline_set *alloc_trampolines(char *start, char *end)
{
	struct trampoline_set *metadata = calloc(1, sizeof(struct trampoline_set));
	metadata->buffers = valloc(sizeof(struct trampoline_buffers));
	for (int i=0 ; i<HEADERS_PER_PAGE ; i++)
	{
		metadata->buffers->headers[i].fnptr = (void(*)(void))invalid;
		metadata->buffers->headers[i].block = &metadata->buffers->headers[i+1].block;
		char *block = metadata->buffers->rx_buffer + (i * sizeof(struct block_header));
		memcpy(block, start, end-start);
	}
	metadata->buffers->headers[HEADERS_PER_PAGE-1].block = NULL;
	mprotect(metadata->buffers->rx_buffer, PAGE_SIZE, PROT_READ | PROT_EXEC);
#ifndef __FreeBSD__
	clear_cache(metadata->buffers->rx_buffer, &metadata->buffers->rx_buffer[PAGE_SIZE]);
#endif
	return metadata;
}

static struct trampoline_set *sret_trampolines;
static struct trampoline_set *trampolines;

IMP imp_implementationWithBlock(void *block)
{
	struct Block_layout *b = block;
	void *start;
	void *end;
	LOCK_FOR_SCOPE(&trampoline_lock);
	struct trampoline_set **setptr;

	if ((b->flags & BLOCK_USE_SRET) == BLOCK_USE_SRET)
	{
		setptr = &sret_trampolines;
		start = &__objc_block_trampoline_sret;
		end = &__objc_block_trampoline_end_sret;
	}
	else
	{
		setptr = &trampolines;
		start = &__objc_block_trampoline;
		end = &__objc_block_trampoline_end;
	}
	size_t trampolineSize = end - start;
	// If we don't have a trampoline intrinsic for this architecture, return a
	// null IMP.
	if (0 >= trampolineSize) { return 0; }
	block = Block_copy(block);
	// Allocate some trampolines if this is the first time that we need to do this.
	if (*setptr == NULL)
	{
		*setptr = alloc_trampolines(start, end);
	}
	for (struct trampoline_set *set=*setptr ; set!=NULL ; set=set->next)
	{
		if (set->first_free != -1)
		{
			int i = set->first_free;
			struct block_header *h = &set->buffers->headers[i];
			struct block_header *next = h->block;
			set->first_free = next ? (next - set->buffers->headers) : -1;
			assert(set->first_free < HEADERS_PER_PAGE);
			assert(set->first_free >= -1);
			h->fnptr = (void(*)(void))b->invoke;
			h->block = b;
			uintptr_t addr = (uintptr_t)&set->buffers->rx_buffer[i*sizeof(struct block_header)];
#if (__ARM_ARCH_ISA_THUMB == 2)
			// If the trampoline is Thumb-2 code, then we must set the low bit
			// to 1 so that b[l]x instructions put the CPU in the correct mode.
			addr |= 1;
#elif defined(__CHERI_PURE_CAPABILITY__)
			// In a CHERI world, restrict the permissions on the capability (in
			// particular, strip store permissions, and load-data
			addr = (uintptr_t)__builtin_memcap_perms_and((void*)addr,
					__CHERI_CAP_PERMISSION_GLOBAL__ |
					__CHERI_CAP_PERMISSION_PERMIT_EXECUTE__ |
					__CHERI_CAP_PERMISSION_PERMIT_LOAD_CAPABILITY__ |
					0xffff8000); // User permissions
#endif
			return (IMP)addr;
		}
	}
	UNREACHABLE("Failed to allocate block");
}

static int indexForIMP(IMP anIMP, struct trampoline_set **setptr)
{
	for (struct trampoline_set *set=*setptr ; set!=NULL ; set=set->next)
	{
		if (((char*)anIMP >= set->buffers->rx_buffer) &&
		    ((char*)anIMP < &set->buffers->rx_buffer[PAGE_SIZE]))
		{
			*setptr = set;
			ptrdiff_t offset = (char*)anIMP - set->buffers->rx_buffer;
			return offset / sizeof(struct block_header);
		}
	}
	return -1;
}

void *imp_getBlock(IMP anImp)
{
	LOCK_FOR_SCOPE(&trampoline_lock);
	struct trampoline_set *set = trampolines;
	int idx = indexForIMP(anImp, &set);
	if (idx == -1)
	{
		set = sret_trampolines;
		indexForIMP(anImp, &set);
	}
	if (idx == -1)
	{
		return NULL;
	}
	return set->buffers->headers[idx].block;
}

BOOL imp_removeBlock(IMP anImp)
{
	LOCK_FOR_SCOPE(&trampoline_lock);
	struct trampoline_set *set = trampolines;
	int idx = indexForIMP(anImp, &set);
	if (idx == -1)
	{
		set = sret_trampolines;
		indexForIMP(anImp, &set);
	}
	if (idx == -1)
	{
		return NO;
	}
	struct block_header *h = &set->buffers->headers[idx];
	Block_release(h->block);
	h->fnptr = (void(*)(void))invalid;
	h->block = set->first_free == -1 ? NULL : &set->buffers->headers[set->first_free];
	set->first_free = h - set->buffers->headers;
	return YES;
}

PRIVATE size_t lengthOfTypeEncoding(const char *types);

char *block_copyIMPTypeEncoding_np(void*block)
{
	char *buffer = strdup(block_getType_np(block));
	if (NULL == buffer) { return NULL; }
	char *replace = buffer;
	// Skip the return type
	replace += lengthOfTypeEncoding(replace);
	while (isdigit(*replace)) { replace++; }
	// The first argument type should be @? (block), and we need to transform
	// it to @, so we have to delete the ?.  Assert here because this isn't a
	// block encoding at all if the first argument is not a block, and since we
	// got it from block_getType_np(), this means something is badly wrong.
	assert('@' == *replace);
	replace++;
	assert('?' == *replace);
	// Use strlen(replace) not replace+1, because we want to copy the NULL
	// terminator as well.
	memmove(replace, replace+1, strlen(replace));
	// The next argument should be an object, and we want to replace it with a
	// selector
	while (isdigit(*replace)) { replace++; }
	if ('@' != *replace)
	{
		free(buffer);
		return NULL;
	}
	*replace = ':';
	return buffer;
}
