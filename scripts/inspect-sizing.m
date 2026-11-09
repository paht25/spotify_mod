#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL relevant(NSString *text) {
    NSString *s = text.lowercaseString;
    return [s containsString:@"accessor"] || [s containsString:@"height"] ||
        [s containsString:@"size"] || [s containsString:@"metric"];
}
int main(void) {
    @autoreleasepool {
        printf("UIKit accessory: %s\n", class_getName(UITabAccessory.class));
        int count = objc_getClassList(NULL, 0);
        int capacity = count;
        Class __unsafe_unretained *classes = (Class __unsafe_unretained *)calloc(capacity, sizeof(Class));
        count = MIN(objc_getClassList(classes, capacity), capacity);
        for (int i = 0; i < count; i++) {
            NSString *name = NSStringFromClass(classes[i]);
            NSString *lower = name.lowercaseString;
            if (![lower containsString:@"tab"] ||
                !([lower containsString:@"accessor"] || [lower containsString:@"tabbar"])) continue;
            printf("CLASS %s\n", name.UTF8String);
            for (int meta = 0; meta < 2; meta++) {
                unsigned int n;
                Method *methods = class_copyMethodList(meta ? object_getClass(classes[i]) : classes[i], &n);
                for (unsigned int j = 0; j < n; j++) {
                    SEL selector = method_getName(methods[j]);
                    NSString *s = NSStringFromSelector(selector);
                    if (relevant(s)) printf("  %c %s | %s\n", meta ? '+' : '-', s.UTF8String, method_getTypeEncoding(methods[j]));
                }
                free(methods);
            }
            unsigned int n;
            Ivar *ivars = class_copyIvarList(classes[i], &n);
            for (unsigned int j = 0; j < n; j++) {
                NSString *s = @(ivar_getName(ivars[j]));
                if (relevant(s)) printf("  ivar %s | %s\n", s.UTF8String, ivar_getTypeEncoding(ivars[j]));
            }
            free(ivars);
        }
        free(classes);
    }
    return 0;
}
