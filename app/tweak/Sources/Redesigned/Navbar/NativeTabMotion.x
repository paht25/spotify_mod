// Motion source: user-supplied spoti.pw-0.23.0-beta.zip, Redesigned/Navbar/TabBar.x.
// Archive SHA-256: 75cd6a8946077d2e9ac99bfe9c3ff868abdcbde6639e30babaf318827e4b847f.
// UIKit watches the actual foreground list through setContentScrollView:forEdge: and animates a
// UITabAccessory. Only its geometry is used here: its view is masked out, cannot receive touches,
// and never replaces the user's existing SGRSystemTabBar or expanded Now Playing controls.
#import "Core/SGCore.h"
#import "Navbar.h"
#import "Redesigned/NowPlayingBar/NowPlayingBar.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/Player/PlayerEvents.h"

@class SGRNativeMotion;
@interface SGRMotionProbe : UIView
@property (nonatomic, weak) SGRNativeMotion *motion;
@end

@interface SGRNativeMotion : UITabBarController <SGPlayerStateObserver>
@property (nonatomic, strong) UITabAccessory *motionAccessory API_AVAILABLE(ios(26.0));
@property (nonatomic, strong) SGRMotionProbe *probe;
@property (nonatomic, strong) CADisplayLink *clock;
@property (nonatomic, weak) UIScrollView *followedList;
@property (nonatomic) CGFloat expandedWidth, inlineWidth;
@property (nonatomic) CGFloat expandedY, inlineY;
@property (nonatomic) NSUInteger restingFrames;
@property (nonatomic) BOOL bindingList;
- (void)wake;
- (void)sample;
- (void)follow:(UIScrollView *)list;
- (void)expand;
- (void)bindFollowedList;
@end

static SGRNativeMotion *sg_motion;
static BOOL sg_syncingMotion;
static char kPanObserved;

// Copied from 0.23.0's SGRInlinePage: UIKit re-reads the named external scroll view on appearance.
@interface SGRNativePage : UIViewController
@end
@implementation SGRNativePage
- (void)loadView {
    UIView *view = [UIView new];
    view.backgroundColor = UIColor.clearColor;
    view.userInteractionEnabled = NO;
    self.view = view;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [sg_motion bindFollowedList];
}
@end

static BOOL motionEnabled(void) {
    id stored = [NSUserDefaults.standardUserDefaults objectForKey:SGRKeyNavbarMinimize];
    return !stored || [stored boolValue];
}

@implementation SGRMotionProbe
- (void)layoutSubviews {
    [super layoutSubviews];
    [self.motion wake];
}
@end

