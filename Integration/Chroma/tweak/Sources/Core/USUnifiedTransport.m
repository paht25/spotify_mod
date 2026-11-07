#import "USUnifiedTransport.h"
#import "USResponseTransaction.h"
#import "USRuntimeState.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#include <stdbool.h>
extern bool USAttachEeveeFeed(void *transaction);
extern bool USAttachEeveePremium(void *transaction);

@interface USComposedTask : NSObject
@property(nonatomic,weak) id owner;
@property(nonatomic,strong) NSHTTPURLResponse *response;
@property(nonatomic,strong) NSMutableData *body;
@property(nonatomic,copy) NSString *category;
@property(nonatomic) BOOL finishing,released,terminalDelivered;
@end
@implementation USComposedTask @end
static char contextKey;
static const NSUInteger limit=8*1024*1024;
BOOL USUnifiedTargetSupported(void) {
    NSBundle *app=NSBundle.mainBundle;
    BOOL supported=[app.executablePath.lastPathComponent isEqual:@"Spotify"] &&
        [[app objectForInfoDictionaryKey:@"CFBundleShortVersionString"] isEqual:@"9.1.90"] &&
        [[app objectForInfoDictionaryKey:@"CFBundleVersion"] isEqual:@"919002269"] &&
        NSProcessInfo.processInfo.operatingSystemVersion.majorVersion==27;
    if(!supported)return NO;
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const char *image=_dyld_get_image_name(i);if(!image)continue;
        NSString *name=[[NSString stringWithUTF8String:image].lastPathComponent lowercaseString];
        if([name isEqual:@"eeveespotify.dylib"] || [name isEqual:@"unifiedspotifyexperimental.dylib"]){
            NSLog(@"[UnifiedSpotify] Existing tweak image %@ detected; use the clean NoEevee input",name);return NO;
        }
    }
    return YES;
}
static void sendBody(id delegate,NSURLSession *session,NSURLSessionDataTask *task,NSData *body) {
    ((void (*)(id,SEL,id,id,id))objc_msgSend)(delegate,NSSelectorFromString(@"URLSession:dataTask:didReceiveData:"),session,task,body);
}
void USUnifiedReceiveResponse(id delegate,NSURLSessionTask *task,NSURLResponse *response) {
    if(![response isKindOfClass:NSHTTPURLResponse.class] || ((NSHTTPURLResponse *)response).statusCode!=200)return;
    NSString *host=response.URL.host.lowercaseString,*p=response.URL.path.lowercaseString;
    if(![host isEqual:@"spotify.com"] && ![host hasSuffix:@".spotify.com"])return;
    BOOL premium=USSettingEnabled(@"unifiedspotify.premiumPatching",[NSUserDefaults.standardUserDefaults integerForKey:@"patchType"]!=1);
    BOOL config=premium && ([p containsString:@"/v1/bootstrap"] || [p containsString:@"/v1/customize"]);
    BOOL feed=USSettingEnabled(@"unifiedspotify.feedEnabled",YES) &&
        ([p containsString:@"/browsita/"] || [p containsString:@"/scrollsita/"] || [p containsString:@"/casita/"]);
    if(!config && !feed)return;
    if([p hasSuffix:@"/casita/v1/feeds"] || [p containsString:@"/casita/v1/feeds/"])return;
    if(objc_getAssociatedObject(task,&contextKey))return;
    USComposedTask *state=[USComposedTask new];state.owner=delegate;state.response=(NSHTTPURLResponse *)response;state.body=[NSMutableData data];
    state.category=config?([p containsString:@"/v1/bootstrap"]?@"bootstrap":@"customize"):@"feed";
    USStateIncrement([NSString stringWithFormat:@"network.%@.selected",state.category]);
    objc_setAssociatedObject(task,&contextKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);USStateIncrement(@"network.selected");
}
BOOL USUnifiedCaptureData(id delegate,NSURLSession *session,NSURLSessionDataTask *task,NSData *data) {
    USComposedTask *state=objc_getAssociatedObject(task,&contextKey);if(!state || state.owner!=delegate)return NO;
    @synchronized(state){
        if(state.released)return NO;
        if(state.finishing)return YES;
        if(data.length<=limit-state.body.length){[state.body appendData:data];return YES;}
        NSData *prefix=[state.body copy];state.body=nil;state.released=YES;
        USStateIncrement(@"network.oversizePassthrough");
        // Keep overflow replay ahead of a concurrent completion. The re-entry
        // takes this recursive lock and immediately sees released == YES.
        if(prefix.length)sendBody(delegate,session,task,prefix);
        sendBody(delegate,session,task,data);return YES;
    }
}
BOOL USUnifiedComplete(id delegate,NSURLSession *session,NSURLSessionTask *task,NSError *error) {
    USComposedTask *state=objc_getAssociatedObject(task,&contextKey);if(!state || state.owner!=delegate)return NO;
    NSData *body=nil;
    @synchronized(state){
        if(state.released){if(state.terminalDelivered)return YES;state.terminalDelivered=YES;return NO;}
        if(state.finishing)return YES;state.finishing=YES;body=[state.body copy];state.body=nil;
    }
    USResponseTransaction *transaction=[[USResponseTransaction alloc] initWithResponse:state.response];
    [transaction appendData:body];
    USAttachEeveeFeed((__bridge void *)transaction);USAttachEeveePremium((__bridge void *)transaction);
    [transaction finishWithError:error workQueue:dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0)
        deliveryQueue:dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0) deliver:^(USResponseValue *value,NSError *issue){
        [session.delegateQueue addOperationWithBlock:^{
            @synchronized(state){state.released=YES;}
            USStateIncrement(@"network.completed");
            if(![value.data isEqual:body]){
                USStateIncrement(@"network.transformed");
                USStateIncrement([NSString stringWithFormat:@"network.%@.transformed",state.category]);
            }
            sendBody(delegate,session,(NSURLSessionDataTask *)task,value.data);
            ((void (*)(id,SEL,id,id,id))objc_msgSend)(delegate,NSSelectorFromString(@"URLSession:task:didCompleteWithError:"),session,task,issue);
        }];
    }];return YES;
}
