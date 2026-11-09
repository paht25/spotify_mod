// The host's explicit CAGradientLayer is not the only fade: iOS 26 draws a bottom scroll-edge
// effect behind floating bars too. Suppress it on the tab's pages while the switch is off.
// Keep the top effect, the system tab bar's material and all player/other-sheet effects intact.
#import "Core/SGCore.h"
#import "Navbar.h"

static NSHashTable<UIScrollView *> *sg_lists;
static char kBottomHiddenKey;
static char kFadeAlphaKey, kBackgroundAlphaKey;
static NSHashTable<UIView *> *sg_stockFades;

void SGRRefreshStockTabBarFade(void) {
    BOOL visible = SGFlag(SGRKeyNavbarBottomGradient, YES);
    for (UIView *fade in sg_stockFades.allObjects) {
        NSNumber *alpha = objc_getAssociatedObject(fade, &kFadeAlphaKey);
        fade.alpha = alpha ? alpha.doubleValue : 1;
    }
    UIView *background = SGRStockTabBarBackground();
    if (!background) return;
    // Sometimes the background container IS TabBarGradientView. Applying both mechanisms to
    // that same view records our forced zero as Spotify's requested alpha and cannot restore it.
    if ([sg_stockFades containsObject:background]) return;
    NSNumber *original = objc_getAssociatedObject(background, &kBackgroundAlphaKey);
    if (!visible && !original) {
        original = @(background.alpha);
        objc_setAssociatedObject(background, &kBackgroundAlphaKey, original, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!visible) background.alpha = 0;
    else if (original) {
        background.alpha = original.doubleValue;
        objc_setAssociatedObject(background, &kBackgroundAlphaKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// Verified in both supplied Spotify binaries, including 9.1.90. This is Spotify's own fade,
// outside the layer that SGRTabBarHost draws. Do not hide the glass tab bar or its platters.
%hook _TtC23NavigationUI_TabBarImpl18TabBarGradientView
- (void)setAlpha:(CGFloat)alpha {
    objc_setAssociatedObject(self, &kFadeAlphaKey, @(alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig(SGFlag(SGRKeyNavbarBottomGradient, YES) ? alpha : 0);
}
- (void)didMoveToWindow {
    %orig;
    if (!sg_stockFades) sg_stockFades = [NSHashTable weakObjectsHashTable];
    [sg_stockFades addObject:(UIView *)self];
    SGRRefreshStockTabBarFade();
}
- (void)layoutSubviews {
    %orig;
    SGRRefreshStockTabBarFade();
}
%end

static void updateBottomEdge(UIScrollView *list) {
    if (@available(iOS 26.0, *)) {
        NSNumber *original = objc_getAssociatedObject(list, &kBottomHiddenKey);
        BOOL pageList = SGRTabBarContainsPageView(list) && list.bounds.size.height >= 150;
        for (UIView *parent = list.superview; pageList && parent; parent = parent.superview) {
            if ([parent isKindOfClass:UIScrollView.class]) pageList = NO;
        }
        BOOL suppress = !SGFlag(SGRKeyNavbarBottomGradient, YES) && pageList;
        if (suppress) {
            if (!original) objc_setAssociatedObject(list, &kBottomHiddenKey, @(list.bottomEdgeEffect.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (!list.bottomEdgeEffect.hidden) list.bottomEdgeEffect.hidden = YES;
        } else if (original) {
            objc_setAssociatedObject(list, &kBottomHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            list.bottomEdgeEffect.hidden = original.boolValue;
        }
    }
}

void SGRRefreshBottomEdgeEffects(void) {
    for (UIScrollView *list in sg_lists.allObjects) updateBottomEdge(list);
}

%hook UIScrollView
- (void)didMoveToWindow {
    %orig;
    if (!sg_lists) sg_lists = [NSHashTable weakObjectsHashTable];
    [sg_lists addObject:self];
    updateBottomEdge(self);
}
- (void)layoutSubviews {
    %orig;
    updateBottomEdge(self);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
}
