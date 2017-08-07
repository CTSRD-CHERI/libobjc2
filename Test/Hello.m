#include <stdio.h>
#include <Foundation/Foundation.h>

@interface HelloWorldCommand : NSObject
{
}
- (void) do_;
@end

@implementation HelloWorldCommand
- (void) do_
{
	printf("Hello world!\n");
}
@end
	

int main(int argc, char *argv[])
{
    NSZone *hello_zone = NSCreateZone(0x8000, 0x8000, 0);
    if (hello_zone == NULL) {
        printf("NSCreateZone err\n");
        exit(1);
    }
    NSSetZoneName(hello_zone, @"Hello-zone");
	id hello_world = [HelloWorldCommand allocWithZone: hello_zone];
    NSZone *hello_world_zone = NSZoneFromPointer(hello_world);
    if (hello_world_zone == NULL) {
        printf("NSZoneFromPointer err\n");
        exit(1);
    }
	printf("Alloc'd %p, zone %s\n", hello_world, [hello_world_zone->name cString]);
	[hello_world init];  
	printf("Init'd %p\n", hello_world);
	[hello_world do_];

	return 0;
}
