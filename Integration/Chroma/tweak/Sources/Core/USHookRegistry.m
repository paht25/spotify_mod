#import "USHookRegistry.h"
#include <string.h>

static NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *owners;
static NSMutableDictionary<NSString *, NSValue *> *implementations;
@implementation USHookRegistry
- (instancetype)init {
    if ((self = [super init])) {
        @synchronized (USHookRegistry.class) {
            if (!owners) owners = [NSMutableDictionary dictionary];
            if (!implementations) implementations = [NSMutableDictionary dictionary];
        }
    }
    return self;
}
- (NSString *)keyForClass:(Class)cls selector:(SEL)selector {
    // Pointer identity resolves mangled and Swift-qualified aliases to one owner.
    // A metaclass has a distinct identity from the corresponding instance class.
    return [NSString stringWithFormat:@"%p/%s", (void *)cls, sel_getName(selector)];
}
- (BOOL)reject:(NSString *)message error:(NSError **)error {
    if (error) *error = [NSError errorWithDomain:@"UnifiedSpotify.Hooks" code:1
        userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
- (BOOL)installOnClass:(Class)cls selector:(SEL)selector owner:(NSString *)owner
       expectedEncoding:(const char *)encoding expectedOriginal:(IMP)expectedOriginal
           replacement:(IMP)replacement error:(NSError **)error {
    @synchronized (USHookRegistry.class) {
        if (!cls || !selector || !owner.length || !encoding || !expectedOriginal || !replacement)
            return [self reject:@"Missing hook contract argument" error:error];
        NSString *key = [self keyForClass:cls selector:selector];
        if (owners[key]) return [self reject:@"Runtime method already has an owner" error:error];
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) return [self reject:@"Runtime method is absent" error:error];
        if (strcmp(method_getTypeEncoding(method), encoding) != 0)
            return [self reject:@"Runtime type encoding differs from the reviewed contract" error:error];
        if (method_getImplementation(method) != expectedOriginal)
            return [self reject:@"Runtime implementation changed before installation" error:error];
        // Add an override for inherited methods so that a subclass hook does
        // not accidentally replace its superclass's implementation.
        if (!class_addMethod(cls, selector, replacement, encoding)) {
            Method own = class_getInstanceMethod(cls, selector);
            if (method_getImplementation(own) != expectedOriginal)
                return [self reject:@"Runtime implementation changed during installation" error:error];
            method_setImplementation(own, replacement);
        }
        owners[key] = @{@"owner":owner, @"class":NSStringFromClass(cls),
                         @"selector":NSStringFromSelector(selector),
                         @"encoding":[NSString stringWithUTF8String:encoding]};
        implementations[key]=[NSValue valueWithPointer:(const void *)replacement];
        return YES;
    }
}
- (NSDictionary<NSString *, NSString *> *)ownerOfClass:(Class)cls selector:(SEL)selector {
    if (!cls || !selector) return nil;
    @synchronized (USHookRegistry.class) { return [owners[[self keyForClass:cls selector:selector]] copy]; }
}
- (BOOL)isActiveOnClass:(Class)cls selector:(SEL)selector {
    if(!cls||!selector)return NO;
    @synchronized(USHookRegistry.class){
        NSValue *expected=implementations[[self keyForClass:cls selector:selector]];
        Method method=class_getInstanceMethod(cls,selector);
        return expected&&method&&(const void *)method_getImplementation(method)==expected.pointerValue;
    }
}
@end
