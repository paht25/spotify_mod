#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN
/// One owner per resolved runtime Class/selector. This registry installs only
/// explicitly supplied implementations; it does not activate either original tweak.
@interface USHookRegistry : NSObject
- (BOOL)installOnClass:(Class)runtimeClass
             selector:(SEL)selector
                 owner:(NSString *)owner
       expectedEncoding:(const char *)encoding
       expectedOriginal:(IMP)expectedOriginal
           replacement:(IMP)replacement
                 error:(NSError * _Nullable * _Nullable)error;
- (nullable NSDictionary<NSString *, NSString *> *)ownerOfClass:(Class)runtimeClass selector:(SEL)selector;
@end
NS_ASSUME_NONNULL_END
