#import "USFeedHooks.h"
#import "USHookRegistry.h"
#import "USResponseTransaction.h"
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

// Explicit selector contract exported by the Swift implementation.
@interface USEeveeFeedModule : NSObject
+ (BOOL)attachTo:(USResponseTransaction *)transaction;
@end

typedef void (^USDisposition)(NSURLSessionResponseDisposition);
typedef void (*USResponseIMP)(id, SEL, NSURLSession *, NSURLSessionDataTask *, NSURLResponse *, USDisposition);
typedef void (*USDataIMP)(id, SEL, NSURLSession *, NSURLSessionDataTask *, NSData *);
typedef void (*USEndIMP)(id, SEL, NSURLSession *, NSURLSessionTask *, NSError *);

@interface USDelegateContract : NSObject
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(USDisposition)handler;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error;
@end
@implementation USDelegateContract
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveResponse:(NSURLResponse *)r completionHandler:(USDisposition)h { (void)s;(void)t;(void)r;h(NSURLSessionResponseAllow); }
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)d { (void)s;(void)t;(void)d; }
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)e { (void)s;(void)t;(void)e; }
@end

@interface USFeedTaskState : NSObject
@property(nonatomic, strong) NSHTTPURLResponse *response;
@property(nonatomic, strong) NSMutableData *buffer;
@property(nonatomic) BOOL passthrough;
@property(nonatomic) BOOL finished;
@end
@implementation USFeedTaskState @end

@interface USFeedOriginals : NSObject
@property(nonatomic) IMP response;
@property(nonatomic) IMP data;
@property(nonatomic) IMP end;
@end
@implementation USFeedOriginals @end

