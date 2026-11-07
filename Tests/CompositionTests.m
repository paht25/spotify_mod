#import <Foundation/Foundation.h>
#import "USUnifiedTransport.h"
#include <stdlib.h>

// A downstream delegate fixture exercises the real composition functions and
// real Swift transforms. It is not a substitute for Chroma/Spotify UI testing.
@interface USCompositionDelegate : NSObject
@property(nonatomic,strong) NSMutableData *bytes;
@property(nonatomic,strong) NSError *error;
@property(nonatomic) NSUInteger completions;
@property(nonatomic) BOOL onDelegateQueue;
@property(nonatomic,copy) void (^done)(void);
@property(nonatomic,strong) USCompositionDelegate *next;
@end
@implementation USCompositionDelegate
- (instancetype)init { if((self=[super init]))_bytes=[NSMutableData data];return self; }
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)d {
    if(USUnifiedCaptureData(self,s,t,d))return;
    self.onDelegateQueue=NSOperationQueue.currentQueue==s.delegateQueue;
    [self.bytes appendData:d];
    if(self.next)[self.next URLSession:s dataTask:t didReceiveData:d];
}
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)e {
    if(USUnifiedComplete(self,s,t,e))return;
    self.onDelegateQueue=self.onDelegateQueue && NSOperationQueue.currentQueue==s.delegateQueue;
    self.completions++;self.error=e;if(self.done)self.done();
    if(self.next)[self.next URLSession:s task:t didCompleteWithError:e];
}
@end
static void require(BOOL ok,NSString *why){if(!ok){NSLog(@"FAIL composition: %@",why);exit(1);}}
static NSData *field(NSString *s){NSData *d=[s dataUsingEncoding:NSUTF8StringEncoding];uint8_t h[]={10,(uint8_t)d.length};NSMutableData *r=[NSMutableData dataWithBytes:h length:2];[r appendData:d];return r;}
static void exercise(NSString *host,NSData *body,NSError *error,BOOL changed,BOOL duplicate){
    NSOperationQueue *q=[NSOperationQueue new];q.maxConcurrentOperationCount=1;
    NSURLSession *s=[NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration delegate:nil delegateQueue:q];
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/scrollsita/v1/home",host]];
    NSURLSessionDataTask *t=[s dataTaskWithURL:url]; // Deliberately not resumed; no network side effects.
    USCompositionDelegate *d=[USCompositionDelegate new];dispatch_semaphore_t done=dispatch_semaphore_create(0);
    USCompositionDelegate *downstream=[USCompositionDelegate new];d.next=downstream;
    downstream.done=^{dispatch_semaphore_signal(done);};
    [q addOperationWithBlock:^{
        NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc]initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
        USUnifiedReceiveResponse(d,t,response);
        USUnifiedReceiveResponse(downstream,t,response); // Same real task forwarded through a second delegate.
        NSUInteger split=body.length/2;
        [d URLSession:s dataTask:t didReceiveData:[body subdataWithRange:NSMakeRange(0,split)]];
        [d URLSession:s dataTask:t didReceiveData:[body subdataWithRange:NSMakeRange(split,body.length-split)]];
        [d URLSession:s task:t didCompleteWithError:error];
        if(duplicate)[d URLSession:s task:t didCompleteWithError:error];
    }];
    require(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC))==0,@"delivery finishes");
    [q waitUntilAllOperationsAreFinished];
    require(d.completions==1,@"one terminal callback");require(d.error==error,@"original error retained");
    require(downstream.completions==1 && [downstream.bytes isEqual:d.bytes],@"same-task downstream delegate receives one complete response");
    require(d.onDelegateQueue,@"downstream callbacks use actual session delegate queue");
    if(changed){
        require(d.bytes.length<body.length,@"actual Eevee filtering ran");
        NSString *text=[[NSString alloc]initWithData:d.bytes encoding:NSUTF8StringEncoding];
        require([text containsString:@"editorial-card"] && ![text containsString:@"UPSELL-BANNER"],@"preserve editorial, remove promo");
    }else require([d.bytes isEqual:body],@"byte-exact passthrough");
    [s invalidateAndCancel];
}
int main(void){@autoreleasepool{
    NSUserDefaults *prefs=NSUserDefaults.standardUserDefaults;
    [prefs setBool:YES forKey:@"unifiedspotify.feedEnabled"];
    NSMutableData *inner=[field(@"editorial-card")mutableCopy];[inner appendData:field(@"UPSELL-BANNER premium offer")];
    uint8_t h[]={10,(uint8_t)inner.length};NSMutableData *body=[NSMutableData dataWithBytes:h length:2];[body appendData:inner];
    exercise(@"spclient.wg.spotify.com",body,nil,YES,YES);
    exercise(@"example.test",body,nil,NO,NO);
    exercise(@"spclient.wg.spotify.com",body,[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil],NO,YES);
    exercise(@"spclient.wg.spotify.com",[NSMutableData dataWithLength:9*1024*1024],nil,NO,YES);
    [prefs setBool:NO forKey:@"unifiedspotify.feedEnabled"];
    exercise(@"spclient.wg.spotify.com",body,nil,NO,NO);
    [prefs removeObjectForKey:@"unifiedspotify.feedEnabled"];
    NSLog(@"Composition boundary tests passed; actual Chroma/Spotify runtime is not tested");
}return 0;}
