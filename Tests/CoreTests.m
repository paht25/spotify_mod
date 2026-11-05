#import <Foundation/Foundation.h>
#import "USHookRegistry.h"
#import "USPreferences.h"
#include <stdlib.h>

@interface USBase : NSObject
- (NSInteger)value;
@end
@implementation USBase
- (NSInteger)value { return 7; }
@end
@interface USChild : USBase @end
@implementation USChild @end
static NSInteger replacement(id self, SEL selector) { (void)self; (void)selector; return 11; }
static void require(BOOL result, NSString *message) {
    if (!result) { NSLog(@"FAIL: %@", message); exit(1); }
}
int main(void) {
    @autoreleasepool {
        USHookRegistry *registry = [USHookRegistry new];
        SEL selector = @selector(value);
        Method original = class_getInstanceMethod(USChild.class, selector);
        IMP imp = method_getImplementation(original);
        const char *encoding = method_getTypeEncoding(original);
        NSError *error = nil;
        require(![registry installOnClass:USChild.class selector:selector owner:@"bad"
            expectedEncoding:"v@:" expectedOriginal:imp replacement:(IMP)replacement error:&error], @"Reject mismatched ABI");
        require([[USChild new] value] == 7, @"Rejected installation must leave behavior intact");
        require([registry installOnClass:USChild.class selector:selector owner:@"player"
            expectedEncoding:encoding expectedOriginal:imp replacement:(IMP)replacement error:&error], @"Install inherited override");
        require([[USChild new] value] == 11, @"Subclass receives replacement");
        require([[USBase new] value] == 7, @"Superclass remains intact");
        require(![registry installOnClass:USChild.class selector:selector owner:@"lyrics"
            expectedEncoding:encoding expectedOriginal:imp replacement:(IMP)replacement error:&error], @"Reject a second owner");
        require(![[USHookRegistry new] installOnClass:USChild.class selector:selector owner:@"other registry"
            expectedEncoding:encoding expectedOriginal:(IMP)replacement replacement:imp error:&error], @"Ownership is shared across registry instances");
        require([[[registry ownerOfClass:USChild.class selector:selector] objectForKey:@"owner"] isEqual:@"player"], @"Keep ownership record");

        NSString *suite = [@"UnifiedSpotify.Tests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        USPreferences *preferences = [[USPreferences alloc] initWithDefaults:defaults];
        [defaults setObject:@[@"home", @"library"] forKey:@"legacy.tabs"];
        require([preferences copySourceKey:@"legacy.tabs" toUnifiedKey:@"unifiedspotify.tabs" expectedClass:NSArray.class error:&error], @"Copy typed setting");
        require([[defaults objectForKey:@"legacy.tabs"] isEqual:[defaults objectForKey:@"unifiedspotify.tabs"]], @"Preserve source setting");
        [defaults setObject:@[@"queue"] forKey:@"unifiedspotify.tabs"];
        require(![preferences copySourceKey:@"legacy.tabs" toUnifiedKey:@"unifiedspotify.tabs" expectedClass:NSArray.class error:&error], @"Preserve existing destination");
        require(![preferences copySourceKey:@"legacy.tabs" toUnifiedKey:@"unifiedspotify.wrong" expectedClass:NSString.class error:&error], @"Reject unexpected type");
        [defaults removePersistentDomainForName:suite];
        NSLog(@"Core tests passed; this does not verify Spotify integration");
    }
    return 0;
}
