#import <UIKit/UIKit.h>
#import "USDiagnosticsUI.h"
#import "USRuntimeState.h"
#import "USHookRegistry.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>

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
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;return section==0?6:section==1?(NSInteger)_statusKeys.count:1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { (void)tableView;return @[@"Chức năng đã có",@"Trạng thái thực tế",@"Chẩn đoán"][section]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if(section==0)return @"Thay đổi áp dụng cho thao tác hoặc request tiếp theo. Rung chỉ áp dụng cho các nút phát được nhận diện. Làm sạch link áp dụng cho clipboard và link mở sang ứng dụng khác.";
    if(section==1)return @"Bộ đếm không đảm bảo tài khoản có quyền Premium từ server hoặc mọi loại quảng cáo đã bị chặn. Player Chroma, lyrics và lock screen động chưa được tích hợp trong bản này.";
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
        NSArray *titles=@[@"Lọc section quảng cáo trong feed",@"Chặn popup đánh giá",@"Làm sạch link chia sẻ",@"Rung ở nút phát",@"Eevee: patch bootstrap/config",@"Eevee: ghi đè cấu hình"];
        NSArray *keys=@[@"unifiedspotify.feedEnabled",@"eeveeBlockRatingPrompts",@"unifiedspotify.cleanShareLinks",@"unifiedspotify.controlHaptics",@"unifiedspotify.premiumPatching",@"overwriteConfiguration"];
        content.text=titles[indexPath.row];UISwitch *toggle=[UISwitch new];toggle.tag=indexPath.row;
        BOOL fallback=indexPath.row==0 ? YES : indexPath.row==2 ? USSettingEnabled(@"cleanShareLinks",NO) : indexPath.row==4 ? !([NSUserDefaults.standardUserDefaults integerForKey:@"patchType"]==1) : NO;
        toggle.on=USSettingEnabled(keys[indexPath.row],fallback);toggle.accessibilityLabel=titles[indexPath.row];
        toggle.enabled=[_snapshot[@"activation.allowed"] isEqual:@"yes"];
        [toggle addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;
    }else if(indexPath.section==1){NSString *key=_statusKeys[indexPath.row];content.text=key;content.secondaryText=[_snapshot[key] description];cell.selectionStyle=UITableViewCellSelectionStyleNone;
    }else{content.text=@"Xuất báo cáo trạng thái";cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
    cell.contentConfiguration=content;
    return cell;
}
- (void)changed:(UISwitch *)sender {
    NSArray *keys=@[@"unifiedspotify.feedEnabled",@"eeveeBlockRatingPrompts",@"unifiedspotify.cleanShareLinks",@"unifiedspotify.controlHaptics",@"unifiedspotify.premiumPatching",@"overwriteConfiguration"];
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

static char rowKey,insetKey;
static NSMutableDictionary<NSValue *,NSValue *> *controllerIMPs;
static IMP collectionIMP;
static const CGFloat rowHeight=68;
static UIViewController *controllerFor(UIView *view) {
    for(UIResponder *r=view;r;r=r.nextResponder)if([r isKindOfClass:UIViewController.class])return (UIViewController *)r;
    return nil;
}
@interface USSettingsEntry : UIButton
@property(nonatomic) BOOL drawer;
@end
@implementation USSettingsEntry
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){
        UIButtonConfiguration *config=[UIButtonConfiguration plainButtonConfiguration];
        config.title=@"Unified Spotify";config.subtitle=@"Cài đặt bản cá nhân";
        config.image=[UIImage systemImageNamed:@"slider.horizontal.3"];config.imagePadding=12;
        config.contentInsets=NSDirectionalEdgeInsetsMake(12,16,12,16);
        self.configuration=config;self.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeading;
        self.accessibilityLabel=@"Unified Spotify, cài đặt bản cá nhân";
        Class glass=NSClassFromString(@"UIGlassEffect");SEL selector=NSSelectorFromString(@"effectWithStyle:");
        if([glass respondsToSelector:selector]){
            UIVisualEffect *effect=((id (*)(id,SEL,NSInteger))objc_msgSend)(glass,selector,0);
            UIVisualEffectView *pane=[[UIVisualEffectView alloc] initWithEffect:effect];
            pane.frame=self.bounds;pane.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            pane.userInteractionEnabled=NO;pane.layer.cornerRadius=16;pane.clipsToBounds=YES;
            [self insertSubview:pane atIndex:0];USStateSet(@"appearance.settingsRow",@"native UIGlassEffect");
        }else USStateSet(@"appearance.settingsRow",@"native glass unavailable");
        [self addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
    }return self;
}
- (void)openSettings {
    UIViewController *owner=controllerFor(self);if(!owner)return;
    // Present from the existing settings/drawer controller. Avoid pushing a
    // foreign SPTPageController onto Spotify's proprietary navigation stack.
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:[USModSettings new]];
    [owner presentViewController:nav animated:YES completion:nil];
}
@end
static UIViewController *settingsIn(UIViewController *root,Class cls) {
    if([root isKindOfClass:cls])return root;
    for(UIViewController *child in root.childViewControllers){UIViewController *found=settingsIn(child,cls);if(found)return found;}
    return nil;
}
static BOOL settingsRoot(UIViewController *vc) {
    for(UIViewController *page in vc.navigationController.viewControllers){UIViewController *found=settingsIn(page,vc.class);if(found)return found==vc;}
    return YES;
}
static void place(UICollectionView *list,USSettingsEntry *row) {
    row.hidden=!row.drawer && list.contentSize.height<=0;
    row.frame=CGRectMake(12,row.drawer?-rowHeight:list.contentSize.height,MAX(0,list.bounds.size.width-24),rowHeight);
    UIEdgeInsets inset=list.contentInset;
    NSValue *applied=objc_getAssociatedObject(list,&insetKey);
    if(applied && UIEdgeInsetsEqualToEdgeInsets(inset,applied.UIEdgeInsetsValue))return;
    if(row.drawer)inset.top+=rowHeight;else inset.bottom+=rowHeight;
    objc_setAssociatedObject(list,&insetKey,[NSValue valueWithUIEdgeInsets:inset],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    list.contentInset=inset;
}
static void walk(UIView *view,BOOL drawer,BOOL root) {
    if([view isKindOfClass:UICollectionView.class] && (!drawer || [NSStringFromClass(view.class) containsString:@"SideDrawerListCollectionView"])){
        UICollectionView *list=(UICollectionView *)view;USSettingsEntry *row=objc_getAssociatedObject(list,&rowKey);
        if(!root){
            NSValue *applied=objc_getAssociatedObject(list,&insetKey);
            if(row && applied && UIEdgeInsetsEqualToEdgeInsets(list.contentInset,applied.UIEdgeInsetsValue)){
                UIEdgeInsets inset=list.contentInset;if(row.drawer)inset.top-=rowHeight;else inset.bottom-=rowHeight;list.contentInset=inset;
            }
            [row removeFromSuperview];objc_setAssociatedObject(list,&rowKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(list,&insetKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return;
        }
        if(!row){row=[[USSettingsEntry alloc] initWithFrame:CGRectZero];row.drawer=drawer;
            objc_setAssociatedObject(list,&rowKey,row,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[list addSubview:row];
            USStateIncrement(drawer?@"ui.sidebarRows":@"ui.settingsRows");}
        place(list,row);return;
    }
    for(UIView *child in view.subviews)walk(child,drawer,root);
}
static void controllerLayout(id self,SEL selector) {
    IMP original=NULL;
    for(Class cls=object_getClass(self);cls;cls=class_getSuperclass(cls)){
        NSValue *value=controllerIMPs[[NSValue valueWithPointer:(const void *)cls]];
        if(value){original=(IMP)value.pointerValue;break;}
    }
    if(original)((void (*)(id,SEL))original)(self,selector);
    UIViewController *vc=self;BOOL drawer=[NSStringFromClass(vc.class) containsString:@"SideDrawer"];
    walk(vc.view,drawer,drawer || settingsRoot(vc));
}
static void collectionLayout(id self,SEL selector) {
    ((void (*)(id,SEL))collectionIMP)(self,selector);
    USSettingsEntry *row=objc_getAssociatedObject(self,&rowKey);if(row)place(self,row);
}
void USShowModEntry(void) {
    NSCAssert(NSThread.isMainThread,@"UIKit integration must run on main thread");
    if(!controllerIMPs)controllerIMPs=[NSMutableDictionary dictionary];
    USHookRegistry *registry=[USHookRegistry new];SEL selector=@selector(viewDidLayoutSubviews);
    for(NSString *name in @[@"_TtC21Settings_PlatformImpl26SettingsListViewController",@"_TtC23SideDrawer_ListPageImpl18ListViewController"]){
        Class cls=NSClassFromString(name);NSString *status=[@"settingsHook." stringByAppendingString:name];
        if(!cls){USStateSet(status,@"class absent");NSLog(@"[UnifiedSpotify] Settings class absent: %@",name);continue;}
        NSValue *key=[NSValue valueWithPointer:(const void *)cls];if(controllerIMPs[key])continue;
        Method method=class_getInstanceMethod(cls,selector);Method contract=class_getInstanceMethod(UIViewController.class,selector);
        if(!method || strcmp(method_getTypeEncoding(method),method_getTypeEncoding(contract))){USStateSet(status,@"ABI rejected");continue;}
        IMP original=method_getImplementation(method);controllerIMPs[key]=[NSValue valueWithPointer:(const void *)original];
        NSError *error=nil;BOOL ok=[registry installOnClass:cls selector:selector owner:@"unified.settings"
            expectedEncoding:method_getTypeEncoding(contract) expectedOriginal:original replacement:(IMP)controllerLayout error:&error];
        if(!ok)[controllerIMPs removeObjectForKey:key];USStateSet(status,ok?@"installed":error.localizedDescription);
        NSLog(@"[UnifiedSpotify] Settings entry %@: %@",name,ok?@"installed":error.localizedDescription);
    }
    if(!collectionIMP){
        Method method=class_getInstanceMethod(UICollectionView.class,@selector(layoutSubviews));IMP original=method_getImplementation(method);
        NSError *error=nil;BOOL ok=[registry installOnClass:UICollectionView.class selector:@selector(layoutSubviews) owner:@"unified.settings.rowLayout"
            expectedEncoding:method_getTypeEncoding(method) expectedOriginal:original replacement:(IMP)collectionLayout error:&error];
        if(ok)collectionIMP=original;USStateSet(@"settingsHook.rowLayout",ok?@"installed":error.localizedDescription);
    }
}
