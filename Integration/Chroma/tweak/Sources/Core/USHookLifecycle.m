#import "USHookLifecycle.h"
#import "USEeveeServices.h"
#import "USAudioAdHooks.h"
#import "USRuntimeState.h"
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#include <stdatomic.h>
#include <stdbool.h>

static atomic_bool pending;
static void reconcile(void) {
    USInstallEeveeServices();
    USInstallAudioAdHooks();
    USStateIncrement(@"hooks.reconcilePasses");
}
static void requestReconcile(void) {
    // dyld callbacks must not inspect Objective-C classes under the loader
    // lock. Coalesce notifications and defer all runtime work to the main queue.
    if(atomic_exchange(&pending,true))return;
    dispatch_async(dispatch_get_main_queue(),^{
        atomic_store(&pending,false);
        reconcile();
    });
}
static void imageAdded(const struct mach_header *header,intptr_t slide) {
    (void)header;(void)slide;requestReconcile();
}
@interface USHookLifecycleObserver : NSObject
+ (void)becameActive:(NSNotification *)note;
@end
@implementation USHookLifecycleObserver
+ (void)becameActive:(NSNotification *)note {(void)note;requestReconcile();}
@end
void USStartHookLifecycle(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{
        atomic_init(&pending,false);
        _dyld_register_func_for_add_image(imageAdded);
        dispatch_async(dispatch_get_main_queue(),^{
            // The class object lives for the process lifetime; no unconsumed
            // block-observer token or temporary receiver is needed.
            [NSNotificationCenter.defaultCenter addObserver:USHookLifecycleObserver.class
                selector:@selector(becameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
            // Swift classes can become registered after their image callback.
            // Keep checking only while foregrounded, with no background timer.
            static NSTimer *timer;
            timer=[NSTimer timerWithTimeInterval:30 repeats:YES block:^(NSTimer *tick){
                (void)tick;
                if(UIApplication.sharedApplication.applicationState==UIApplicationStateActive)requestReconcile();
            }];
            timer.tolerance=5;
            [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
            USStateSet(@"hooks.lifecycle",@"image + foreground + active-only reconciliation");
            requestReconcile();
        });
    });
}
