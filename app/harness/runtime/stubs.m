// Only Spotify data/navigation are mocked. Tab bar, player layout, gradient, profile and settings
// control handling are the production implementations compiled into this simulator app.
#import "Core/SGCore.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/Player/PlayerEvents.h"
#import "Redesigned/Kit/SGRBridges.h"

UIColor *SGRAccentColor(void) { return nil; }
NSString *SGRAccentLabel(void) { return @"Spotify's green"; }
void SGRPickAccent(void) {}
void SGRHomeProfilePhotoPreferenceChanged(void) {}
__weak UIView *sgr_nowPlayingRoot, *sgr_nowPlayingCard, *sgr_lyricsPageRoot, *sgr_playlistRoot, *sgr_albumRoot, *sgr_artistRoot;
void SGRComposeTabBar(UIView *bar) {}
void SGRLogTabBarRow(UIView *bar) {}
void SGRRefreshTabBar(void) {}
void SGOpenModSettings(UIView *source) {}
NSString *const SGRNavbarID = @"id", *const SGRNavbarIcon = @"icon", *const SGRNavbarIconSet = @"iconSet", *const SGRNavbarURI = @"uri";
NSString *const SGTabIconSetSymbols = @"symbols";
NSArray *SGRNavbarLayout(void) { return @[]; }
NSString *SGRNavbarDefaultIcon(NSString *name) { return @""; }
BOOL SGRNavbarEntryHasCustomIcon(NSDictionary *entry) { return NO; }
UIView *SGTabIconView(NSString *name, BOOL symbols, UIColor *color) { return [UIView new]; }

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
- (BOOL)isPaused { return NO; }
- (double)position { return 40; }
- (double)positionAsOfTimestamp { return 40; }
- (double)duration { return 200; }
@end
SPTPlayerState *SGPlayerState(void) { static FixtureState *state; if (!state) state = [FixtureState new]; return (id)state; }
void SGAddPlayerStateObserver(id<SGPlayerStateObserver> observer) {}
NSString *SGURIString(id uri) { return [uri isKindOfClass:NSString.class] ? uri : nil; }
id<SPTPlayer> SGKaraokePlayer(void) { return nil; }
NSNotificationName const SGPlayerTransitionNotification = @"fixture.player.transition";
NSNotificationName const SGPlayerTransitionEndedNotification = @"fixture.player.transition.ended";
CFTimeInterval SGPlayerTransitionEnds(void) { return 0; }
NSNotificationName const SGRNowPlayingArtworkDidChangeNotification = @"fixture.artwork";
UIImage *SGRNowPlayingArtwork(NSString **track, NSString **identity) { return nil; }
