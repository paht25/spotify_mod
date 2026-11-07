#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Keeps legacy namespaces intact. Callers must explicitly choose a source key;
/// matching labels are never treated as permission to merge preference values.
@interface USPreferences : NSObject
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (nullable id)valueForSourceKey:(NSString *)key expectedClass:(Class)valueClass;
- (BOOL)copySourceKey:(NSString *)sourceKey
        toUnifiedKey:(NSString *)destinationKey
       expectedClass:(Class)valueClass
               error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
