// Only Spotify data/navigation are mocked. Tab bar, player layout, gradient, profile and settings
// control handling are the production implementations compiled into this simulator app.
#import "Core/SGCore.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/Player/PlayerEvents.h"
#import "Redesigned/Kit/SGRBridges.h"
#import "Shared/Navigation/Links.h"
#import "Headers/SPTEncoreIconView.h"

UIColor *SGRAccentColor(void) { return nil; }
NSString *SGRAccentLabel(void) { return @"Spotify's green"; }
void SGRPickAccent(void) {}
void SGRHomeProfilePhotoPreferenceChanged(void) {}
__weak UIView *sgr_nowPlayingRoot, *sgr_nowPlayingCard, *sgr_lyricsPageRoot, *sgr_playlistRoot, *sgr_albumRoot, *sgr_artistRoot;
void SGOpenModSettings(UIView *source) {}
BOOL SGOpenSpotifyURI(NSURL *uri) { return YES; }
// Native settings/persistence are real; this fixture displays the Redesigned
// bar, so repainting a separate Native bar is outside this settings test.
void SGRefreshTabBar(void) {}
id SGLinkDispatcher(void) { return nil; }
SGLinkRoute SGSpotifyURIRoute(NSURL *uri, NSString **via) { return SGLinkRouteOpens; }
NSURL *SGSpotifyURIFromText(NSString *text) { return [NSURL URLWithString:text]; }
@implementation SPTEncoreIconView
- (instancetype)initWithIcon:(id)icon { return [super initWithFrame:CGRectZero]; }
- (void)setForegroundColor:(UIColor *)color { self.tintColor = color; }
- (void)setActiveForegroundColor:(UIColor *)color {}
- (void)setIsActive:(BOOL)active {}
- (BOOL)isActive { return NO; }
@end

static BOOL fixturePaused;
static NSUInteger fixtureToggleCount, fixtureOpenCount, fixtureNextCount, fixtureTabCount;
static NSString *fixtureLastTab;
static NSHashTable *fixtureObservers;
void FixtureRecordOpen(void) { fixtureOpenCount++; }
void FixtureRecordTab(NSString *title) { fixtureTabCount++; fixtureLastTab = title; }
NSDictionary *FixtureControlState(void) {
    return @{@"toggleCount": @(fixtureToggleCount), @"openCount": @(fixtureOpenCount),
        @"nextCount": @(fixtureNextCount), @"tabCount": @(fixtureTabCount), @"lastTab": fixtureLastTab ?: @""};
}
static void notifyPlayer(void) {
    for (id<SGPlayerStateObserver> observer in fixtureObservers.allObjects) [observer playerStateDidChange:SGPlayerState()];
}
@interface FixturePlayer : NSObject
@end
@implementation FixturePlayer
- (id)pause:(id)options { fixturePaused = YES; fixtureToggleCount++; notifyPlayer(); return @YES; }
- (id)resume:(id)options { fixturePaused = NO; fixtureToggleCount++; notifyPlayer(); return @YES; }
- (id)skipToNextTrackWithOptions:(id)options { fixtureNextCount++; notifyPlayer(); return @YES; }
- (id)skipToPreviousTrackWithOptions:(id)options { return @YES; }
@end

@interface FixtureTrack : NSObject
@property (nonatomic, readonly) NSString *URI, *trackTitle, *artistName;
@end
@implementation FixtureTrack
- (NSString *)URI { return @"spotify:track:fixture"; }
- (NSString *)trackTitle { return @"Stay High"; }
- (NSString *)artistName { return @"Fixture artist"; }
@end
@interface FixtureState : NSObject
@property (nonatomic, readonly) id track;
@property (nonatomic, readonly) BOOL isPaused;
@property (nonatomic, readonly) double position, positionAsOfTimestamp, duration;
@end
@implementation FixtureState
- (id)track { static FixtureTrack *track; if (!track) track = [FixtureTrack new]; return track; }
- (BOOL)isPaused { return fixturePaused; }
- (double)position { return 40; }
- (double)positionAsOfTimestamp { return 40; }
- (double)duration { return 200; }
@end
SPTPlayerState *SGPlayerState(void) { static FixtureState *state; if (!state) state = [FixtureState new]; return (id)state; }
void SGAddPlayerStateObserver(id<SGPlayerStateObserver> observer) {
    if (!fixtureObservers) fixtureObservers = [NSHashTable weakObjectsHashTable];
    [fixtureObservers addObject:observer];
}
NSString *SGURIString(id uri) { return [uri isKindOfClass:NSString.class] ? uri : nil; }
id<SPTPlayer> SGKaraokePlayer(void) { static FixturePlayer *player; if (!player) player = [FixturePlayer new]; return (id)player; }
NSNotificationName const SGPlayerTransitionNotification = @"fixture.player.transition";
NSNotificationName const SGPlayerTransitionEndedNotification = @"fixture.player.transition.ended";
CFTimeInterval SGPlayerTransitionEnds(void) { return 0; }
NSNotificationName const SGRNowPlayingArtworkDidChangeNotification = @"fixture.artwork";
UIImage *SGRNowPlayingArtwork(NSString **track, NSString **identity) { return nil; }
