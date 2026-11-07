#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "USEeveeServices.h"
#include <stdlib.h>
static NSUInteger loads,durationCalls;
static BOOL enabled;
static void loadFixture(id self,SEL cmd){(void)self;(void)cmd;loads++;}
static void durationFixture(id self,SEL cmd,NSInteger value){(void)self;(void)cmd;(void)value;durationCalls++;}
static void enabledFixture(id self,SEL cmd,BOOL value){(void)self;(void)cmd;enabled=value;}
static BOOL shuffleFixture(id self,SEL cmd){(void)self;(void)cmd;return YES;}
static BOOL shuffleTrackFixture(id self,SEL cmd,id track){(void)self;(void)cmd;(void)track;return YES;}
static Class makeClass(const char *name){Class cls=objc_allocateClassPair(NSObject.class,name,0);if(!cls)abort();return cls;}
static void require(BOOL ok,NSString *why){if(!ok){NSLog(@"FAIL service hook: %@",why);exit(1);}}
int main(void){@autoreleasepool{
    // Runtime fixtures exist only in this test executable. No Spotify code or
    // network is simulated in the shipped tweak; these test ABI and forwarding.
    Class ad=makeClass("_TtC29AdsNowPlaying_InStreamAdsImpl18InStreamAdsService");
    class_addMethod(ad,NSSelectorFromString(@"load"),(IMP)loadFixture,"v16@0:8");objc_registerClassPair(ad);
    Class sh=makeClass("_TtC21SmartShuffle_CoreImpl33SmartShuffleHandlerImplementation");
    class_addMethod(sh,NSSelectorFromString(@"checkRecommendationsEnabled"),(IMP)shuffleFixture,"B16@0:8");
    class_addMethod(sh,NSSelectorFromString(@"recommendationIsBeingAddedWithTrackID:"),(IMP)shuffleTrackFixture,"B24@0:8@16");objc_registerClassPair(sh);
    Class prefs=makeClass("_TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation");
    class_addMethod(prefs,NSSelectorFromString(@"setAudioCrossfadeTime:"),(IMP)durationFixture,"v24@0:8q16");
    class_addMethod(prefs,NSSelectorFromString(@"setAudioCrossfade:"),(IMP)enabledFixture,"v20@0:8B16");objc_registerClassPair(prefs);
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    [defaults setBool:YES forKey:@"unifiedspotify.adServices"];
    USInstallEeveeServices();USInstallEeveeServices();
    id obj=[ad new];((void(*)(id,SEL))objc_msgSend)(obj,NSSelectorFromString(@"load"));require(loads==0,@"ad service suppressed");
    [defaults setBool:NO forKey:@"unifiedspotify.adServices"];
    ((void(*)(id,SEL))objc_msgSend)(obj,NSSelectorFromString(@"load"));require(loads==1,@"original called once after disabling");
    id shuffle=[sh new];SEL check=NSSelectorFromString(@"checkRecommendationsEnabled"),track=NSSelectorFromString(@"recommendationIsBeingAddedWithTrackID:");
    [defaults setBool:NO forKey:@"trueShuffleEnabled"];
    require(((BOOL(*)(id,SEL))objc_msgSend)(shuffle,check),@"preserve original shuffle gate");
    [defaults setBool:YES forKey:@"trueShuffleEnabled"];
    require(!((BOOL(*)(id,SEL))objc_msgSend)(shuffle,check),@"disable recommendations");
    require(!((BOOL(*)(id,SEL,id))objc_msgSend)(shuffle,track,@"spotify:track:test"),@"disable recommendation insertion");
    [defaults setBool:YES forKey:@"unifiedspotify.crossfadeSync"];
    id preferences=[prefs new];SEL duration=NSSelectorFromString(@"setAudioCrossfadeTime:");
    ((void(*)(id,SEL,NSInteger))objc_msgSend)(preferences,duration,4);require(enabled && durationCalls==1,@"positive crossfade duration enables once");
    ((void(*)(id,SEL,NSInteger))objc_msgSend)(preferences,duration,0);require(!enabled && durationCalls==2,@"zero disables crossfade");
    for(NSString *key in @[@"unifiedspotify.adServices",@"trueShuffleEnabled",@"unifiedspotify.crossfadeSync"])[defaults removeObjectForKey:key];
    NSLog(@"Service hook boundary tests passed; audible ad blocking and Spotify playback remain untested");
}return 0;}
