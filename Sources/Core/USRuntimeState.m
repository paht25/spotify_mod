#import "USRuntimeState.h"
static NSMutableDictionary<NSString *, id> *state;
void USStateSet(NSString *key, NSString *value) {
    @synchronized (NSProcessInfo.class) {
        if (!state) state=[NSMutableDictionary dictionary]; state[key]=value;
    }
}
void USStateIncrement(NSString *key) {
    @synchronized (NSProcessInfo.class) {
        if (!state) state=[NSMutableDictionary dictionary]; state[key]=@([state[key] unsignedLongLongValue]+1);
    }
}
NSDictionary<NSString *, id> *USStateSnapshot(void) {
    @synchronized (NSProcessInfo.class) { return state ? [state copy] : @{}; }
}
BOOL USSettingEnabled(NSString *key, BOOL fallback) {
    id value=[NSUserDefaults.standardUserDefaults objectForKey:key];
    return [value isKindOfClass:NSNumber.class] ? [value boolValue] : fallback;
}
