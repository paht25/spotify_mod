#import "USRuntimeInspection.h"
#import "USRuntimeState.h"
#import "SGUIMode.h"
#import "SGPrefs.h"
#import <objc/runtime.h>
#import <dlfcn.h>

static void inspect(NSString *label,NSString *name,NSString *methodName) {
    Class cls=NSClassFromString(name);NSString *key=[@"runtimeHook." stringByAppendingString:label];
    if(!cls){USStateSet(key,@"class unavailable");return;}
    Method method=class_getInstanceMethod(cls,NSSelectorFromString(methodName));
    if(!method){USStateSet(key,@"selector unavailable");return;}
    Dl_info info={0};IMP implementation=method_getImplementation(method);
    if(!dladdr((const void *)implementation,&info)||!info.dli_fname){USStateSet(key,@"implementation image unresolved");return;}
    NSString *image=[NSString stringWithUTF8String:info.dli_fname].lastPathComponent;
    USStateSet(key,[image.lowercaseString isEqual:@"spotifyglass.dylib"]?@"unified implementation active":image);
}
void USRefreshRuntimeDiagnostics(void) {
    USStateSet(@"mode.active",SGRedesignedUI()?@"redesigned":@"native");
    USStateSet(@"mode.stored",SGRedesignedUIStored()?@"redesigned":@"native");
    USStateSet(@"mode.stockDefaults",[NSUserDefaults.standardUserDefaults boolForKey:SGKeyStock]?@"yes":@"no");
    USStateSet(@"ui.requiresCompatibility",[[NSBundle.mainBundle objectForInfoDictionaryKey:@"UIDesignRequiresCompatibility"] boolValue]?@"yes":@"no");
    inspect(@"flags",@"_TtC22RemoteConfigurationSDK25ConfigurationProviderImpl",@"boolValueForId:defaultValue:");
    inspect(@"observableFlags",@"_TtC22RemoteConfigurationSDK35ObservableConfigurationProviderImpl",@"boolValueForId:defaultValue:");
    inspect(@"playerBackground",@"_TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController",@"viewDidLayoutSubviews");
    inspect(@"playerHeader",@"_TtC20NowPlaying_ModesImpl18HeaderElementsUnit",@"viewDidLayoutSubviews");
    inspect(@"playButton",@"_TtC28EncoreConsumerMobile_BaseKit14PlayButtonView",@"uiButtonTapped");
    inspect(@"tabBar",@"_TtC23NavigationUI_TabBarImpl10TabBarView",@"layoutSubviews");
    inspect(@"playerMorph",@"SPTBarOverlayPresentationTransition",@"setProgress:");
    inspect(@"audioAdPolicy",@"SPTAdsProductState",@"adsEnabled");
    inspect(@"productState",@"SPTCoreProductState",@"stringForKey:");
}
