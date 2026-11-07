#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import "USFeedHooks.h"
#import "USUtilityHooks.h"
#import "USDiagnosticsUI.h"
#import "USRuntimeState.h"

static void activate(void) {
    NSBundle *app = NSBundle.mainBundle;
    if (![app.executablePath.lastPathComponent isEqual:@"Spotify"]) return;
    NSString *version = [app objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    USStateSet(@"build",@"personal-sidebar-v4-9188");USStateSet(@"dylib",@"loaded");
    USStateSet(@"spotify",version ?: @"unknown");USStateSet(@"activation.allowed",@"no");
    USShowModEntry();
    if (![version isEqual:@"9.1.88"]) {
        USStateSet(@"activation.reason",@"Spotify version is not 9.1.88");
        NSLog(@"[UnifiedSpotify] Experimental feed module skipped: unsupported Spotify %@", version); return;
    }
    for (uint32_t i=0;i<_dyld_image_count();i++) {
        NSString *name = [[NSString stringWithUTF8String:_dyld_get_image_name(i)] lastPathComponent].lowercaseString;
        if ([name isEqual:@"spotifyglass.dylib"] || [name isEqual:@"eeveespotify.dylib"]) {
            USStateSet(@"activation.reason",@"Original Chroma/Eevee dylib detected; hooks skipped");
            NSLog(@"[UnifiedSpotify] Remove original Chroma/Eevee dylibs before this isolated feed test"); return;
        }
    }
    USStateSet(@"activation.allowed",@"yes");
    static BOOL utilitiesInstalled;
    if(!utilitiesInstalled){USInstallUtilityHooks();utilitiesInstalled=YES;}
    for (NSString *name in @[@"SPTDataLoaderService", @"Connectivity_HttpClientKit.HttpClientURLSession",
                             @"_TtC26Connectivity_HttpClientKit20HttpClientURLSession"]) {
        Class cls = NSClassFromString(name);
        if (!cls) { USStateSet([@"hook." stringByAppendingString:name],@"class absent");continue; }
        NSError *error = nil;
        BOOL ok = USInstallFeedHooks(cls, &error);
        USStateSet([@"hook." stringByAppendingString:name],ok?@"active":error.localizedDescription);
        NSLog(@"[UnifiedSpotify] Feed delegate %@: %@", name, ok ? @"active" : error.localizedDescription);
    }
}
__attribute__((constructor)) static void USStart(void) {
    @autoreleasepool {
        // Give the app's linked frameworks a chance to finish class registration.
        dispatch_async(dispatch_get_main_queue(), ^{ activate(); });
        for(NSNumber *delay in @[@1,@3,@8])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{activate();});
    }
}
