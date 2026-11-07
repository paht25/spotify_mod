#import <UIKit/UIKit.h>
#import "USDiagnosticsUI.h"
#import "USRuntimeState.h"

@interface USModSettings : UITableViewController
@end
@implementation USModSettings {
    NSDictionary *_snapshot;
    NSArray<NSString *> *_statusKeys;
}
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];self.title=@"Unified Spotify";
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    [self refresh];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)refresh { _snapshot=USStateSnapshot();_statusKeys=[_snapshot.allKeys sortedArrayUsingSelector:@selector(compare:)];[self.tableView reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView;return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;return section==0?4:section==1?(NSInteger)_statusKeys.count:1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { (void)tableView;return @[@"Chức năng đã có",@"Trạng thái thực tế",@"Chẩn đoán"][section]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if(section==0)return @"Thay đổi áp dụng cho thao tác hoặc request tiếp theo. Rung chỉ áp dụng cho các nút phát được nhận diện. Làm sạch link áp dụng cho clipboard và link mở sang ứng dụng khác.";
    if(section==1)return @"0 phản hồi đã sửa chưa chứng minh hook lỗi: feed hiện tại có thể không chứa section phù hợp. Bản này chưa có giao diện Chroma, lyrics provider hay Premium patching.";
    return @"Báo cáo chỉ chứa phiên bản, trạng thái hook và bộ đếm; không xuất token hay dữ liệu tài khoản.";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    UIListContentConfiguration *content=[UIListContentConfiguration subtitleCellConfiguration];
    content.textProperties.numberOfLines=0;content.secondaryTextProperties.numberOfLines=0;
    content.textProperties.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];content.textProperties.adjustsFontForContentSizeCategory=YES;
    content.secondaryTextProperties.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];content.secondaryTextProperties.adjustsFontForContentSizeCategory=YES;
    if(indexPath.section==0){
        NSArray *titles=@[@"Lọc section quảng cáo trong feed",@"Chặn popup đánh giá",@"Làm sạch link chia sẻ",@"Rung ở nút phát"];
        NSArray *keys=@[@"unifiedspotify.feedEnabled",@"eeveeBlockRatingPrompts",@"unifiedspotify.cleanShareLinks",@"unifiedspotify.controlHaptics"];
        content.text=titles[indexPath.row];UISwitch *toggle=[UISwitch new];toggle.tag=indexPath.row;
        BOOL fallback=indexPath.row==0 ? YES : indexPath.row==2 ? USSettingEnabled(@"cleanShareLinks",NO) : NO;
        toggle.on=USSettingEnabled(keys[indexPath.row],fallback);toggle.accessibilityLabel=titles[indexPath.row];
        toggle.enabled=[_snapshot[@"activation.allowed"] isEqual:@"yes"];
        [toggle addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;
    }else if(indexPath.section==1){NSString *key=_statusKeys[indexPath.row];content.text=key;content.secondaryText=[_snapshot[key] description];cell.selectionStyle=UITableViewCellSelectionStyleNone;
    }else{content.text=@"Xuất báo cáo trạng thái";cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
    cell.contentConfiguration=content;
    return cell;
}
- (void)changed:(UISwitch *)sender {
    NSArray *keys=@[@"unifiedspotify.feedEnabled",@"eeveeBlockRatingPrompts",@"unifiedspotify.cleanShareLinks",@"unifiedspotify.controlHaptics"];
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:keys[sender.tag]];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];if(indexPath.section!=2)return;
    NSData *data=[NSJSONSerialization dataWithJSONObject:USStateSnapshot() options:NSJSONWritingPrettyPrinted error:NULL];
    NSString *report=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[report ?: @"{}"] applicationActivities:nil];
    share.popoverPresentationController.sourceView=tableView;
    share.popoverPresentationController.sourceRect=[tableView rectForRowAtIndexPath:indexPath];
    [self presentViewController:share animated:YES completion:nil];
}
@end

@interface USModEntry : NSObject
@property(nonatomic,strong) UIButton *button;
+ (instancetype)shared;
- (void)attach;
@end
@implementation USModEntry
+ (instancetype)shared { static USModEntry *entry;static dispatch_once_t once;dispatch_once(&once,^{entry=[USModEntry new];});return entry; }
- (void)attach {
    UIWindow *window=nil;
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){
        if(scene.activationState!=UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class])continue;
        for(UIWindow *candidate in ((UIWindowScene *)scene).windows)if(candidate.isKeyWindow){window=candidate;break;}
        if(window)break;
    }
    if(!window)return;
    if(!self.button){
        self.button=[UIButton buttonWithType:UIButtonTypeSystem];
        UIButtonConfiguration *configuration=[UIButtonConfiguration filledButtonConfiguration];
        configuration.title=@"Mod";configuration.image=[UIImage systemImageNamed:@"slider.horizontal.3"];
        configuration.imagePadding=6;configuration.cornerStyle=UIButtonConfigurationCornerStyleCapsule;
        self.button.configuration=configuration;self.button.accessibilityLabel=@"Mở cài đặt Unified Spotify";
        [self.button addTarget:self action:@selector(open) forControlEvents:UIControlEventTouchUpInside];
    }
    if(self.button.superview==window){[window bringSubviewToFront:self.button];return;}
    [self.button removeFromSuperview];self.button.translatesAutoresizingMaskIntoConstraints=NO;[window addSubview:self.button];
    [NSLayoutConstraint activateConstraints:@[
        [self.button.trailingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.button.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor constant:-140],
        [self.button.heightAnchor constraintGreaterThanOrEqualToConstant:44]]];
}
- (void)open {
    UIViewController *top=((UIWindow *)self.button.window).rootViewController;
    while(top.presentedViewController)top=top.presentedViewController;
    if(!top || top.isBeingDismissed)return;
    if([top isKindOfClass:UINavigationController.class] && [((UINavigationController *)top).topViewController isKindOfClass:USModSettings.class])return;
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:[USModSettings new]];
    [top presentViewController:nav animated:YES completion:nil];
}
@end
void USShowModEntry(void) {
    NSCAssert(NSThread.isMainThread,@"UIKit entry must run on main thread");
    USModEntry *entry=[USModEntry shared];[entry attach];
    static id observer;static dispatch_once_t once;
    dispatch_once(&once,^{observer=[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){(void)note;[[USModEntry shared] attach];}];});
    (void)observer;
    for(NSNumber *delay in @[@1,@3,@8])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[entry attach];});
}
