#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRRepaint.h"
#import "Redesigned/Kit/SGRTokens.h"
#import "Redesigned/Kit/SGRBridges.h"
#import "Redesigned/Navbar/Navbar.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/Player/NowPlayingExtras.h"
#import "Shared/Player/PlayerEvents.h"
#import "Shared/Player/PlayerState.h"
#import "NowPlayingBar.h"
#import <objc/message.h>
#import <objc/runtime.h>

static const CGFloat kCardRadius = 24;
static char kGlassKey, kProgressViewKey, kProgressAlphaKey;
static __weak UIVisualEffectView *sg_cardGlass;
static __weak UIView *sg_cardArtwork;
static __weak UIView *sg_cardContent;
static __weak UIView *sg_progressLine;
static __weak UIView *sg_miniProgressView;
static __weak UIViewController *sg_container;
static NSTimer *sg_progressTimer;
static BOOL sg_stylingCard;
static __weak UIView *sg_barContainer;
static void styleNowPlayingBar(UIViewController *container);

BOOL SGRInlinePlayer(void) {
    static BOOL on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Default this newly imported option on; keep an explicit user's choice.
        if (![NSUserDefaults.standardUserDefaults objectForKey:SGRKeyInlinePlayer]) SGSetEnabled(SGRKeyInlinePlayer, YES);
        on = SGRedesignedUI() && SGHidden(SGRKeyInlinePlayer);
    });
    return on;
}

CGRect SGRNowPlayingCardFrameIn(UIView *host, CGFloat *radius) {
    if (SGRInlinePlayer()) return SGRMiniPlayerFrameIn(host, radius);
    UIVisualEffectView *glass = sg_cardGlass;
    if (!glass.superview || !glass.window || !host) return CGRectNull;
    if (radius) *radius = MIN(kCardRadius, glass.bounds.size.height / 2);
    return [host convertRect:glass.bounds fromView:glass];
}

CGRect SGRNowPlayingArtworkFrameIn(UIView *host) {
    if (SGRInlinePlayer()) return SGRMiniPlayerArtworkFrameIn(host);
    UIView *artwork = sg_cardArtwork;
    if (!artwork.window || !host) return CGRectNull;
    return [host convertRect:artwork.bounds fromView:artwork];
}

UIImageView *SGRNowPlayingArtworkView(void) {
    __block UIImageView *found = nil;
    void (^look)(UIView *) = ^(UIView *root) {
        if (!root) return;
        SGForEachView(root, ^(UIView *v) {
            if (found || ![v isKindOfClass:UIImageView.class]) return;
            CGSize size = v.bounds.size;
            if (size.width >= 30 && size.width <= 64 && fabs(size.width - size.height) < 1) found = (UIImageView *)v;
        });
    };
    UIView *artwork = sg_cardArtwork;
    if ([artwork isKindOfClass:UIImageView.class]) return (UIImageView *)artwork;
    look(artwork);
    if (!found) look(sgr_nowPlayingRoot);
    return found;
}

UIImage *SGRNowPlayingArtworkImage(void) {
    return SGRNowPlayingArtworkView().image;
}

// The recognizer nearest the top of the bar opens the player; deeper ones belong to its buttons and the
// device line. Breadth first from the bar's container, then up its superviews to Spotify's page.
BOOL SGROpenPlayerFromBar(void) {
    UIView *container = sg_barContainer;
    if (!container) return NO;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:container];
    while (queue.count) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        // Our invisible decorative glass is not Spotify's player-opening target.
        if (view == objc_getAssociatedObject(container, &kGlassKey)) continue;
        if (SGRFireTapRecognizers(view)) {
            SGLog(@"mini player: tap passed to %@ on Spotify's bar", NSStringFromClass(view.class));
            return YES;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    for (UIView *view = container.superview; view && ![view isKindOfClass:UIWindow.class]; view = view.superview) {
        if (SGRFireTapRecognizers(view)) {
            SGLog(@"mini player: tap passed to %@ above Spotify's bar", NSStringFromClass(view.class));
            return YES;
        }
    }
    NSMutableString *out = [NSMutableString stringWithString:@"mini player: no tap recognizer on Spotify's bar"];
    SGForEachView(container, ^(UIView *v) {
        for (UIGestureRecognizer *r in v.gestureRecognizers) [out appendFormat:@"\n  %@ on %@", r, NSStringFromClass(v.class)];
    });
    SGLogLong(@"mini player", out);
    return NO;
}

