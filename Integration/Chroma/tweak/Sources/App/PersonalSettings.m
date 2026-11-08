#import "PersonalSettings.h"
#import "Core/SGCore.h"
#import "Core/USRuntimeState.h"
#import "Core/USFontOverrides.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Shared/Personal/USAssetStore.h"
#import "Shared/Personal/USWebDisplay.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface USPersonalLibraryPage : SGPage <UIDocumentPickerDelegate>
@end
@implementation USPersonalLibraryPage {
    NSArray<NSDictionary *> *_assets;
    BOOL _busy;
}
- (instancetype)init {if((self=[super initWithStyle:UITableViewStyleInsetGrouped]))self.title=@"Local Workshop";return self;}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableHeaderView=SGNote(@"Import your own shaders, fonts, audio presets and headphone EQ. Files stay on this device.");
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(libraryChanged:) name:@"UnifiedPersonalLibraryChanged" object:nil];
    [self refresh];
}
- (void)dealloc {[NSNotificationCenter.defaultCenter removeObserver:self];}
- (void)libraryChanged:(NSNotification *)notification {(void)notification;[self refresh];}
- (void)refresh {_assets=USPersonalAssets();[self.tableView reloadData];}
- (void)viewWillAppear:(BOOL)animated {[super viewWillAppear:animated];[self refresh];}
- (void)viewDidLayoutSubviews {[super viewDidLayoutSubviews];SGFitNote(self.tableView,self.tableView.tableHeaderView,12,12);SGInsetForBars(self.tableView);}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {(void)table;return 2;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {(void)table;return section==0?1:MAX(1,_assets.count);}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {(void)table;return section==0?@"Import":@"Your files";}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index {
    UITableViewCell *cell=SGDequeueCell(table,@"personalAsset");cell.accessoryType=UITableViewCellAccessoryNone;cell.selectionStyle=UITableViewCellSelectionStyleDefault;
    if(index.section==0)SGFillCell(cell,_busy?@"Importing…":@"Import file",@"Shader, font, audio preset or headphone EQ",nil,@"square.and.arrow.down");
    else if(!_assets.count){SGFillCell(cell,@"No files yet",@"Imported files stay on this device",nil,@"folder");cell.selectionStyle=UITableViewCellSelectionStyleNone;}
    else {NSDictionary *asset=_assets[index.row];SGFillCell(cell,asset[@"title"]?:asset[@"name"],asset[@"kind"],nil,@"doc");cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
    return cell;
}
- (void)message:(NSString *)title text:(NSString *)text {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index {
    [table deselectRowAtIndexPath:index animated:YES];if(_busy)return;
    if(index.section==0){
        UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeData] asCopy:NO];
        picker.delegate=self;picker.allowsMultipleSelection=NO;[self presentViewController:picker animated:YES completion:nil];return;
    }
    if(index.row>=(NSInteger)_assets.count)return;NSDictionary *asset=_assets[index.row];
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:asset[@"title"]?:asset[@"name"] message:asset[@"kind"] preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Apply" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;NSError *error=nil;
        if(!USApplyPersonalAsset(asset,&error))[self message:@"Could not apply" text:error.localizedDescription];
        else {
            NSDictionary *notes=@{@"font":@"Restart Spotify to update existing text. Icons and embedded custom fonts keep their original design.",@"shader":@"The enabled visualizer will compile this shader. Check Shader status for any error."};
            [self message:@"Applied" text:notes[asset[@"kind"]]?:@"Audio settings were applied to the DSP engine."];
        }
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        (void)action;NSError *error=nil;if(!USDeletePersonalAsset(asset,&error))[self message:@"Could not delete" text:error.localizedDescription];[self refresh];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView=table;
    sheet.popoverPresentationController.sourceRect=[table rectForRowAtIndexPath:index];[self presentViewController:sheet animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;if(!urls.count)return;_busy=YES;[self.tableView reloadData];
    NSURL *url=urls.firstObject;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSError *error=nil;NSDictionary *asset=USImportPersonalAsset(url,&error);
        dispatch_async(dispatch_get_main_queue(),^{self->_busy=NO;[self refresh];if(!asset)[self message:@"Could not import" text:error.localizedDescription];});
    });
}
@end
UIViewController *USPersonalSettingsPage(void) {
    SGModRow *visual=SGOptionRow(@"Audio-reactive background",@"Redesigned player; restart after changing",@"unifiedspotify.personal.visualizer");
    SGModRow *style=SGChoiceRow(@"Built-in style",nil,@"unifiedspotify.personal.visualizerStyle",@[@"Spectrum",@"Orbit",@"Wave"],0);
    SGModRow *gain=SGSliderRow(@"Sensitivity",nil,.2,4,.1,^double{
        double value=[NSUserDefaults.standardUserDefaults doubleForKey:@"unifiedspotify.personal.visualizerGain"];return value>0?value:1;
    },^(double value){[NSUserDefaults.standardUserDefaults setDouble:value forKey:@"unifiedspotify.personal.visualizerGain"];},^NSString *(double value){return [NSString stringWithFormat:@"%.1f×",value];});
    SGModRow *library=SGPageRow(@"Local Workshop",^UIViewController *{return [USPersonalLibraryPage new];});
    SGModRow *font=SGActionRow(@"Use system font",@"Restart to update existing text",^{[NSUserDefaults.standardUserDefaults removeObjectForKey:@"unifiedspotify.personal.fontFile"];USSetPersonalFontName(nil);});
    SGModRow *shader=SGActionRow(@"Use built-in shader",nil,^{[NSUserDefaults.standardUserDefaults removeObjectForKey:@"unifiedspotify.personal.shaderFile"];[NSNotificationCenter.defaultCenter postNotificationName:@"UnifiedPersonalLibraryChanged" object:nil];});
    SGModRow *tap=SGStatRow(@"Audio source",^NSString *{return USStateSnapshot()[@"personal.audioTap"]?:@"Not observed yet";});
    SGModRow *status=SGStatRow(@"Shader",^NSString *{return USStateSnapshot()[@"personal.shader"]?:@"Open the player to initialize";});
    SGModRow *web=SGOptionRow(@"Web display",@"Private Wi-Fi only; sound stays on this phone",@"unifiedspotify.personal.webDisplay");
    web.changed=^(BOOL on){if(on)USStartWebDisplay();else USStopWebDisplay();};
    SGModRow *control=SGOptionRow(@"Allow browser playback control",@"Anyone with your private link can send playback commands",@"unifiedspotify.personal.webControl");
    SGModRow *webStatus=SGStatRow(@"Web display status",^NSString *{return USWebDisplayStatus();});
    SGModRow *link=SGActionRow(@"Copy private link",@"Open on another screen in the same Wi-Fi; link changes after restart",^{
        NSString *url=USWebDisplayLink();
        if(url.length)UIPasteboard.generalPasteboard.string=url;
        else {
            UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Web display" message:USWebDisplayStatus() preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[SGTopController() presentViewController:alert animated:YES completion:nil];
        }
    });
    return [[SGModPage alloc]initWithTitle:@"Personal features" intro:@"Independent local modules. Spotify sign-in stays unchanged."
        sections:@[SGSection(@"Player",@[visual,style,gain]),SGSection(@"Your library",@[library,font,shader]),SGSection(@"Web display",@[web,control,webStatus,link]),SGSection(@"Status",@[tap,status])]
        footer:@"Ambient and Sing are excluded by choice. Local features are independent; remote Workshop and other 1.0.1 additions remain incomplete."];
}
