#import <UIKit/UIKit.h>

#define SGRHideBarConnect @"spotifyglass.redesign.hide.barConnect"   // the device button on the card
#define SGRKeyNowPlayingRoundedArtwork @"spotifyglass.redesign.nowPlayingBar.roundedArtwork"
#define SGRKeyNowPlayingProgressThickness @"spotifyglass.redesign.nowPlayingBar.progressThickness"

@class SGModRow;

UIViewController *SGRNowPlayingBarSettingsPage(void);
NSArray<SGModRow *> *SGRNowPlayingBarRows(void);   // the Mini player section on the redesign's Player page

CGRect SGRNowPlayingCardFrameIn(UIView *host, CGFloat *radius);
// The artwork on that card in `host`'s coordinates; CGRectNull when none was found.
CGRect SGRNowPlayingArtworkFrameIn(UIView *host);
void SGRNowPlayingBarRefresh(void);

// Complete 0.23.0 Apple Music style player option, read at launch.
#define SGRKeyInlinePlayer @"spotifyglass.redesign.inlinePlayer"
BOOL SGRInlinePlayer(void);
UIImage *SGRNowPlayingArtworkImage(void);
UIImageView *SGRNowPlayingArtworkView(void);
BOOL SGROpenPlayerFromBar(void);
UIView *SGRMakeMiniPlayer(void);
CGRect SGRMiniPlayerFrameIn(UIView *host, CGFloat *radius);
CGRect SGRMiniPlayerArtworkFrameIn(UIView *host);
CGFloat SGRNowPlayingExpandedHeight(void);
void SGRRefreshMiniPlayerSize(void);