CGFloat SGRNowPlayingExpandedHeight(void) {
    CGFloat height = sg_cardGlass.bounds.size.height;
    return height >= 30 && height <= 80 ? height : 56;
}

void SGRNowPlayingBarRefresh(void) {
    if (sg_container) styleNowPlayingBar(sg_container);
    SGRRefreshMiniPlayerSize();
}

static UIView *detectColoredCard(UIView *bar) {
    __block UIView *best = nil;
    __block CGFloat bestArea = 0;
    SGForEachView(bar, ^(UIView *v) {
        if ([v isKindOfClass:UIVisualEffectView.class] || SGKeepsColor(v) || !SGLooksLikeCard(v, v.layer.backgroundColor)) return;
        CGFloat area = v.bounds.size.width * v.bounds.size.height;
        if (area > bestArea) { bestArea = area; best = v; }
    });
    return best;
}

// Fallback when nothing is painted: the box around artwork, text and the small buttons.
static CGRect contentBounds(UIView *bar, UIView *target) {
    __block CGRect box = CGRectNull;
    SGForEachView(bar, ^(UIView *v) {
        if (v.hidden || v.alpha == 0) return;
        CGFloat width = v.bounds.size.width;
        BOOL content = ([v isKindOfClass:UIImageView.class] && width >= 20 && width <= 120)
            || [v isKindOfClass:UILabel.class]
            || ([v isKindOfClass:UIControl.class] && width <= 100);
        if (content) box = CGRectUnion(box, SGFrameIn(v, target));
    });
    return CGRectIsNull(box) ? box : CGRectInset(box, -10, -8);
}

static void roundView(UIView *view, CGFloat radius) {
    view.layer.cornerRadius = radius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
}

static CGFloat progressThickness(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    return [defaults objectForKey:SGRKeyNowPlayingProgressThickness]
        ? MIN(5, MAX(0, [defaults doubleForKey:SGRKeyNowPlayingProgressThickness])) : 2;
}

@interface SGRMiniProgressView : UIView
- (void)setProgress:(CGFloat)progress thickness:(CGFloat)thickness;
@end

@implementation SGRMiniProgressView {
    UIView *_track;
    UIView *_fill;
    CGFloat _progress;
    CGFloat _thickness;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.isAccessibilityElement = NO;
    self.clipsToBounds = YES;
    _track = [UIView new];
    _track.backgroundColor = [UIColor colorWithWhite:1 alpha:0.24];
    _fill = [UIView new];
    _fill.backgroundColor = UIColor.whiteColor;
    [self addSubview:_track];
    [self addSubview:_fill];
    return self;
}

- (void)setProgress:(CGFloat)progress thickness:(CGFloat)thickness {
    _progress = MIN(1, MAX(0, progress));
    _thickness = MIN(5, MAX(0, thickness));
    self.hidden = _thickness <= 0;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat horizontalInset = 8;
    CGFloat width = MAX(0, self.bounds.size.width - horizontalInset * 2);
    CGFloat fillY = self.bounds.size.height - 3 - _thickness / 2;
    _track.frame = CGRectMake(horizontalInset, fillY, width, _thickness);
    _fill.frame = CGRectMake(horizontalInset, fillY, width * _progress, _thickness);
    _track.layer.cornerRadius = _thickness / 2;
    _fill.layer.cornerRadius = _thickness / 2;
}
@end

static BOOL isProgressLine(UIView *view, UIView *card) {
    if (view == card || !view.superview) return NO;
    CGSize size = view.bounds.size;
    if (size.height <= 0 || size.height > 10 || size.width < MAX(200, card.bounds.size.width * 0.7)) return NO;
    CGRect frame = [view convertRect:view.bounds toView:card];
    return CGRectGetMaxY(frame) >= card.bounds.size.height - 14;
}

static void updateMiniProgress(void) {
    UIView *line = sg_progressLine;
    UIView *custom = sg_miniProgressView;
    if (!custom) return;
    BOOL transitioning = !SGIsInside(custom, sgr_nowPlayingRoot) || SGPlayerTransitionEnds() > 0;
    if (line) {
        NSNumber *originalAlpha = objc_getAssociatedObject(line, &kProgressAlphaKey);
        BOOL hideOriginal = !transitioning && SGIsInside(line, sgr_nowPlayingRoot);
        if (originalAlpha) line.alpha = hideOriginal ? 0 : originalAlpha.doubleValue;
    }
    custom.hidden = transitioning || progressThickness() <= 0;
    if (transitioning) return;

    SPTPlayerState *state = SGPlayerState();
    double position = state.isPaused ? state.positionAsOfTimestamp : state.position;
    CGFloat progress = state.duration > 0 ? (CGFloat)(position / state.duration) : 0;
    [(SGRMiniProgressView *)custom setProgress:progress thickness:progressThickness()];
}

