#import "USResponseTransaction.h"

@implementation USResponseValue
- (instancetype)initWithResponse:(NSHTTPURLResponse *)response data:(NSData *)data {
    NSParameterAssert(response); NSParameterAssert(data);
    if ((self = [super init])) { _response = response; _data = [data copy]; }
    return self;
}
@end

@interface USResponseStep : NSObject
@property(nonatomic, copy) NSString *owner;
@property(nonatomic, copy) USResponseTransform transform;
@end
@implementation USResponseStep @end

@implementation USResponseTransaction {
    NSHTTPURLResponse *_response;
    NSMutableData *_buffer;
    NSMutableArray<USResponseStep *> *_steps;
    BOOL _finishing;
}
- (instancetype)initWithResponse:(NSHTTPURLResponse *)response {
    NSParameterAssert(response);
    if ((self = [super init])) {
        _response = response;
        _buffer = [NSMutableData data];
        _steps = [NSMutableArray array];
    }
    return self;
}
- (BOOL)addTransformForOwner:(NSString *)owner transform:(USResponseTransform)transform {
    @synchronized (self) {
        if (_finishing || !owner.length || !transform) return NO;
        for (USResponseStep *step in _steps) if ([step.owner isEqual:owner]) return NO;
        USResponseStep *step = [USResponseStep new];
        step.owner = owner; step.transform = transform;
        [_steps addObject:step];
        return YES;
    }
}
- (BOOL)appendData:(NSData *)data {
    @synchronized (self) {
        if (_finishing || !data) return NO;
        [_buffer appendData:data];
        return YES;
    }
}
- (BOOL)finishWithError:(NSError *)networkError workQueue:(dispatch_queue_t)workQueue
         deliveryQueue:(dispatch_queue_t)deliveryQueue deliver:(USResponseDelivery)deliver {
    NSParameterAssert(workQueue); NSParameterAssert(deliveryQueue); NSParameterAssert(deliver);
    USResponseValue *original;
    NSArray<USResponseStep *> *steps;
    @synchronized (self) {
        if (_finishing) return NO;
        _finishing = YES;
        original = [[USResponseValue alloc] initWithResponse:_response data:_buffer];
        steps = [_steps copy];
        // Preserve only the immutable snapshot after terminal transition.
        _buffer = nil; _steps = nil;
    }
    dispatch_async(workQueue, ^{
        USResponseValue *value = original;
        NSError *failure = networkError;
        if (!failure) for (USResponseStep *step in steps) {
            NSError *transformError = nil;
            USResponseValue *next = step.transform(value, &transformError);
            if (transformError) { failure = transformError; value = original; break; }
            if (next) value = next;
        }
        if (!failure && value != original) {
            // NSURLSession gives consumers decoded bytes. Rewritten payloads
            // must not retain wire compression/transfer/length metadata.
            NSMutableDictionary *headers = [value.response.allHeaderFields mutableCopy];
            for (id key in [headers.allKeys copy]) {
                NSString *lower = [[key description] lowercaseString];
                if ([@[@"content-length", @"content-encoding", @"transfer-encoding"] containsObject:lower])
                    [headers removeObjectForKey:key];
            }
            headers[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)value.data.length];
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:value.response.URL
                statusCode:value.response.statusCode HTTPVersion:@"HTTP/1.1" headerFields:headers];
            value = [[USResponseValue alloc] initWithResponse:response data:value.data];
        }
        dispatch_async(deliveryQueue, ^{ deliver(value, failure); });
    });
    return YES;
}
@end
