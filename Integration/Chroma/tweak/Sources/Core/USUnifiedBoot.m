#import "USUnifiedTransport.h"
#import "USUtilityHooks.h"
#import "USRuntimeState.h"
#import "USEeveeServices.h"
#import "USAudioAdHooks.h"
#import "USRuntimeInspection.h"
__attribute__((constructor)) static void unifiedStart(void) {
    @autoreleasepool {
        if(!USUnifiedTargetSupported())return;
        USInstallEeveeServices();
        USInstallAudioAdHooks();
        NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
        // Preserve the previous private build's choice without overwriting an
        // existing Chroma setting. Chroma is the sole haptic owner in this build.
        id legacy=[defaults objectForKey:@"unifiedspotify.controlHaptics"];
        if(legacy && ![defaults objectForKey:@"spotifyglass.haptics.controls"])
            [defaults setObject:legacy forKey:@"spotifyglass.haptics.controls"];
        if(![defaults objectForKey:@"unifiedspotify.premiumPatching"] && [defaults objectForKey:@"patchType"] && [defaults integerForKey:@"patchType"]!=0)
            [defaults setBool:[defaults integerForKey:@"patchType"]!=1 forKey:@"unifiedspotify.premiumPatching"];
        if(![defaults objectForKey:@"unifiedspotify.cleanShareLinks"] && [defaults objectForKey:@"cleanShareLinks"])
            [defaults setObject:[defaults objectForKey:@"cleanShareLinks"] forKey:@"unifiedspotify.cleanShareLinks"];
        dispatch_async(dispatch_get_main_queue(),^{
            USStateSet(@"build",@"personal-v6-9190");USStateSet(@"spotify",@"9.1.90");
            USStateSet(@"renderOwner",@"Chroma native/redesigned profiles");
            USStateSet(@"networkOwner",@"Composed Chroma delegate + Eevee transforms");
            USInstallUtilityHooks();
            USRefreshRuntimeDiagnostics();
            for(NSNumber *delay in @[@1,@3,@8])
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{USInstallEeveeServices();USInstallAudioAdHooks();});
        });
    }
}
