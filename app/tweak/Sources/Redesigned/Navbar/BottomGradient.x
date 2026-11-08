// The host's explicit CAGradientLayer is not the only fade: iOS 26 draws a bottom scroll-edge
// effect behind floating bars too. Suppress it on the tab's pages while the switch is off.
// Keep the top effect, the system tab bar's material and all player/other-sheet effects intact.
#import "Core/SGCore.h"
#import "Navbar.h"

static NSHashTable<UIScrollView *> *sg_lists;
static char kBottomHiddenKey;

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
