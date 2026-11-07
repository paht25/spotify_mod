#import <Foundation/Foundation.h>
/// Returns NO if selectors/ABIs are absent, inherited or already modified.
BOOL USInstallFeedHooks(Class delegateClass, NSError **error);
