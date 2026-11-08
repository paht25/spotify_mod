#import <Foundation/Foundation.h>
#import "USAudioAdHooks.h"
#import "USRuntimeState.h"
#import "USHookRegistry.h"
#include <stdlib.h>

// Test-only classes with the selectors/ABI read from the supplied Spotify image.
// These fixtures are not linked into the product and do not prove audible blocking.
@interface SPTCoreProductState : NSObject
@property(nonatomic,copy) NSDictionary *originalValues;
@property(nonatomic,copy) NSDictionary *overrides;
- (NSDictionary *)values;
- (NSString *)stringForKey:(NSString *)key;
- (id)objectForKeyedSubscript:(id)key;
@end
@implementation SPTCoreProductState
- (NSDictionary *)values { return self.originalValues; }
- (NSString *)stringForKey:(NSString *)key { return self.originalValues[key]; }
- (id)objectForKeyedSubscript:(id)key { return self.originalValues[key]; }
@end
@interface SPTAdsProductState : NSObject
- (BOOL)adsEnabled;
@end
@implementation SPTAdsProductState
- (BOOL)adsEnabled { return YES; }
@end
static void require(BOOL ok,NSString *why) {
    if(!ok){NSLog(@"FAIL audio ad policy: %@",why);exit(1);}
}
int main(void) { @autoreleasepool {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    id previous=[defaults objectForKey:@"unifiedspotify.audioAds"];
    NSDictionary *input=@{@"ads":@"1",@"audio-ad-frequency":@"5",@"video-ad-frequency":@"6",
        @"ab-ad-player-targeting":@"1",@"ad-formats":@"audio,video",@"country":@"VN",@"type":@"free",
        @"streaming-rules":@"original",@"offline":@"0",@"quality":@"account-value",@"unknown":@42};
    NSDictionary *result=USAudioAdAttributes(input);
    require([input[@"ads"] isEqual:@"1"],@"input is immutable");
    for(NSString *key in input) {
        BOOL ad=[@[@"ads",@"audio-ad-frequency",@"video-ad-frequency",@"ab-ad-player-targeting"] containsObject:key];
        id expected=[key isEqual:@"ad-formats"]?@"":(ad?@"0":input[key]);
        require([result[key] isEqual:expected],[@"preserve/override " stringByAppendingString:key]);
    }
    require([USAudioAdAttributes(@{}) isEqual:@{@"ads":@"0"}],@"only the ad seed is added");
    require(USAudioAdAttributes(nil)==nil,@"nil safely passes through");
    [defaults setBool:NO forKey:@"unifiedspotify.audioAds"];
    USInstallAudioAdHooks();
    NSUInteger installed=[USStateSnapshot()[@"audioAds.installed"] unsignedIntegerValue];
    require(installed==8,@"eight reviewed method boundaries installed");
    USHookRegistry *registry=[USHookRegistry new];
    require([registry isActiveOnClass:SPTAdsProductState.class selector:@selector(adsEnabled)],@"registered block IMP is active");
    USInstallAudioAdHooks();
    require([USStateSnapshot()[@"audioAds.installed"] unsignedIntegerValue]==installed,@"installation is idempotent");
    SPTCoreProductState *state=[SPTCoreProductState new];
    SPTAdsProductState *ads=[SPTAdsProductState new];
    state.originalValues=input;state.overrides=input;
    require([state.values isEqual:input] && [state.overrides isEqual:input] && ads.adsEnabled,@"disabled state preserves original behavior");
    [defaults setBool:YES forKey:@"unifiedspotify.audioAds"];
    require(!ads.adsEnabled,@"local ads gate disabled");
    require([[state stringForKey:@"ads"] isEqual:@"0"] && [state[@"audio-ad-frequency"] isEqual:@"0"],@"ad getters rewritten");
    require([[state stringForKey:@"ad-formats"] isEqual:@""],@"ad format getter agrees with dictionary");
    require([state.overrides[@"ad-formats"] isEqual:@""],@"previously stored override snapshot is filtered");
    require([[state stringForKey:@"country"] isEqual:@"VN"] && [state[@"type"] isEqual:@"free"],@"account properties untouched");
    state.originalValues=input;state.overrides=input;
    require([state.originalValues isEqual:result] && [state.values isEqual:result] && [state.overrides isEqual:result],@"setters and snapshot getters agree");
    [defaults setBool:NO forKey:@"unifiedspotify.audioAds"];
    state.originalValues=input;state.overrides=input;
    require([state.values isEqual:input] && [state[@"ads"] isEqual:@"1"] && ads.adsEnabled,@"disable restores forwarding for future state");
    Method gate=class_getInstanceMethod(SPTAdsProductState.class,@selector(adsEnabled));
    IMP ours=method_getImplementation(gate);
    IMP outsider=imp_implementationWithBlock(^BOOL(id object){(void)object;return YES;});
    method_setImplementation(gate,outsider);
    require(![registry isActiveOnClass:SPTAdsProductState.class selector:@selector(adsEnabled)],@"later replacement is detected");
    method_setImplementation(gate,ours);imp_removeBlock(outsider);
    if(previous)[defaults setObject:previous forKey:@"unifiedspotify.audioAds"];
    else [defaults removeObjectForKey:@"unifiedspotify.audioAds"];
    NSLog(@"Audio ad policy boundary tests passed; Spotify audio playback remains untested");
} return 0; }