static NSMutableDictionary<NSValue *, USFeedOriginals *> *originals;
static char stateKey;
static const NSUInteger bufferLimit = 8 * 1024 * 1024;
static SEL responseSelector(void) { return @selector(URLSession:dataTask:didReceiveResponse:completionHandler:); }
static SEL dataSelector(void) { return @selector(URLSession:dataTask:didReceiveData:); }
static SEL endSelector(void) { return @selector(URLSession:task:didCompleteWithError:); }
static USFeedOriginals *forDelegate(id delegate) {
    @synchronized (USFeedOriginals.class) {
        for (Class cls = object_getClass(delegate); cls; cls = class_getSuperclass(cls)) {
            USFeedOriginals *value = originals[[NSValue valueWithPointer:(const void *)cls]];
            if (value) return value;
        }
        return nil;
    }
}
static BOOL selectedResponse(NSURLResponse *response) {
    if (![response isKindOfClass:NSHTTPURLResponse.class] || ((NSHTTPURLResponse *)response).statusCode != 200) return NO;
    NSString *host = response.URL.host.lowercaseString;
    if (![host isEqual:@"spotify.com"] && ![host hasSuffix:@".spotify.com"]) return NO;
    NSString *p = response.URL.path.lowercaseString;
    if ([p hasSuffix:@"/casita/v1/feeds"] || [p containsString:@"/casita/v1/feeds/"]) return NO;
    return [p containsString:@"/scrollsita/"] || [p containsString:@"/browsita/"] || [p containsString:@"/casita/"];
}
static void receiveResponse(id self, SEL command, NSURLSession *session, NSURLSessionDataTask *task, NSURLResponse *response, USDisposition handler) {
    USFeedOriginals *o = forDelegate(self);
    ((USResponseIMP)o.response)(self, command, session, task, response, ^(NSURLSessionResponseDisposition choice) {
        if (choice == NSURLSessionResponseAllow && selectedResponse(response)) {
            USFeedTaskState *state = [USFeedTaskState new];
            state.response = (NSHTTPURLResponse *)response;
            state.buffer = [NSMutableData data];
            objc_setAssociatedObject(task, &stateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        handler(choice);
    });
}
static void receiveData(id self, SEL command, NSURLSession *session, NSURLSessionDataTask *task, NSData *data) {
    USFeedOriginals *o = forDelegate(self);
    USFeedTaskState *state = objc_getAssociatedObject(task, &stateKey);
    if (!state) { ((USDataIMP)o.data)(self, command, session, task, data); return; }
    NSData *flush = nil;
    @synchronized (state) {
        if (state.finished) return;
        if (!state.passthrough && data.length <= bufferLimit - state.buffer.length) {
            [state.buffer appendData:data]; return;
        }
        if (!state.passthrough) { flush = [state.buffer copy]; state.buffer = nil; state.passthrough = YES; }
    }
    if (flush.length) ((USDataIMP)o.data)(self, command, session, task, flush);
    ((USDataIMP)o.data)(self, command, session, task, data);
}
static void complete(id self, SEL command, NSURLSession *session, NSURLSessionTask *task, NSError *error) {
    USFeedOriginals *o = forDelegate(self);
    USFeedTaskState *state = objc_getAssociatedObject(task, &stateKey);
    if (!state) { ((USEndIMP)o.end)(self, command, session, task, error); return; }
    NSData *body;
    BOOL passthrough;
    @synchronized (state) {
        if (state.finished) return;
        state.finished = YES;
        passthrough = state.passthrough; body = [state.buffer copy]; state.buffer = nil;
    }
    if (passthrough) { ((USEndIMP)o.end)(self, command, session, task, error); return; }
    USResponseTransaction *transaction = [[USResponseTransaction alloc] initWithResponse:state.response];
    [transaction appendData:body];
    [USEeveeFeedModule attachTo:transaction];
    [transaction finishWithError:error workQueue:dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
        deliveryQueue:dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
        deliver:^(USResponseValue *value, NSError *issue) {
            // Re-enter the session's actual delegate operation queue, including
            // main-queue delegates. Replay body and completion in ONE operation.
            [session.delegateQueue addOperationWithBlock:^{
                ((USDataIMP)o.data)(self, dataSelector(), session, (NSURLSessionDataTask *)task, value.data);
                ((USEndIMP)o.end)(self, command, session, task, issue);
            }];
        }];
}
static Method ownMethod(Class cls, SEL selector) {
    unsigned count = 0; Method found = NULL; Method *methods = class_copyMethodList(cls, &count);
    for (unsigned i=0;i<count;i++) if (method_getName(methods[i]) == selector) { found=methods[i]; break; }
    free(methods); return found;
}
BOOL USInstallFeedHooks(Class cls, NSError **error) {
    @synchronized (USFeedOriginals.class) {
        if (!originals) originals = [NSMutableDictionary dictionary];
        NSValue *key = [NSValue valueWithPointer:(const void *)cls];
        if (originals[key]) return YES;
        SEL selectors[] = {responseSelector(), dataSelector(), endSelector()};
        IMP replacements[] = {(IMP)receiveResponse, (IMP)receiveData, (IMP)complete};
        IMP previous[3];
        USHookRegistry *registry = [USHookRegistry new];
        for (NSUInteger i=0;i<3;i++) {
            Method method = cls ? ownMethod(cls, selectors[i]) : NULL;
            Method contract = class_getInstanceMethod(USDelegateContract.class, selectors[i]);
            if (!method || [registry ownerOfClass:cls selector:selectors[i]] ||
                strcmp(method_getTypeEncoding(method), method_getTypeEncoding(contract)) != 0) {
                if (error) *error = [NSError errorWithDomain:@"UnifiedSpotify.FeedHooks" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Delegate selectors or ABI do not match reviewed contract"}];
                return NO;
            }
            previous[i] = method_getImplementation(method);
        }
        USFeedOriginals *o = [USFeedOriginals new]; o.response=previous[0]; o.data=previous[1]; o.end=previous[2];
        originals[key] = o;
        for (NSUInteger i=0;i<3;i++) {
            BOOL ok = [registry installOnClass:cls selector:selectors[i] owner:@"unified.feed-delegate"
                expectedEncoding:method_getTypeEncoding(class_getInstanceMethod(USDelegateContract.class, selectors[i]))
                expectedOriginal:previous[i] replacement:replacements[i] error:error];
            if (!ok) {
                // A concurrent external swizzler is not supported. Keep the
                // original table for any callback already installed; fail fast.
                NSLog(@"[UnifiedSpotify] Partial hook activation; stop this test and remove the experimental dylib");
                return NO;
            }
        }
        return YES;
    }
}
