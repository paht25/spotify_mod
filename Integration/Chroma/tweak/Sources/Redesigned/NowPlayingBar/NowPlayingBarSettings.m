// The Now playing page of the redesign, under Player (App/Pages.m puts it there): the bar and the
// player behind it.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "NowPlayingBar.h"
#import "Redesigned/Player/Player.h"

UIViewController *SGRNowPlayingBarSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Now playing" intro:SGRestartNote sections:@[
        SGSection(nil, @[
            SGHideRow(@"Hide the device button", nil, SGRHideBarConnect),
        ]),
        SGSection(nil, @[
            SGSwitchRow(@"Moving background", @"Artwork colors; black background takes priority", SGRKeyPlayerMotion),
            SGOptionRow(@"Black player background", @"Keep controls and optional audio visualization over black", SGRKeyPlayerBlack),
            SGSwitchRow(@"Glass behind header buttons", @"Keep the close and menu controls with or without glass", SGRKeyPlayerHeaderGlass),
            SGHideRow(@"Hide shuffle", @"Restart to restore a hidden control", SGRKeyPlayerHideShuffle),
            SGHideRow(@"Hide repeat", @"Restart to restore a hidden control", SGRKeyPlayerHideRepeat),
        ]),
    ] footer:nil];
}
