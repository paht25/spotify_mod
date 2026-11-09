#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface TapProbe : NSObject
@end
@implementation TapProbe
+ (void)called:(id)sender { printf("TAP CLASS FIRED\n"); }
- (void)called:(id)sender { printf("TAP INSTANCE FIRED\n"); }
@end
static void inspectTap(UIView *view, id target) {
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:target action:@selector(called:)];
    [view addGestureRecognizer:recognizer];
    printf("TAP enabled %d targetkind %s\n", recognizer.enabled, class_getName(object_getClass(target)));
    Ivar targetsIvar = class_getInstanceVariable(UIGestureRecognizer.class, "_targets");
    printf("TAP targetsivar %p\n", targetsIvar);
    if (!targetsIvar) return;
    for (id pair in object_getIvar(recognizer, targetsIvar)) {
        printf("TAP PAIR %s\n", class_getName([pair class]));
        unsigned int count; Ivar *ivars=class_copyIvarList([pair class], &count);
        for(unsigned int i=0;i<count;i++) printf("TAP IVAR %s %s\n", ivar_getName(ivars[i]), ivar_getTypeEncoding(ivars[i]));
        free(ivars);
        Ivar ti=class_getInstanceVariable([pair class],"_target"), ai=class_getInstanceVariable([pair class],"_action");
        if (!ti || !ai) continue;
        id t=object_getIvar(pair,ti);
        SEL a=*(SEL *)((char *)(__bridge void *)pair+ivar_getOffset(ai));
        printf("TAP REPLAY %p %s valid %d\n", t, a ? sel_getName(a) : "nil", [t respondsToSelector:a]);
        if (t && a && [t respondsToSelector:a]) ((void (*)(id,SEL,id))objc_msgSend)(t,a,recognizer);
    }
}
static BOOL settingFrame;
static BOOL centerAdjusted;
@interface ProbePlayer : UIView @end
@implementation ProbePlayer
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, 56); }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, 56); }
@end

@interface ProbeTabs : UITabBarController
@property BOOL customChildSize;
@end
@implementation ProbeTabs
- (CGSize)sizeForChildContentContainer:(id<UIContentContainer>)child withParentContainerSize:(CGSize)parentSize {
    CGSize size = [super sizeForChildContentContainer:child withParentContainerSize:parentSize];
    if (self.customChildSize && [NSStringFromClass([(id)child class]) containsString:@"Accessory"]) {
        printf("CHILD SIZING %s %.2f %.2f\n", class_getName([(id)child class]), size.width, size.height);
        size.height = 56;
    }
    return size;
}
@end

static id styleFor(UITabBarController *tabs) {
    SEL getter = NSSelectorFromString(@"bottomAccessoryInsets");
    for (Class cls = tabs.class; cls; cls = class_getSuperclass(cls)) {
        unsigned int count;
        Ivar *list = class_copyIvarList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            const char *type = ivar_getTypeEncoding(list[i]);
            NSString *name = @(ivar_getName(list[i]));
            if (!type || type[0] != '@' || ![name.lowercaseString containsString:@"style"]) continue;
            id value = object_getIvar(tabs, list[i]);
            printf("STYLE FIELD %s %s\n", name.UTF8String, value ? class_getName([value class]) : "nil");
            if ([value respondsToSelector:getter]) { free(list); return value; }
        }
        free(list);
    }
    return nil;
}
static void dump(NSString *stage, UITabBarController *tabs, UIView *mini) {
    [tabs.view setNeedsLayout]; [tabs.view layoutIfNeeded];
    CGRect f = [mini convertRect:mini.bounds toView:tabs.view];
    printf("STAGE %s MINI %.2f %.2f %.2f %.2f\n", stage.UTF8String, f.origin.x, f.origin.y, f.size.width, f.size.height);
    for (UIView *v = mini; v; v = v.superview) {
        printf("ANCESTOR %s SUPER %s FRAME %s CONSTRAINTS %s\n", class_getName(v.class), class_getName(class_getSuperclass(v.class)),
            NSStringFromCGRect(v.frame).UTF8String, v.constraints.description.UTF8String);
        if (v == tabs.view) break;
    }
    for (UIViewController *child in tabs.childViewControllers)
        printf("CHILD %s SUPER %s PREF %s\n", class_getName(child.class), class_getName(class_getSuperclass(child.class)), NSStringFromCGSize(child.preferredContentSize).UTF8String);
    id style = styleFor(tabs);
    if (style) {
        UIEdgeInsets insets = ((UIEdgeInsets (*)(id, SEL))objc_msgSend)(style, NSSelectorFromString(@"bottomAccessoryInsets"));
        printf("STYLE INSETS %s %s\n", class_getName([style class]), NSStringFromUIEdgeInsets(insets).UTF8String);
    }
    fflush(stdout);
}

