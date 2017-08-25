#include <stdio.h>
#include <assert.h>

#import <objc/ObjectPlane.h>

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
