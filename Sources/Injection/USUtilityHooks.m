#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "USUtilityHooks.h"
#import "USHookRegistry.h"
#import "USRuntimeState.h"

extern void *USCleanSharedObject(void *object);
extern void *USCleanDeepLink(void *object);
static NSMutableDictionary<NSString *, NSValue *> *imps;
static NSString *key(Class cls, SEL selector) { return [NSString stringWithFormat:@"%p/%s",(void *)cls,sel_getName(selector)]; }
static IMP previous(id object, SEL selector) {
    @synchronized (USHookRegistry.class) {
    for (Class cls=object_getClass(object);cls;cls=class_getSuperclass(cls)) {
        NSValue *value=imps[key(cls,selector)]; if (value) return (IMP)[value pointerValue];
    }
    return NULL;
    }
}
static id cleaned(id value, BOOL deep) {
    if (!value || !USSettingEnabled(@"unifiedspotify.cleanShareLinks",USSettingEnabled(@"cleanShareLinks",NO))) return value;
    void *raw=deep ? USCleanDeepLink((__bridge void *)value) : USCleanSharedObject((__bridge void *)value);
    id result=CFBridgingRelease(raw);
    if (![result isEqual:value]) USStateIncrement(@"links.cleaned");
    return result ?: value;
}
static void setOne(id self, SEL selector, id value) {
    ((void (*)(id,SEL,id))previous(self,selector))(self,selector,cleaned(value,NO));
}
static void setTwo(id self, SEL selector, id value, id option) {
    ((void (*)(id,SEL,id,id))previous(self,selector))(self,selector,cleaned(value,NO),option);
}
static void openLink(id self, SEL selector, NSURL *url, NSDictionary *options, void (^completion)(BOOL)) {
    ((void (*)(id,SEL,id,id,id))previous(self,selector))(self,selector,cleaned(url,YES),options,completion);
}
static void review(id self, SEL selector) {
    if (USSettingEnabled(@"eeveeBlockRatingPrompts",NO)) { USStateIncrement(@"ratings.blocked"); return; }
    ((void (*)(id,SEL))previous(self,selector))(self,selector);
}
static void reviewScene(id self, SEL selector, id scene) {
    if (USSettingEnabled(@"eeveeBlockRatingPrompts",NO)) { USStateIncrement(@"ratings.blocked"); return; }
    ((void (*)(id,SEL,id))previous(self,selector))(self,selector,scene);
}
static void haptic(UIControl *control, UIEvent *event) {
    if (!USSettingEnabled(@"unifiedspotify.controlHaptics",NO)) return;
    NSString *identifier=control.accessibilityIdentifier.length ? control.accessibilityIdentifier : control.superview.accessibilityIdentifier;
    if (![@[@"SPTNowPlayingPlayButton",@"SPTNowPlayingPreviousTrackButton",@"SPTNowPlayingNextTrackButton",
             @"Components.UI.ShuffleButton",@"Nowplaying-RepeatButton",@"Components.UI.AddToButton"] containsObject:identifier ?: @""]) return;
    if (event.allTouches.count) {
        BOOL ended=NO; for (UITouch *touch in event.allTouches) if (touch.phase==UITouchPhaseEnded) ended=YES;
        if (!ended) return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        static CFTimeInterval last; CFTimeInterval now=CACurrentMediaTime(); if (now-last<0.08) return; last=now;
        static UIImpactFeedbackGenerator *generator;
        if(!generator)generator=[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator impactOccurred];[generator prepare]; USStateIncrement(@"haptics.delivered");
    });
}
static void controlAction(id self, SEL selector, SEL action, id target, UIEvent *event) {
    ((void (*)(id,SEL,SEL,id,id))previous(self,selector))(self,selector,action,target,event); haptic(self,event);
}
static void controlUIAction(id self, SEL selector, UIAction *action) {
    ((void (*)(id,SEL,id))previous(self,selector))(self,selector,action); haptic(self,nil);
}
static void install(Class cls, NSString *name, IMP replacement, NSUInteger args, BOOL objectReturn) {
    SEL selector=NSSelectorFromString(name); Method method=cls ? class_getInstanceMethod(cls,selector) : NULL;
    if (!method) { USStateSet([@"utility." stringByAppendingString:name],@"selector absent"); return; }
    if (imps[key(cls,selector)]) return;
    char returnType[32]={0};method_getReturnType(method,returnType,sizeof(returnType));
    if (method_getNumberOfArguments(method)!=args || returnType[0]!=(objectReturn?'@':'v')) {
        USStateSet([@"utility." stringByAppendingString:name],@"ABI rejected");return;
    }
    for (NSUInteger i=2;i<args;i++) {
        char type[64]={0};method_getArgumentType(method,(unsigned int)i,type,sizeof(type));
        char expected=([name isEqual:@"sendAction:to:forEvent:"] && i==2) ? ':' : '@';
        if (type[0]!=expected) { USStateSet([@"utility." stringByAppendingString:name],@"argument ABI rejected");return; }
    }
    IMP original=method_getImplementation(method);imps[key(cls,selector)]=[NSValue valueWithPointer:(const void *)original];
    NSError *error=nil;BOOL ok=[[USHookRegistry new] installOnClass:cls selector:selector owner:@"unified.utilities"
        expectedEncoding:method_getTypeEncoding(method) expectedOriginal:original replacement:replacement error:&error];
    if (!ok) [imps removeObjectForKey:key(cls,selector)];
    USStateSet([@"utility." stringByAppendingString:name],ok?@"installed":error.localizedDescription);
}
void USInstallUtilityHooks(void) {
    @synchronized (USHookRegistry.class) {
    if (!imps) imps=[NSMutableDictionary dictionary];
    // Hook the concrete pasteboard class once; hooking its superclass too can
    // recursively invoke the same wrapper on super calls.
    Class pasteboard=object_getClass(UIPasteboard.generalPasteboard);
    for (NSString *name in @[@"setURL:",@"setURLs:",@"setString:",@"setStrings:",@"setItems:",@"addItems:"])
        install(pasteboard,name,(IMP)setOne,3,NO);
    for (NSString *name in @[@"setItems:options:",@"setValue:forPasteboardType:",@"setData:forPasteboardType:"])
        install(pasteboard,name,(IMP)setTwo,4,NO);
    install(UIApplication.class,@"openURL:options:completionHandler:",(IMP)openLink,5,NO);
    Class reviewClass=object_getClass(NSClassFromString(@"SKStoreReviewController"));
    install(reviewClass,@"requestReview",(IMP)review,2,NO);
    install(reviewClass,@"requestReviewInScene:",(IMP)reviewScene,3,NO);
    install(UIControl.class,@"sendAction:to:forEvent:",(IMP)controlAction,5,NO);
    install(UIControl.class,@"sendAction:",(IMP)controlUIAction,3,NO);
    }
}
