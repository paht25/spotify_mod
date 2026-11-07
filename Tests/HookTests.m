#import <Foundation/Foundation.h>
#import "USFeedHooks.h"
#import "USFeedBridge.h"
#include <stdlib.h>

@interface USRecordingDelegate : NSObject
@property(nonatomic,strong) NSMutableData *bytes;
@property(nonatomic) NSUInteger completions;
@property(nonatomic,strong) NSError *error;
@property(nonatomic,copy) void (^done)(void);
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveResponse:(NSURLResponse *)r completionHandler:(void (^)(NSURLSessionResponseDisposition))handler;
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)d;
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)e;
@end
@implementation USRecordingDelegate
- (instancetype)init { if ((self=[super init])) _bytes=[NSMutableData data]; return self; }
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveResponse:(NSURLResponse *)r completionHandler:(void (^)(NSURLSessionResponseDisposition))handler { (void)s;(void)t;(void)r;handler(NSURLSessionResponseAllow); }
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)d { (void)s;(void)t;[_bytes appendData:d]; }
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)e { (void)s;(void)t;self.completions++; self.error=e; if (self.done) self.done(); }
@end
static void check(BOOL ok, NSString *message) { if (!ok) { NSLog(@"FAIL: %@",message);exit(1); } }
static NSData *field(NSString *text) {
    NSData *payload=[text dataUsingEncoding:NSUTF8StringEncoding]; uint8_t header[]={10,(uint8_t)payload.length};
    NSMutableData *result=[NSMutableData dataWithBytes:header length:2];[result appendData:payload];return result;
}
static void exercise(NSString *host, NSData *body, NSError *failure, BOOL changed) {
    NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=1;
    NSURLSession *session=[NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration delegate:nil delegateQueue:queue];
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/scrollsita/v1/home",host]];
    NSURLSessionDataTask *task=[session dataTaskWithURL:url]; // Never resumed: this is a delegate integration test, not a network request.
    USRecordingDelegate *delegate=[USRecordingDelegate new];
    dispatch_semaphore_t done=dispatch_semaphore_create(0);
    delegate.done=^{ dispatch_semaphore_signal(done); };
    NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    __block BOOL allowed=NO;
    [queue addOperationWithBlock:^{
        [delegate URLSession:session dataTask:task didReceiveResponse:response completionHandler:^(NSURLSessionResponseDisposition choice){ allowed=choice==NSURLSessionResponseAllow; }];
        [delegate URLSession:session dataTask:task didReceiveData:[body subdataWithRange:NSMakeRange(0,body.length/2)]];
        [delegate URLSession:session dataTask:task didReceiveData:[body subdataWithRange:NSMakeRange(body.length/2,body.length-body.length/2)]];
        [delegate URLSession:session task:task didCompleteWithError:failure];
    }];
    check(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC))==0,@"Hook callback must finish");
    [queue waitUntilAllOperationsAreFinished];
    check(allowed,@"Preserve original response disposition");
    check(delegate.completions==1,@"Complete once");
    check(delegate.error==failure,@"Preserve cancellation/network error");
    check(changed ? delegate.bytes.length<body.length : [delegate.bytes isEqual:body],@"Expected transformation or lossless passthrough");
    if (changed) {
        NSString *text=[[NSString alloc] initWithData:delegate.bytes encoding:NSUTF8StringEncoding];
        check([text containsString:@"editorial-card"] && ![text containsString:@"UPSELL-BANNER"],@"Actual Eevee transform keeps editorial and removes promotional section");
    }
    [session invalidateAndCancel];
}
int main(void) {
    @autoreleasepool {
        NSError *error=nil;
        check(!USAttachEeveeFeed(NULL),@"C bridge rejects a null transaction");
        check(!USInstallFeedHooks(NSObject.class,&error),@"Reject missing selectors before any hook changes");
        check(USInstallFeedHooks(USRecordingDelegate.class,&error),@"Install all reviewed delegate callbacks");
        check(USInstallFeedHooks(USRecordingDelegate.class,&error),@"Repeated installation is idempotent");
        NSMutableData *inner=[field(@"editorial-card") mutableCopy];[inner appendData:field(@"UPSELL-BANNER premium offer")];
        uint8_t header[]={10,(uint8_t)inner.length};NSMutableData *body=[NSMutableData dataWithBytes:header length:2];[body appendData:inner];
        exercise(@"spclient.wg.spotify.com",body,nil,YES);
        exercise(@"example.test",body,nil,NO);
        exercise(@"spclient.wg.spotify.com",body,[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil],NO);
        exercise(@"spclient.wg.spotify.com",[NSMutableData dataWithLength:9*1024*1024],nil,NO);
        NSLog(@"Delegate hook integration tests passed; actual Spotify runtime remains untested");
    }
    return 0;
}
