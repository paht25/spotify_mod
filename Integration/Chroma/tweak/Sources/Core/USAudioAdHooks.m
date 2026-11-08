// Adapted from EeveeSpotify v7.0.0 EeveePremiumForce.x.swift (GPL-3.0).
// Narrow ad-only policy: country, streaming rules, subscription dates, offline
// and quality entitlements are deliberately left to the real account response.
#import "USAudioAdHooks.h"
#import "USHookRegistry.h"
#import "USRuntimeState.h"
#include <string.h>

static NSString *adValue(id key) {
    if(![key isKindOfClass:NSString.class])return nil;
    if([@[@"ads",@"audio-ad-frequency",@"video-ad-frequency",@"ab-ad-player-targeting"] containsObject:key])return @"0";
    if([key isEqual:@"ad-formats"])return @"";
    return nil;
}
static BOOL enabled(void) { return USSettingEnabled(@"unifiedspotify.audioAds",YES); }
NSDictionary *USAudioAdAttributes(NSDictionary *attributes) {
    if(![attributes isKindOfClass:NSDictionary.class])return attributes;
    // Count incoming policy changes without collecting account values or IDs.
    // A later update arriving with ads enabled is useful evidence, not proof
    // that the playback core consumed (or rejected) the rewritten dictionary.
    id incoming=attributes[@"ads"];
    if([incoming respondsToSelector:@selector(boolValue)]&&[incoming boolValue])
        USStateIncrement(@"audioAds.enabledPolicyObservations");
    if(attributes[@"ad-formats"])USStateIncrement(@"audioAds.formatPoliciesSeen");
    NSMutableDictionary *result=[attributes mutableCopy];
    for(id key in attributes){NSString *value=adValue(key);if(value)result[key]=value;}
    result[@"ads"]=@"0"; // Original Eevee's safe seed; other ad keys override only.
    return result;
}
static BOOL shape(Method method,char result,NSUInteger args) {
    if(!method||method_getNumberOfArguments(method)!=args)return NO;
    char type[64]={0};method_getReturnType(method,type,sizeof(type));if(type[0]!=result)return NO;
    for(NSUInteger i=2;i<args;i++){method_getArgumentType(method,(unsigned int)i,type,sizeof(type));if(type[0]!='@')return NO;}
    return YES;
}
static void install(Class cls,NSString *name,char result,NSUInteger args,IMP (^make)(IMP,SEL)) {
    NSString *state=[@"audioAdHook." stringByAppendingString:name];
    SEL sel=NSSelectorFromString(name);
    if(!cls){USStateSet(state,@"class unavailable");return;}
    if([[USHookRegistry new]ownerOfClass:cls selector:sel])return;
    Method method=class_getInstanceMethod(cls,sel);
    if(!shape(method,result,args)){USStateSet(state,@"selector absent or ABI rejected");return;}
    IMP original=method_getImplementation(method),replacement=make(original,sel);NSError *error=nil;
    BOOL ok=[[USHookRegistry new]installOnClass:cls selector:sel owner:@"unified.audio-ad-policy"
        expectedEncoding:method_getTypeEncoding(method) expectedOriginal:original replacement:replacement error:&error];
    if(!ok)imp_removeBlock(replacement);
    USStateSet(state,ok?@"installed":error.localizedDescription);
    if(ok)USStateIncrement(@"audioAds.installed");
}
void USInstallAudioAdHooks(void) {
    @synchronized(USHookRegistry.class){
        Class core=NSClassFromString(@"SPTCoreProductState");
        for(NSString *name in @[@"setOriginalValues:",@"setOverrides:"])
            install(core,name,'v',3,^IMP(IMP original,SEL sel){return imp_implementationWithBlock(^(id object,id values){
                id input=enabled()?USAudioAdAttributes(values):values;
                if(input!=values)USStateIncrement(@"audioAds.dictionaryWrites");
                ((void(*)(id,SEL,id))original)(object,sel,input);
            });});
        for(NSString *name in @[@"values",@"originalValues",@"overrides"])
            install(core,name,'@',2,^IMP(IMP original,SEL sel){return imp_implementationWithBlock(^id(id object){
                id values=((id(*)(id,SEL))original)(object,sel);
                return enabled()?USAudioAdAttributes(values):values;
            });});
        for(NSString *name in @[@"stringForKey:",@"objectForKeyedSubscript:"])
            install(core,name,'@',3,^IMP(IMP original,SEL sel){return imp_implementationWithBlock(^id(id object,id key){
                NSString *value=enabled()?adValue(key):nil;
                if(value){USStateIncrement(@"audioAds.getterOverrides");return value;}
                return ((id(*)(id,SEL,id))original)(object,sel,key);
            });});
        install(NSClassFromString(@"SPTAdsProductState"),@"adsEnabled",'B',2,^IMP(IMP original,SEL sel){
            return imp_implementationWithBlock(^BOOL(id object){
                if(enabled()){USStateIncrement(@"audioAds.adsEnabledOverrides");return NO;}
                return ((BOOL(*)(id,SEL))original)(object,sel);
            });
        });
    }
}
