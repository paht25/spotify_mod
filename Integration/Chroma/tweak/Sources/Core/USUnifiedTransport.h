#import <Foundation/Foundation.h>
@class UIViewController;
BOOL USUnifiedTargetSupported(void);
void USUnifiedReceiveResponse(id delegate, NSURLSessionTask *task, NSURLResponse *response);
BOOL USUnifiedCaptureData(id delegate, NSURLSession *session, NSURLSessionDataTask *task, NSData *data);
BOOL USUnifiedComplete(id delegate, NSURLSession *session, NSURLSessionTask *task, NSError *error);
UIViewController *USUnifiedSettingsPage(void);
