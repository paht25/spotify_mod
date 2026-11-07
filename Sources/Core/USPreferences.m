#import "USPreferences.h"

@implementation USPreferences {
    NSUserDefaults *_defaults;
}
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    NSParameterAssert(defaults);
    if ((self = [super init])) _defaults = defaults;
    return self;
}
- (id)valueForSourceKey:(NSString *)key expectedClass:(Class)valueClass {
    @synchronized (self) {
        id value = [_defaults objectForKey:key];
        return [value isKindOfClass:valueClass] ? value : nil;
    }
}
- (BOOL)copySourceKey:(NSString *)sourceKey toUnifiedKey:(NSString *)destinationKey
       expectedClass:(Class)valueClass error:(NSError **)error {
    @synchronized (self) {
        NSString *reason = nil;
        if (!sourceKey.length || ![destinationKey hasPrefix:@"unifiedspotify."] || !valueClass)
            reason = @"Migration requires a source key, a unifiedspotify destination and a value class";
        id value = reason ? nil : [_defaults objectForKey:sourceKey];
        if (!reason && ![value isKindOfClass:valueClass]) reason = @"Source preference is absent or has an unexpected type";
        if (!reason && [_defaults objectForKey:destinationKey] != nil) reason = @"Destination preference already exists";
        if (reason) {
            if (error) *error = [NSError errorWithDomain:@"UnifiedSpotify.Preferences" code:1
                userInfo:@{NSLocalizedDescriptionKey:reason}];
            return NO;
        }
        // Source values and defaults are deliberately retained. This is an
        // explicit copy operation, not a claim of an atomic migration system.
        [_defaults setObject:value forKey:destinationKey];
        return YES;
    }
}
@end
