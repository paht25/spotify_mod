#import <Foundation/Foundation.h>
#import "USResponseTransaction.h"
#import "Protobuf.h"
#include <stdlib.h>

static void check(BOOL ok, NSString *message) {
    if (!ok) { NSLog(@"FAIL: %@", message); exit(1); }
}
static NSData *bytes(NSString *text) { return [text dataUsingEncoding:NSUTF8StringEncoding]; }
static NSHTTPURLResponse *response(void) {
    return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.test/lyrics"]
        statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Length":@"999", @"Content-Encoding":@"gzip"}];
}
static USResponseValue *finish(USResponseTransaction *transaction, NSError *error, NSError **failure) {
    dispatch_queue_t work = dispatch_queue_create("transport.test.work", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t delivery = dispatch_queue_create("transport.test.delivery", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block USResponseValue *output;
    __block NSError *outputError;
    check([transaction finishWithError:error workQueue:work deliveryQueue:delivery deliver:^(USResponseValue *value, NSError *issue) {
        output = value; outputError = issue; dispatch_semaphore_signal(done);
    }], @"First completion wins");
    check(![transaction finishWithError:nil workQueue:work deliveryQueue:delivery deliver:^(USResponseValue *value, NSError *issue) {
        (void)value; (void)issue; check(NO, @"Duplicate completion must not deliver");
    }], @"Reject duplicate completion");
    check(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, @"Delivery must finish without hanging");
    dispatch_sync(work, ^{}); dispatch_sync(delivery, ^{});
    if (failure) *failure = outputError;
    return output;
}
int main(void) {
    @autoreleasepool {
        USResponseTransaction *a = [[USResponseTransaction alloc] initWithResponse:response()];
        USResponseTransaction *b = [[USResponseTransaction alloc] initWithResponse:response()];
        [a appendData:bytes(@"one")]; [b appendData:bytes(@"other")]; [a appendData:bytes(@"two")];
        check([finish(a, nil, NULL).data isEqual:bytes(@"onetwo")], @"Interleaved transactions retain their own bytes");
        check([finish(b, nil, NULL).data isEqual:bytes(@"other")], @"Second transaction remains isolated");
        check(![a appendData:bytes(@"late")], @"Reject late data");
        USResponseTransaction *ordered = [[USResponseTransaction alloc] initWithResponse:response()];
        [ordered appendData:bytes(@"base")];
        USResponseTransform first = ^USResponseValue *(USResponseValue *input, NSError **error) {
            (void)error; check([input.data isEqual:bytes(@"base")], @"First transform sees original");
            return [[USResponseValue alloc] initWithResponse:input.response data:bytes(@"step1")];
        };
        check([ordered addTransformForOwner:@"first" transform:first], @"Register first owner");
        check(![ordered addTransformForOwner:@"first" transform:first], @"Duplicate owner rejected");
        [ordered addTransformForOwner:@"second" transform:^USResponseValue *(USResponseValue *input, NSError **error) {
            (void)error; check([input.data isEqual:bytes(@"step1")], @"Transforms run in registration order");
            return [[USResponseValue alloc] initWithResponse:input.response data:bytes(@"step2")];
        }];
        USResponseValue *result = finish(ordered, nil, NULL);
        check([result.data isEqual:bytes(@"step2")], @"Deliver composed result");
        check([[result.response valueForHTTPHeaderField:@"Content-Length"] isEqual:@"5"], @"Recompute length");
        check([result.response valueForHTTPHeaderField:@"Content-Encoding"] == nil, @"Remove stale compression metadata");
        USResponseTransaction *rollback = [[USResponseTransaction alloc] initWithResponse:response()];
        [rollback appendData:bytes(@"original")];
        [rollback addTransformForOwner:@"mutate" transform:first];
        // A separate valid first step allows checking rollback of prior output.
        USResponseTransaction *failed = [[USResponseTransaction alloc] initWithResponse:response()];
        [failed appendData:bytes(@"base")]; [failed addTransformForOwner:@"first" transform:first];
        [failed addTransformForOwner:@"fail" transform:^USResponseValue *(USResponseValue *input, NSError **error) {
            (void)input; *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil]; return nil;
        }];
        NSError *issue = nil;
        check([finish(failed, nil, &issue).data isEqual:bytes(@"base")] && issue != nil, @"Transform errors restore original bytes");
        NSError *cancelled = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
        check([finish(rollback, cancelled, &issue).data isEqual:bytes(@"original")] && issue == cancelled, @"Cancellation skips transformations");
        USResponseTransaction *empty = [[USResponseTransaction alloc] initWithResponse:response()];
        check(finish(empty, nil, NULL).data.length == 0, @"Empty responses still complete");
        USResponseTransaction *raced = [[USResponseTransaction alloc] initWithResponse:response()];
        dispatch_queue_t raceWork = dispatch_queue_create("race.work", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t raceDelivery = dispatch_queue_create("race.delivery", DISPATCH_QUEUE_SERIAL);
        dispatch_semaphore_t raceDone = dispatch_semaphore_create(0);
        NSObject *countLock = [NSObject new];
        __block NSUInteger winners = 0, deliveries = 0;
        dispatch_apply(32, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
            (void)index;
            BOOL won = [raced finishWithError:nil workQueue:raceWork deliveryQueue:raceDelivery
                deliver:^(USResponseValue *value, NSError *error) {
                    (void)value; (void)error;
                    @synchronized (countLock) { deliveries++; }
                    dispatch_semaphore_signal(raceDone);
                }];
            if (won) @synchronized (countLock) { winners++; }
        });
        check(dispatch_semaphore_wait(raceDone, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0,
              @"Concurrent completion delivers");
        dispatch_sync(raceWork, ^{}); dispatch_sync(raceDelivery, ^{});
        check(winners == 1 && deliveries == 1, @"Concurrent completion has one winner and one delivery");

        // Exercise the actual Chroma wire codec, including unknown-field retention.
        NSArray *fields = @[SGPBString(1, @"lyrics"), SGPBVarint(99, 12345)];
        NSData *wire = SGPBSerialize(fields);
        NSArray *decoded = SGPBParse(wire);
        check([SGPBText(SGPBFirst(decoded, 1)) isEqual:@"lyrics"], @"Decode Chroma lyric text field");
        check(SGPBFirst(decoded, 99).varint == 12345, @"Unknown protobuf field survives");
        check([SGPBSerialize(decoded) isEqual:wire], @"Wire fields round-trip");
        uint8_t bad[] = {0x0a, 0x05, 0x41};
        check(SGPBParse([NSData dataWithBytes:bad length:sizeof(bad)]) == nil, @"Reject truncated length-delimited payload");
        NSLog(@"Transport and Chroma protobuf tests passed; Spotify runtime remains untested");
    }
    return 0;
}
