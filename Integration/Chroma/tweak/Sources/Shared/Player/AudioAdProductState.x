#import "Core/USUnifiedTransport.h"
#import "Core/USRuntimeState.h"
#import "Core/USAudioAdHooks.h"
#import <objc/runtime.h>

// Seed the real product-state input before its C++ playback state is created.
// Scheduler is an opaque pointer, passed through unchanged. Selector and ABI
// are present in the supplied 9.1.90 image; no backend/write API is intercepted.
%hook SPTCoreProductState
- (id)initWithValuesDict:(NSDictionary *)values scheduler:(void *)scheduler {
    if(!USSettingEnabled(@"unifiedspotify.audioAds",YES))return %orig;
    USStateIncrement(@"audioAds.initializers");
    return %orig(USAudioAdAttributes(values),scheduler);
}
%end

%ctor {
    if (!USUnifiedTargetSupported()) return;
    Method method=class_getInstanceMethod(NSClassFromString(@"SPTCoreProductState"),NSSelectorFromString(@"initWithValuesDict:scheduler:"));
    char result[64]={0},values[64]={0},scheduler[64]={0};
    if(method){method_getReturnType(method,result,sizeof(result));method_getArgumentType(method,2,values,sizeof(values));method_getArgumentType(method,3,scheduler,sizeof(scheduler));}
    if(!method || method_getNumberOfArguments(method)!=4 || result[0]!='@' || values[0]!='@' || scheduler[0]!='^'){
        USStateSet(@"audioAdHook.initializer",@"selector absent or ABI rejected");return;
    }
    %init;
    USStateSet(@"audioAdHook.initializer",@"installed");
}
