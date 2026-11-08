// AdaptiveFaceContainer is shared by Home and Library (HomeHeader.x, LibraryHeader.x).
// Keep Spotify's requested alpha and interaction state while the preference suppresses the view;
// restoring the photo must also preserve Home's existing scroll fade. Never hide an arranged view.
#import "Core/SGCore.h"
#import "Navbar.h"

static char kAlphaKey, kInteractionKey, kAccessibilityKey;
static NSHashTable<UIView *> *sg_faces;

void SGRNavbarSetProfilePhotoVisible(UIView *face) {
    if (!face) return;
    if (!sg_faces) sg_faces = [NSHashTable weakObjectsHashTable];
    [sg_faces addObject:face];
    NSNumber *alpha = objc_getAssociatedObject(face, &kAlphaKey);
    NSNumber *interaction = objc_getAssociatedObject(face, &kInteractionKey);
    NSNumber *accessibility = objc_getAssociatedObject(face, &kAccessibilityKey);
    face.alpha = alpha ? alpha.doubleValue : face.alpha;
    face.userInteractionEnabled = interaction ? interaction.boolValue : face.userInteractionEnabled;
    face.accessibilityElementsHidden = accessibility ? accessibility.boolValue : face.accessibilityElementsHidden;
}

void SGRRefreshProfilePhotos(void) {
    for (UIView *face in sg_faces.allObjects) SGRNavbarSetProfilePhotoVisible(face);
}

%hook _TtC29ListeningActivity_ElementsKit21AdaptiveFaceContainer
- (void)setAlpha:(CGFloat)alpha {
    objc_setAssociatedObject(self, &kAlphaKey, @(alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig(SGFlag(SGRKeyNavbarProfilePhoto, YES) ? alpha : 0);
}
- (void)setUserInteractionEnabled:(BOOL)enabled {
    objc_setAssociatedObject(self, &kInteractionKey, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig(enabled && SGFlag(SGRKeyNavbarProfilePhoto, YES));
}
- (void)setAccessibilityElementsHidden:(BOOL)hidden {
    objc_setAssociatedObject(self, &kAccessibilityKey, @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig(hidden || !SGFlag(SGRKeyNavbarProfilePhoto, YES));
}
- (void)layoutSubviews {
    %orig;
    SGRNavbarSetProfilePhotoVisible((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    SGRNavbarSetProfilePhotoVisible((UIView *)self);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[@"_TtC29ListeningActivity_ElementsKit21AdaptiveFaceContainer"]);
}
