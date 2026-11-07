#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface USResponseValue : NSObject
@property(nonatomic, readonly) NSHTTPURLResponse *response;
@property(nonatomic, readonly) NSData *data;
- (instancetype)initWithResponse:(NSHTTPURLResponse *)response data:(NSData *)data;
@end

typedef USResponseValue * _Nullable (^USResponseTransform)(USResponseValue *input, NSError * _Nullable *error);
typedef void (^USResponseDelivery)(USResponseValue *value, NSError * _Nullable error);

/// One transaction per actual task object; callers must not key by taskIdentifier
/// alone, since different NSURLSessions can use the same identifier.
@interface USResponseTransaction : NSObject
- (instancetype)initWithResponse:(NSHTTPURLResponse *)response;
/// Registration order is transformation order. Duplicate owners are rejected.
- (BOOL)addTransformForOwner:(NSString *)owner transform:(USResponseTransform)transform NS_SWIFT_NAME(addTransform(owner:transform:));
- (BOOL)appendData:(NSData *)data NS_SWIFT_NAME(append(_:));
/// Exactly one caller wins. Transformation runs off the delegate queue and
/// delivery is enqueued on the explicit queue chosen by the hook adapter.
/// A network or transform error delivers original response/body and the error.
- (BOOL)finishWithError:(nullable NSError *)error
             workQueue:(dispatch_queue_t)workQueue
         deliveryQueue:(dispatch_queue_t)deliveryQueue
               deliver:(USResponseDelivery)deliver NS_SWIFT_NAME(finish(error:workQueue:deliveryQueue:deliver:));
@end
NS_ASSUME_NONNULL_END
