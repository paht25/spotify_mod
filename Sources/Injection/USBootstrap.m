#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import "USFeedHooks.h"

static void activate(void) {
    NSBundle *app = NSBundle.mainBundle;
    if (![app.executablePath.lastPathComponent isEqual:@"Spotify"]) return;
    NSString *version = [app objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (![version isEqual:@"9.1.90"]) {
        NSLog(@"[UnifiedSpotify] Experimental feed module skipped: unsupported Spotify %@", version); return;
    }
    for (uint32_t i=0;i<_dyld_image_count();i++) {
        NSString *name = [[NSString stringWithUTF8String:_dyld_get_image_name(i)] lastPathComponent].lowercaseString;
        if ([name isEqual:@"spotifyglass.dylib"] || [name isEqual:@"eeveespotify.dylib"]) {
            NSLog(@"[UnifiedSpotify] Remove original Chroma/Eevee dylibs before this isolated feed test"); return;
        }
    }
    for (NSString *name in @[@"SPTDataLoaderService", @"Connectivity_HttpClientKit.HttpClientURLSession",
                             @"_TtC26Connectivity_HttpClientKit20HttpClientURLSession"]) {
        Class cls = NSClassFromString(name); if (!cls) continue;
        NSError *error = nil;
        BOOL ok = USInstallFeedHooks(cls, &error);
        NSLog(@"[UnifiedSpotify] Feed delegate %@: %@", name, ok ? @"active" : error.localizedDescription);
    }
}
__attribute__((constructor)) static void USStart(void) {
    @autoreleasepool {
        // Give the app's linked frameworks a chance to finish class registration.
        dispatch_async(dispatch_get_main_queue(), ^{ activate(); });
    }
}
