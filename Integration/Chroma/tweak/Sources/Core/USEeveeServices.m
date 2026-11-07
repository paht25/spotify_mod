// Adapted from EeveeSpotify v7.0.0 (GPL-3.0):
// EeveeAdBlockerExtended.x.swift, UpsellServiceBlocker.x.swift,
// Premium/TrueShuffle.x.swift and EeveeCrossfadeForce.x.swift.
// Uses one reviewed Objective-C implementation per selector; no Swift offset
// guessing and no Orion runtime or original Eevee dylib are loaded.
#import "USEeveeServices.h"
#import "USUnifiedTransport.h"
#import "USHookRegistry.h"
#import "USRuntimeState.h"
#import <objc/message.h>
#include <string.h>

static BOOL signature(Method method,const char *result,NSArray<NSString *> *arguments) {
    if(!method || method_getNumberOfArguments(method)!=arguments.count+2)return NO;
    char type[64]={0};method_getReturnType(method,type,sizeof(type));
    if(strcmp(type,result))return NO;
    for(NSUInteger i=0;i<arguments.count;i++){
        method_getArgumentType(method,(unsigned int)i+2,type,sizeof(type));
        if(strcmp(type,arguments[i].UTF8String))return NO;
    }return YES;
}
static BOOL install(Class cls,SEL selector,IMP implementation,IMP original) {
    Method method=class_getInstanceMethod(cls,selector);NSError *error=nil;
    BOOL ok=[[USHookRegistry new]installOnClass:cls selector:selector owner:@"unified.eevee-services"
        expectedEncoding:method_getTypeEncoding(method) expectedOriginal:original replacement:implementation error:&error];
    if(!ok){imp_removeBlock(implementation);USStateSet([@"service." stringByAppendingString:NSStringFromClass(cls)],error.localizedDescription);}
    return ok;
}
static void service(NSString *name) {
    Class cls=NSClassFromString(name);SEL sel=NSSelectorFromString(@"load");
    NSString *stateKey=[@"service." stringByAppendingString:name];
    if(!cls){USStateSet(stateKey,@"class unavailable");return;}
    if([[USHookRegistry new]ownerOfClass:cls selector:sel])return;
    Method method=class_getInstanceMethod(cls,sel);
    if(!signature(method,"v",@[])){USStateSet(stateKey,@"load selector unavailable or ABI rejected");return;}
    IMP original=method_getImplementation(method);
    IMP replacement=imp_implementationWithBlock(^(id object){
        if(USSettingEnabled(@"unifiedspotify.adServices",YES)){USStateIncrement(@"services.suppressed");return;}
        ((void(*)(id,SEL))original)(object,sel);
    });
    if(install(cls,sel,replacement,original)){USStateSet(stateKey,@"installed");USStateIncrement(@"services.installed");}
}
static void shuffle(NSString *name,BOOL takesArgument) {
    Class cls=NSClassFromString(@"_TtC21SmartShuffle_CoreImpl33SmartShuffleHandlerImplementation");
    if(!cls)return;SEL sel=NSSelectorFromString(name);
    if([[USHookRegistry new]ownerOfClass:cls selector:sel])return;
    Method method=class_getInstanceMethod(cls,sel);
    if(!signature(method,"B",takesArgument?@[@"@"]:@[])){USStateSet([@"shuffle." stringByAppendingString:name],@"ABI rejected");return;}
    IMP original=method_getImplementation(method),replacement;
    if(takesArgument)replacement=imp_implementationWithBlock(^BOOL(id object,id track){
        if(USSettingEnabled(@"trueShuffleEnabled",NO))return NO;
        return ((BOOL(*)(id,SEL,id))original)(object,sel,track);
    });
    else replacement=imp_implementationWithBlock(^BOOL(id object){
        if(USSettingEnabled(@"trueShuffleEnabled",NO))return NO;
        return ((BOOL(*)(id,SEL))original)(object,sel);
    });
    if(install(cls,sel,replacement,original))USStateSet([@"shuffle." stringByAppendingString:name],@"installed");
}
static void crossfade(void) {
    Class cls=NSClassFromString(@"_TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation");
    if(!cls)return;SEL sel=NSSelectorFromString(@"setAudioCrossfadeTime:"),enable=NSSelectorFromString(@"setAudioCrossfade:");
    if([[USHookRegistry new]ownerOfClass:cls selector:sel])return;
    Method method=class_getInstanceMethod(cls,sel);
    if(!signature(method,"v",@[@"q"]) || !signature(class_getInstanceMethod(cls,enable),"v",@[@"B"])){
        USStateSet(@"crossfade",@"ABI rejected");return;
    }
    IMP original=method_getImplementation(method);
    IMP replacement=imp_implementationWithBlock(^(id object,NSInteger value){
        ((void(*)(id,SEL,NSInteger))original)(object,sel,value);
        if(USSettingEnabled(@"unifiedspotify.crossfadeSync",YES))
            ((void(*)(id,SEL,BOOL))objc_msgSend)(object,enable,value>0);
    });
    if(install(cls,sel,replacement,original))USStateSet(@"crossfade",@"installed");
}
void USInstallEeveeServices(void) {
    @synchronized(USHookRegistry.class){
        // Exact original Eevee load targets. Missing ObjC selectors are reported
        // and skipped: a matching Swift class name alone proves no callable ABI.
        for(NSString *name in @[
            @"_TtC19AdsPlatform_AdsImpl14AdsServiceImpl",
            @"_TtC29AdsNowPlaying_InStreamAdsImpl18InStreamAdsService",
            @"_TtC29AdsNowPlaying_EmbeddedNPVImpl22EmbeddedNPVServiceImpl",
            @"_TtC36AdsStandalone_LeavebehindAdsBaseImpl25LeavebehindAdsBaseService",
            @"_TtC36AdsStandalone_LeavebehindAdsBaseImpl33LeavebehindAdsBaseInternalService",
            @"_TtC35AdsEmbedded_AdsSponsoredContextImpl30AdsSponsoredContextServiceImpl",
            @"_TtC48AdsEmbedded_AdsSponsoredContextNPBAttachmentImpl43AdsSponsoredContextNPBAttachmentServiceImpl",
            @"_TtC42AdsEmbedded_AdsSponsoredPlaylistHeaderImpl37AdsSponsoredPlaylistHeaderServiceImpl",
            @"_TtC20NativeAds_LoggerImpl26NativeAdsLoggerServiceImpl",
            @"_TtC35AdsEmbedded_EmbeddedCTAElementsImpl30EmbeddedCTAElementsServiceImpl",
            @"_TtC36AdsEmbedded_EmbeddedAdControllerImpl31EmbeddedAdControllerServiceImpl",
            @"_TtC35AdsEmbedded_EmbeddedCTAElementsImpl32EmbeddedAdAdapterElementProvider",
            @"_TtC32AdsEmbedded_EmbeddedPlaylistImpl22PlaylistAdControllerV2",
            @"_TtC32AdsEmbedded_EmbeddedPlaylistImpl24PlaylistAdControllerImpl",
            @"_TtC37AdsEmbedded_EmbeddedAdPresentationKit28LeavebehindAdElementProvider",
            @"_TtC19Upsells_ServiceImpl18UpsellsServiceImpl",
            @"_TtC31PremiumUpsell_UpsellServiceImpl17UpsellServiceImpl",
            @"_TtC45ReinventFree_ContextualUpsellPremiumPromoImpl39ContextualUpsellPremiumPromoServiceImpl",
            @"_TtC40Referrals_ReferralsUpsellCardElementImpl37ReferralsUpsellCardElementServiceImpl",
            @"_TtC31ReinventFree_DownloadUpsellImpl21DownloadUpsellService",
            @"_TtC28Jam_FreeHostedJamsUpsellImpl31FreeHostedJamsUpsellServiceImpl",
            @"_TtC30Jam_FreeUserSkipUpsellPageImpl29FreeUserSkipUpsellPageService",
            @"_TtC38Jam_FreeUserShuffleUpsellSheetPageImpl37FreeUserShuffleUpsellSheetPageService"
        ])service(name);
        shuffle(@"checkRecommendationsEnabled",NO);shuffle(@"recommendationIsBeingAddedWithTrackID:",YES);crossfade();
    }
}
