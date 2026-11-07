#import "USUnifiedPreferences.h"
BOOL USUnifiedPreferenceKey(NSString *key) {
    return [key hasPrefix:@"unifiedspotify."] ||
        [@[@"overwriteConfiguration",@"trueShuffleEnabled",@"eeveeBlockRatingPrompts",@"cleanShareLinks",@"patchType"] containsObject:key];
}
