#import "Core/SGCore.h"
#import "Core/USUnifiedTransport.h"
#import "Core/USRuntimeState.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"

UIViewController *USUnifiedSettingsPage(void) {
    SGModRow *patch=SGSwitchRow(@"Eevee bootstrap / config patch",@"Uses original Eevee account/flag transforms; server rights remain server-owned",@"unifiedspotify.premiumPatching");
    SGModRow *overwrite=SGOptionRow(@"Overwrite configuration",@"Original 9.1.76+ snapshot; applies to the next matching response",@"overwriteConfiguration");
    SGModRow *feed=SGSwitchRow(@"Filter promotional feed sections",@"Eevee feed transform runs before Chroma's lyric-card insertion",@"unifiedspotify.feedEnabled");
    SGModRow *ratings=SGOptionRow(@"Block rating requests",nil,@"eeveeBlockRatingPrompts");
    SGModRow *links=SGOptionRow(@"Clean shared Spotify links",@"Clipboard and outgoing deep links",@"unifiedspotify.cleanShareLinks");
    SGModRow *ads=SGSwitchRow(@"Block ad and upsell services",@"Original Eevee service targets, with runtime ABI checks",@"unifiedspotify.adServices");
    SGModRow *shuffle=SGOptionRow(@"True shuffle",@"Stop Smart Shuffle recommendations",@"trueShuffleEnabled");
    SGModRow *crossfade=SGSwitchRow(@"Keep crossfade enabled with its duration",nil,@"unifiedspotify.crossfadeSync");
    SGModRow *selected=SGStatRow(@"Responses selected",^NSString *{return [USStateSnapshot()[@"network.selected"] description] ?: @"0";});
    SGModRow *changed=SGStatRow(@"Responses transformed",^NSString *{return [USStateSnapshot()[@"network.transformed"] description] ?: @"0";});
    SGModRow *services=SGStatRow(@"Service hooks installed",^NSString *{return [USStateSnapshot()[@"services.installed"] description] ?: @"0";});
    SGModRow *suppressed=SGStatRow(@"Service loads blocked",^NSString *{return [USStateSnapshot()[@"services.suppressed"] description] ?: @"0";});
    SGModRow *diagnostics=SGActionRow(@"Share diagnostic report",nil,^{
        NSData *data=[NSJSONSerialization dataWithJSONObject:USStateSnapshot() options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
        if(!data)return;
        NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"UnifiedSpotify-diagnostics.json"]];
        if(![data writeToURL:url atomically:YES])return;
        UIViewController *top=SGTopController();
        UIActivityViewController *sheet=[[UIActivityViewController alloc]initWithActivityItems:@[url] applicationActivities:nil];
        sheet.popoverPresentationController.sourceView=top.view;
        [top presentViewController:sheet animated:YES completion:nil];
    });
    return [[SGModPage alloc] initWithTitle:@"Eevee integration" intro:@"Private integration test for Spotify 9.1.88 on iOS 27"
        sections:@[SGNotedSection(@"Network",@[patch,overwrite,feed,ads],@"Changes apply to future responses. Restart Spotify to cause bootstrap to be fetched again. This does not grant backend-only entitlements."),
                   SGSection(@"Playback",@[shuffle,crossfade]),
                   SGSection(@"Sharing and prompts",@[ratings,links]),SGSection(@"Diagnostics",@[selected,changed,services,suppressed,diagnostics])]
        footer:@"Chroma owns the player, lyrics, artwork and visual settings. Its controls and profiles remain in their original pages. This build still requires device verification; not every Eevee-specific feature is ported."];
}