@implementation SGRNativeMotion
- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    if (@available(iOS 26.0, *)) {
        self.tabBarMinimizeBehavior = UITabBarMinimizeBehaviorOnScrollDown;
        NSMutableArray<UITab *> *tabs = [NSMutableArray array];
        for (NSUInteger i = 0; i < 2; i++) {
            [tabs addObject:[[UITab alloc] initWithTitle:i ? @"Motion" : @"Home"
                image:[UIImage systemImageNamed:@"house"] identifier:[NSString stringWithFormat:@"motion.%lu", (unsigned long)i]
                viewControllerProvider:^UIViewController *(UITab *tab) {
                    return [SGRNativePage new];
                }]];
        }
        UISearchTab *trailing = [[UISearchTab alloc] initWithViewControllerProvider:^UIViewController *(UITab *tab) {
            return [SGRNativePage new];
        }];
        trailing.automaticallyActivatesSearch = NO;
        [tabs addObject:trailing];
        self.tabs = tabs;
        self.probe = [SGRMotionProbe new];
        self.probe.motion = self;
        self.motionAccessory = [[UITabAccessory alloc] initWithContentView:self.probe];
        [self.probe registerForTraitChanges:@[UITraitTabAccessoryEnvironment.class] withTarget:self action:@selector(wake)];
    }
    SGAddPlayerStateObserver(self);
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.userInteractionEnabled = NO;
    self.view.accessibilityElementsHidden = YES;
    // A zero-area mask removes the entire driver's rendering, including its glass and shadows.
    // Keep alpha at one so UIKit's on-screen scroll observation remains active.
    self.view.layer.mask = [CALayer layer];
}
- (void)wake {
    if (!self.clock) {
        self.clock = [CADisplayLink displayLinkWithTarget:self selector:@selector(sample)];
        if (@available(iOS 15.0, *)) {
            float maximum = UIScreen.mainScreen.maximumFramesPerSecond;
            self.clock.preferredFrameRateRange = CAFrameRateRangeMake(MIN(80, maximum), maximum, maximum);
        }
        [self.clock addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    self.restingFrames = 0;
    self.clock.paused = NO;
}
- (void)sample {
    if (@available(iOS 26.0, *)) {
        if (!self.viewIfLoaded.window || !self.bottomAccessory) {
            self.clock.paused = YES;
            SGRRenderTabBarProgress(0);
            return;
        }
        BOOL inlineMode = self.probe.traitCollection.tabAccessoryEnvironment == UITabAccessoryEnvironmentInline;
        CGRect model = [self.probe convertRect:self.probe.bounds toView:self.view];
        if (!inlineMode && model.size.width > 100) {
            self.expandedWidth = model.size.width;
            self.expandedY = CGRectGetMidY(model);
        }
        if (inlineMode && model.size.width < self.expandedWidth - 8) {
            self.inlineWidth = model.size.width;
            self.inlineY = CGRectGetMidY(model);
        }
        CALayer *layer = self.probe.layer.presentationLayer ?: self.probe.layer;
        CALayer *root = self.view.layer.presentationLayer ?: self.view.layer;
        CGRect presented = [layer convertRect:layer.bounds toLayer:root];
        CGFloat width = presented.size.width;
        CGFloat distance = self.expandedWidth - self.inlineWidth;
        CGFloat progress = distance > 8 && self.inlineWidth > 0 ? (self.expandedWidth - width) / distance : 0;
        // In 0.23.0 UIKit moves the accessory as well as narrowing it. Its horizontal morph
        // finishes earlier than its vertical spring. Sampling only width rushes our entire
        // movement into that first phase; follow the actual accessory travel for continuity.
        CGFloat travel = self.inlineY - self.expandedY;
        if (self.inlineWidth > 0 && fabs(travel) > 8)
            progress = (CGRectGetMidY(presented) - self.expandedY) / travel;
        if (UIAccessibilityIsReduceMotionEnabled()) progress = inlineMode ? 1 : 0;
        progress = MAX(0, MIN(1, progress));
        if (progress < 0.002) progress = 0;
        if (progress > 0.998) progress = 1;
        BOOL settled = fabs(progress - SGRTabBarCollapseProgress()) < 0.0001 && (progress == 0 || progress == 1);
        // A steady accessory needs no visible re-layout. Keep sampling only through the morph.
        if (!settled) SGRRenderTabBarProgress(progress);
        if (settled && ++self.restingFrames > 20) self.clock.paused = YES;
        else if (!settled) self.restingFrames = 0;
    }
}
- (void)follow:(UIScrollView *)list {
    if (!list.window || list == self.followedList) return;
    self.followedList = list;
    [self bindFollowedList];
    SGLog(@"UIFIX r3: native motion follows %@", NSStringFromClass(list.class));
    [self wake];
}
- (void)bindFollowedList {
    // Port of 0.23.0 nameScrollView(), including the re-entrant appearance guard.
    UIScrollView *list = self.followedList;
    UIViewController *page = self.selectedViewController;
    if (!page || !list.window || self.bindingList) return;
    if ([page contentScrollViewForEdge:NSDirectionalRectEdgeBottom] == list) return;
    [page setContentScrollView:list forEdge:NSDirectionalRectEdgeAll];
    if (!self.viewIfLoaded.window) return;
    if (@available(iOS 26.0, *)) {
        UITab *selected = self.selectedTab, *other = nil;
        for (UITab *tab in self.tabs)
            if (tab != selected && ![tab isKindOfClass:UISearchTab.class]) { other = tab; break; }
        if (!selected || !other) return;
        self.bindingList = YES;
        [UIView performWithoutAnimation:^{ self.selectedTab = other; self.selectedTab = selected; }];
        self.bindingList = NO;
    }
}
- (void)expand {
    if (@available(iOS 26.0, *)) {
        if (self.tabBarMinimizeBehavior == UITabBarMinimizeBehaviorNever) return;
        // Changing behavior outside an animation transaction can snap the accessory to regular.
        // Animate UIKit's layout itself, so a reverse drag supplies a continuous native geometry
        // curve to the same player and tab renderer, including when interrupted halfway through.
        void (^expand)(void) = ^{
            self.tabBarMinimizeBehavior = UITabBarMinimizeBehaviorNever;
            [self.view layoutIfNeeded];
        };
        if (UIAccessibilityIsReduceMotionEnabled()) [UIView performWithoutAnimation:expand];
        else [UIView animateWithDuration:SGRNavbarMotionDuration delay:0 usingSpringWithDamping:1 initialSpringVelocity:0
            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
            animations:expand completion:nil];
    }
    [self wake];
}
- (void)playerStateDidChange:(SPTPlayerState *)state {
    if (@available(iOS 26.0, *)) {
        UITabAccessory *accessory = SGRNowPlayingAvailable() && motionEnabled() ? self.motionAccessory : nil;
        if (self.bottomAccessory != accessory) {
            [self setBottomAccessory:accessory animated:NO];
            if (!accessory) SGRRenderTabBarProgress(0);
            [self wake];
        }
    }
}
@end

BOOL SGRNativeTabMotionActive(void) {
    return sg_motion.viewIfLoaded.window && motionEnabled();
}

void SGRExpandNativeTabMotion(void) { [sg_motion expand]; }

NSDictionary *SGRNativeTabMotionState(void) {
    if (@available(iOS 26.0, *)) {
        return @{@"nativeInline": @(sg_motion.probe.traitCollection.tabAccessoryEnvironment == UITabAccessoryEnvironmentInline),
            @"expandedWidth": @(sg_motion.expandedWidth), @"inlineWidth": @(sg_motion.inlineWidth),
            @"modelWidth": @(sg_motion.probe.bounds.size.width),
            @"nativeVerticalTravel": @(sg_motion.inlineY - sg_motion.expandedY),
            @"behavior": @(sg_motion.tabBarMinimizeBehavior), @"offset": @(sg_motion.followedList.contentOffset.y)};
    }
    return @{};
}

static BOOL pageList(UIScrollView *list) {
    UIView *root = SGRTabBarPageRoot();
    if (!root.window || !list.window || list.hidden || list.pagingEnabled || !SGRTabBarContainsPageView(list)) return NO;
    if ([list isDescendantOfView:sg_motion.viewIfLoaded]) return NO;
    if (list.bounds.size.height < root.bounds.size.height * 0.5) return NO;
    // The full-screen player's list and the original Now Playing controls are not a page list.
    for (UIResponder *r = list.nextResponder; r; r = r.nextResponder) {
        NSString *name = NSStringFromClass(r.class);
        if ([name containsString:@"NowPlaying"] || [name containsString:@"NPV"]) return NO;
        if (r == root.nextResponder) break;
    }
    return YES;
}

// 0.23.0 considers lists when they enter the window, including the deferred appearance pass;
// keep the inner list when a containing scroll view arrives afterward.
static void considerPageList(UIScrollView *list) {
    if (!sg_motion || !pageList(list) || sg_motion.followedList == list) return;
    UIScrollView *current = sg_motion.followedList;
    if (current.window && [current isDescendantOfView:list]) return;
    [sg_motion follow:list];
}

void SGRSyncNativeTabMotion(void) {
    if (sg_syncingMotion) return;
    if (@available(iOS 26.0, *)) {
        UIView *root = SGRTabBarPageRoot();
        if (!root.window) return;
        sg_syncingMotion = YES;
        @try {
            if (!sg_motion) sg_motion = [SGRNativeMotion new];
            if (sg_motion.view.superview != root) {
                [sg_motion beginAppearanceTransition:YES animated:NO];
                sg_motion.view.frame = root.bounds;
                sg_motion.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [root insertSubview:sg_motion.view atIndex:0];
                [sg_motion endAppearanceTransition];
            }
            [sg_motion playerStateDidChange:SGPlayerState()];
            if (!sg_motion.followedList.window) {
                __block UIScrollView *best = nil;
                SGForEachView(root, ^(UIView *view) {
                    if ([view isKindOfClass:UIScrollView.class] && pageList((UIScrollView *)view)) best = (UIScrollView *)view;
                });
                [sg_motion follow:best];
            }
        } @finally { sg_syncingMotion = NO; }
    }
}

@interface SGRNativeScrollPan : NSObject
@end
@implementation SGRNativeScrollPan
+ (void)dragged:(UIPanGestureRecognizer *)pan {
    UIScrollView *list = (UIScrollView *)pan.view;
    if (![list isKindOfClass:UIScrollView.class] || !pageList(list)) return;
    CGPoint velocity = [pan velocityInView:list];
    if (fabs(velocity.y) > fabs(velocity.x)) {
        if (pan.state == UIGestureRecognizerStateBegan) [sg_motion follow:list];
        if (@available(iOS 26.0, *)) {
            if (velocity.y > 0 && (SGRTabBarCollapseProgress() > 0 ||
                sg_motion.probe.traitCollection.tabAccessoryEnvironment == UITabAccessoryEnvironmentInline)) [sg_motion expand];
            else if (velocity.y < 0 && (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged))
                if (sg_motion.tabBarMinimizeBehavior != UITabBarMinimizeBehaviorOnScrollDown)
                    sg_motion.tabBarMinimizeBehavior = UITabBarMinimizeBehaviorOnScrollDown;
        }
    }
    [sg_motion wake];
}
@end

%hook UIScrollView
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    if (!objc_getAssociatedObject(self, &kPanObserved)) {
        objc_setAssociatedObject(self, &kPanObserved, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self.panGestureRecognizer addTarget:SGRNativeScrollPan.class action:@selector(dragged:)];
    }
    considerPageList(self);
    __weak UIScrollView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ considerPageList(weakSelf); });
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    [NSNotificationCenter.defaultCenter addObserverForName:SGPlayerTransitionNotification object:nil
        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { [sg_motion expand]; }];
}
