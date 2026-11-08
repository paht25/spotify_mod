#import <Foundation/Foundation.h>
NSString *USPersonalLibraryDirectory(void);
NSString *USPersonalAssetPath(NSString *name);
NSArray<NSDictionary *> *USPersonalAssets(void);
NSDictionary *USImportPersonalAsset(NSURL *url,NSError **error);
BOOL USApplyPersonalAsset(NSDictionary *asset,NSError **error);
BOOL USDeletePersonalAsset(NSDictionary *asset,NSError **error);
NSString *USSelectedShaderSource(void);
void USRestorePersonalFont(void);
