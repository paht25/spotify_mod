// Motion source: spoti.pw v0.23.0-beta, TabBar.x (49e02e204f397b1e4197876dd622d4ee1663188e).
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
@property (nonatomic) NSUInteger restingFrames;
- (void)wake;
- (void)sample;
- (void)follow:(UIScrollView *)list;
- (void)expand;
@end

static SGRNativeMotion *sg_motion;
static BOOL sg_syncingMotion;
static char kPanObserved;

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
                    UIViewController *page = [UIViewController new];
                    page.view.backgroundColor = UIColor.clearColor;
                    return page;
                }]];
        }
        UISearchTab *trailing = [[UISearchTab alloc] initWithViewControllerProvider:^UIViewController *(UITab *tab) {
            return [UIViewController new];
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
        if (!inlineMode && model.size.width > 100) self.expandedWidth = model.size.width;
        if (inlineMode && model.size.width < self.expandedWidth - 8) self.inlineWidth = model.size.width;
        CALayer *layer = self.probe.layer.presentationLayer ?: self.probe.layer;
        CALayer *root = self.view.layer.presentationLayer ?: self.view.layer;
        CGFloat width = [layer convertRect:layer.bounds toLayer:root].size.width;
        CGFloat distance = self.expandedWidth - self.inlineWidth;
        CGFloat progress = distance > 8 && self.inlineWidth > 0 ? (self.expandedWidth - width) / distance : 0;
        if (UIAccessibilityIsReduceMotionEnabled()) progress = inlineMode ? 1 : 0;
        progress = MAX(0, MIN(1, progress));
        if (progress < 0.002) progress = 0;
        if (progress > 0.998) progress = 1;
        BOOL settled = fabs(progress - SGRTabBarCollapseProgress()) < 0.0001 && (progress == 0 || progress == 1);
        SGRRenderTabBarProgress(progress);
        if (settled && ++self.restingFrames > 20) self.clock.paused = YES;
        else if (!settled) self.restingFrames = 0;
    }
}
- (void)follow:(UIScrollView *)list {
    if (!list.window || list == self.followedList) return;
    self.followedList = list;
    UIViewController *page = self.selectedViewController;
    [page setContentScrollView:list forEdge:NSDirectionalRectEdgeAll];
    // As in 0.23.0, UIKit re-reads a replacement list when the page is selected.
    [UIView performWithoutAnimation:^{
        self.selectedIndex = 1;
        self.selectedIndex = 0;
    }];
    SGLog(@"UIFIX r2: native motion follows %@", NSStringFromClass(list.class));
    [self wake];
}
- (void)expand {
    if (@available(iOS 26.0, *)) {
        // A controller used solely as a motion source can keep its selected page minimized
        // across selection changes. Never requests UIKit's actual expanded accessory geometry.
        if (self.tabBarMinimizeBehavior != UITabBarMinimizeBehaviorNever)
            self.tabBarMinimizeBehavior = UITabBarMinimizeBehaviorNever;
    }
    [self wake];
}
- (void)playerStateDidChange:(SPTPlayerState *)state {
    if (@available(iOS 26.0, *)) {
        UITabAccessory *accessory = SGRNowPlayingAvailable() && motionEnabled() ? self.motionAccessory : nil;
        if (self.bottomAccessory != accessory) [self setBottomAccessory:accessory animated:NO];
        if (!accessory) SGRRenderTabBarProgress(0);
        [self wake];
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
    if (!self.window || objc_getAssociatedObject(self, &kPanObserved)) return;
    objc_setAssociatedObject(self, &kPanObserved, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self.panGestureRecognizer addTarget:SGRNativeScrollPan.class action:@selector(dragged:)];
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    [NSNotificationCenter.defaultCenter addObserverForName:SGPlayerTransitionNotification object:nil
        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { [sg_motion expand]; }];
}