static void ensureMiniProgress(UIView *card) {
    __block UIView *line = nil;
    SGForEachView(card, ^(UIView *view) {
        if (!line && isProgressLine(view, card)) line = view;
    });

    if (sg_progressLine && sg_progressLine != line) {
        NSNumber *oldAlpha = objc_getAssociatedObject(sg_progressLine, &kProgressAlphaKey);
        if (oldAlpha) sg_progressLine.alpha = oldAlpha.doubleValue;
    }
    sg_progressLine = line;
    if (line && !objc_getAssociatedObject(line, &kProgressAlphaKey)) {
        objc_setAssociatedObject(line, &kProgressAlphaKey, @(line.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    SGRMiniProgressView *progress = objc_getAssociatedObject(card, &kProgressViewKey);
    if (!progress) {
        progress = [[SGRMiniProgressView alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(card, &kProgressViewKey, progress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (progress.superview != card) [card addSubview:progress];
    [card bringSubviewToFront:progress];
    progress.frame = card.bounds;
    progress.layer.cornerRadius = MIN(kCardRadius, card.bounds.size.height / 2);
    sg_miniProgressView = progress;
    updateMiniProgress();
    if (!sg_progressTimer) {
        sg_progressTimer = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
            updateMiniProgress();
        }];
        [NSRunLoop.mainRunLoop addTimer:sg_progressTimer forMode:NSRunLoopCommonModes];
    }
}

static void restyleCardContent(UIView *card) {
    if (!card || !SGIsInside(card, sgr_nowPlayingRoot)) return;
    sg_cardContent = card;
    SGForEachView(card, ^(UIView *v) {
        CGSize size = v.bounds.size;
        BOOL square = size.width >= 36 && size.width <= 48 && fabs(size.width - size.height) < 1;
        if (!square || v.layer.cornerRadius <= 0) return;
        CGFloat radius = SGFlag(SGRKeyNowPlayingRoundedArtwork, NO) ? MIN(9, size.width * 0.22) : size.width / 2;
        UIView *outer = v;
        for (UIView *u = v; u && u != card && CGSizeEqualToSize(u.bounds.size, size); u = u.superview) {
            roundView(u, radius);
            u.clipsToBounds = YES;
            outer = u;
        }
        sg_cardArtwork = outer;
    });
    if (!SGRInlinePlayer()) ensureMiniProgress(card);
}


// Change the constraints Spotify owns rather than assigning a frame that its next pass overwrites.
static void alignContentHost(UIView *bar, UIView *container, CGRect current, CGRect target) {
    CGRect before = [container convertRect:current toView:bar.superview];
    CGRect after = [container convertRect:target toView:bar.superview];
    CGFloat leading = CGRectGetMinX(after) - CGRectGetMinX(before);
    CGFloat trailing = CGRectGetMaxX(after) - CGRectGetMaxX(before);
    if (fabs(leading) < 0.25 && fabs(trailing) < 0.25) return;
    BOOL constrained = NO;
    for (UIView *owner = bar; owner; owner = owner.superview) {
        for (NSLayoutConstraint *constraint in owner.constraints) {
            if (!constraint.active || constraint.relation != NSLayoutRelationEqual) continue;
            BOOL first = constraint.firstItem == bar, second = constraint.secondItem == bar;
            if (!first && !second) continue;
            NSLayoutAttribute attribute = first ? constraint.firstAttribute : constraint.secondAttribute;
            CGFloat delta;
            switch (attribute) {
                case NSLayoutAttributeLeading: case NSLayoutAttributeLeft: delta = leading; break;
                case NSLayoutAttributeTrailing: case NSLayoutAttributeRight: delta = trailing; break;
                case NSLayoutAttributeCenterX: delta = (leading + trailing) / 2; break;
                case NSLayoutAttributeWidth: delta = trailing - leading; break;
                default: continue;
            }
            // An internal content constraint must not resize the host in both directions.
            id other = first ? constraint.secondItem : constraint.firstItem;
            if ([other isKindOfClass:UIView.class] && [(UIView *)other isDescendantOfView:bar]) continue;
            if ([other isKindOfClass:UILayoutGuide.class] && [[(UILayoutGuide *)other owningView] isDescendantOfView:bar]) continue;
            constraint.constant += first ? delta : -constraint.multiplier * delta;
            constrained = YES;
        }
        if (owner == container) break;
    }
    if (constrained) [bar.superview layoutIfNeeded];
    else {
        CGRect frame = bar.frame;
        frame.origin.x += leading;
        frame.size.width += trailing - leading;
        bar.frame = frame;
        [bar setNeedsLayout];
        [bar layoutIfNeeded];
    }
}

static void layoutNowPlayingBar(UIViewController *container) {
    UIViewController *barVC = container.childViewControllers.firstObject;
    UIView *bar = barVC.viewIfLoaded ?: container.view;
    sgr_nowPlayingRoot = bar;
    sg_container = container;
    sg_barContainer = container.view;
    // The mini player in the tab bar takes the bar's place: Spotify's bar stays, laid out and loading its
    // artwork for the mini player, but nobody sees or touches it.
    // The bar's page (NowPlaying_BarPageImpl's TouchPassthroughView) stands over the tab bar container
    // where the expanded mini player is, and took its touches (harness/tabbar), so it takes none either;
    // the bar is all it holds.
    if (SGRInlinePlayer()) {
        if (container.view.alpha != 0) container.view.alpha = 0;
        if (container.view.userInteractionEnabled) container.view.userInteractionEnabled = NO;
        for (UIView *v = container.view.superview; v && ![v isKindOfClass:UIWindow.class]; v = v.superview) {
            if (![NSStringFromClass(v.class) containsString:@"TouchPassthroughView"]) continue;
            if (v.userInteractionEnabled) v.userInteractionEnabled = NO;
            break;
        }
    }



    UIView *card = sgr_nowPlayingCard;
    if (!card || !SGIsInside(card, bar)) card = sgr_nowPlayingCard = detectColoredCard(bar);

    // UIKit's visible platter is inset further than Spotify's original 8 pt player inset.
    // Resize the player's content host so its original constraints lay out the artwork, text,
    // buttons and hit targets inside the matching width. Do not scale or resize the tab bar.
    CGRect navbar = SGRTabBarFrameIn(container.view);
    if (!CGRectIsNull(navbar) && navbar.size.width >= 100 && bar != container.view && bar.superview) {
        CGRect current = card ? SGFrameIn(card, container.view) : SGFrameIn(bar, container.view);
        CGRect target = current;
        target.origin.x = navbar.origin.x;
        target.size.width = navbar.size.width;
        alignContentHost(bar, container.view, current, target);
    }

    container.view.layer.backgroundColor = NULL;
    SGStripBackgrounds(bar);

    CGRect frame = card ? SGFrameIn(card, container.view) : contentBounds(bar, container.view);
    if (CGRectIsNull(frame)) return;
    frame.size.height = MIN(frame.size.height, 80);
    if (frame.size.height < 30 || frame.size.width < 100) return;
    if (!CGRectIsNull(navbar)) {
        frame.origin.x = navbar.origin.x;
        frame.size.width = navbar.size.width;
    }

    CGFloat radius = MIN(kCardRadius, frame.size.height / 2);
    if (card) {
        roundView(card, radius);
    }
    restyleCardContent(card ?: bar);

    UIVisualEffectView *glass = SGGlassFor(container.view, &kGlassKey);
    if (glass.overrideUserInterfaceStyle != UIUserInterfaceStyleDark) glass.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    sg_cardGlass = glass;
    glass.frame = frame;
    SGShapeGlass(glass, radius, NO);
    SGRRefreshMiniPlayerSize();

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"now playing card %@ at %@ (bar %@, container %@)", card.class, NSStringFromCGRect(frame),
              NSStringFromCGRect(bar.frame), NSStringFromCGRect(container.view.bounds));
    });
}

static void styleNowPlayingBar(UIViewController *container) {
    if (sg_stylingCard) return;
    sg_stylingCard = YES;
    @try {
        layoutNowPlayingBar(container);
    } @finally {
        sg_stylingCard = NO;
    }
}

%hook _TtC18NowPlaying_BarImpl36NowPlayingBarContainerViewController
- (void)viewDidLayoutSubviews {
    %orig;
    styleNowPlayingBar((UIViewController *)self);
}
%end

%hook _TtC18NowPlaying_BarImpl27NowPlayingBarViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *parent = ((UIViewController *)self).parentViewController;
    if ([NSStringFromClass(parent.class) containsString:@"NowPlayingBarContainer"]) styleNowPlayingBar(parent);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[
        @"_TtC18NowPlaying_BarImpl36NowPlayingBarContainerViewController",
        @"_TtC18NowPlaying_BarImpl27NowPlayingBarViewController",
    ]);
}