static void tree(UIView *view, NSUInteger level) {
    printf("TREE %lu %s %s\n", (unsigned long)level, class_getName(view.class), NSStringFromCGRect(view.frame).UTF8String);
    if (level < 9) for (UIView *child in view.subviews) tree(child, level+1);
}

@interface ProbeApp : UIResponder <UIApplicationDelegate> @end
@implementation ProbeApp @end
@interface ProbeScene : UIResponder <UIWindowSceneDelegate>
@property UIWindow *window;
@end
@implementation ProbeScene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    ProbeTabs *tabs = [ProbeTabs new];
    tabs.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    NSMutableArray *list = [NSMutableArray new];
    for (NSUInteger i = 0; i < 3; i++) {
        [list addObject:[[UITab alloc] initWithTitle:@[@"Home",@"Search",@"Library"][i] image:[UIImage systemImageNamed:@"house"]
            identifier:[NSString stringWithFormat:@"tab.%lu", (unsigned long)i] viewControllerProvider:^UIViewController *(UITab *tab) { return [UIViewController new]; }]];
    }
    UISearchTab *last = [[UISearchTab alloc] initWithViewControllerProvider:^UIViewController *(UITab *tab) { return [UIViewController new]; }];
    last.automaticallyActivatesSearch = NO; [list addObject:last]; tabs.tabs = list;
    ProbePlayer *mini = [ProbePlayer new];
    mini.backgroundColor = UIColor.systemPinkColor;
    tabs.bottomAccessory = [[UITabAccessory alloc] initWithContentView:mini];
    self.window.rootViewController = tabs; [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        dump(@"BASE", tabs, mini);
        tree(tabs.view,0);
        UIView *container = mini.superview;
        SEL frameSelector = @selector(setFrame:);
        Class cls = container.class;
        Method method = class_getInstanceMethod(cls, frameSelector);
        IMP original = method_getImplementation(method);
        IMP replacement = imp_implementationWithBlock(^(UIView *receiver, CGRect value) {
            if (receiver == container && fabs(value.size.height - 48) < .1) { value.origin.y -= 8; value.size.height += 8; }
            settingFrame=YES;
            ((void (*)(id, SEL, CGRect))original)(receiver, frameSelector, value);
            settingFrame=NO;
        });
        if (!class_addMethod(cls, frameSelector, replacement, method_getTypeEncoding(method)))
            class_replaceMethod(cls, frameSelector, replacement, method_getTypeEncoding(method));
        SEL boundsSelector = @selector(setBounds:);
        Method boundsMethod = class_getInstanceMethod(cls, boundsSelector);
        IMP boundsOriginal = method_getImplementation(boundsMethod);
        IMP boundsReplacement = imp_implementationWithBlock(^(UIView *receiver, CGRect value) {
            if (receiver == container && fabs(value.size.height - 48) < .1) value.size.height = 56;
            ((void (*)(id, SEL, CGRect))boundsOriginal)(receiver, boundsSelector, value);
        });
        if (!class_addMethod(cls, boundsSelector, boundsReplacement, method_getTypeEncoding(boundsMethod)))
            class_replaceMethod(cls, boundsSelector, boundsReplacement, method_getTypeEncoding(boundsMethod));
        SEL cs=@selector(setCenter:); Method cm=class_getInstanceMethod(cls,cs); IMP co=method_getImplementation(cm);
        IMP cr=imp_implementationWithBlock(^(UIView *receiver, CGPoint value) {
            if(receiver==container && !settingFrame) {
                if(!centerAdjusted || !CGPointEqualToPoint(value,receiver.center)) value.y-=4;
                centerAdjusted=YES;
            }
            ((void (*)(id,SEL,CGPoint))co)(receiver,cs,value);
        });
        if(!class_addMethod(cls,cs,cr,method_getTypeEncoding(cm))) class_replaceMethod(cls,cs,cr,method_getTypeEncoding(cm));
        UIView *targetView=[UIView new]; [tabs.view addSubview:targetView];
        targetView.alpha=0; targetView.userInteractionEnabled=NO;
        inspectTap(targetView,TapProbe.class);
        TapProbe *tapObject=[TapProbe new]; inspectTap(targetView,tapObject);
        CGRect before = container.frame;
        container.frame = before;
        printf("AFTER ASSIGN %s BOUNDS %s\n", NSStringFromCGRect(container.frame).UTF8String, NSStringFromCGRect(container.bounds).UTF8String);
        container.bounds = CGRectMake(0,0,360,56);
        printf("AFTER BOUNDS %s\n", NSStringFromCGRect(container.frame).UTF8String);
        mini.frame = container.bounds;
        [container setNeedsLayout];
        [tabs.tabBar setNeedsLayout];
        [container.superview setNeedsLayout];
        dump(@"NATIVE CONTAINER SIZE", tabs, mini);
        tree(tabs.view,0);
        printf("LAYERS %s\n", container.layer.sublayers.description.UTF8String);
        for (CALayer *layer in container.layer.sublayers) printf("LAYER %s %s CHILDREN %s\n", class_getName(layer.class), NSStringFromCGRect(layer.frame).UTF8String, layer.sublayers.description.UTF8String);
        unsigned int mc; Method *ml = class_copyMethodList(cls, &mc);
        for (unsigned int i=0;i<mc;i++) printf("METHOD %s %s\n", sel_getName(method_getName(ml[i])), method_getTypeEncoding(ml[i]));
        free(ml);
        tabs.customChildSize = YES;
        for (UIViewController *child in tabs.childViewControllers)
            if ([NSStringFromClass(child.class) containsString:@"Accessory"]) child.preferredContentSize = CGSizeMake(tabs.view.bounds.size.width, 56);
        dump(@"CHILD PREFERENCE", tabs, mini);
        for (UIView *v = mini.superview; v && v != tabs.view; v = v.superview) {
            SEL get = NSSelectorFromString(@"preferredSize"), set = NSSelectorFromString(@"setPreferredSize:");
            if ([v respondsToSelector:get] && [v respondsToSelector:set]) {
                CGSize size = ((CGSize (*)(id, SEL))objc_msgSend)(v, get);
                printf("PREFERRED OWNER %s %s\n", class_getName(v.class), NSStringFromCGSize(size).UTF8String);
                size.height = 56; ((void (*)(id, SEL, CGSize))objc_msgSend)(v, set, size);
            }
        }
        dump(@"PREFERRED OWNER", tabs, mini);
        id style = styleFor(tabs);
        if (style) {
            SEL selector = NSSelectorFromString(@"bottomAccessoryInsets");
            Method method = class_getInstanceMethod([style class], selector);
            IMP original = method_getImplementation(method);
            IMP replacement = imp_implementationWithBlock(^UIEdgeInsets(id receiver) {
                UIEdgeInsets insets = ((UIEdgeInsets (*)(id, SEL))original)(receiver, selector);
                if (receiver == style) insets.top -= 8;
                return insets;
            });
            if (!class_addMethod([style class], selector, replacement, method_getTypeEncoding(method)))
                class_replaceMethod([style class], selector, replacement, method_getTypeEncoding(method));
            SEL update = NSSelectorFromString(@"updateBottomAccessoryAnimated:");
            if ([style respondsToSelector:update]) ((void (*)(id, SEL, BOOL))objc_msgSend)(style, update, NO);
        }
        dump(@"INSET", tabs, mini);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            dump(@"SETTLED", tabs, mini); fflush(stdout); exit(0);
        });
    });
}
@end

int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(ProbeApp.class)); }
}
