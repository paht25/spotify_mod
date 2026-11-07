#import <Foundation/Foundation.h>
void USStateSet(NSString *key, NSString *value);
void USStateIncrement(NSString *key);
NSDictionary<NSString *, id> *USStateSnapshot(void);
BOOL USSettingEnabled(NSString *key, BOOL fallback);
