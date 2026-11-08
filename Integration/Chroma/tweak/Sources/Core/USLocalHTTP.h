#import <Foundation/Foundation.h>
// nil + needsMore: wait for another chunk. nil + error: reject the request.
NSDictionary *USParseLocalRequest(NSData *data,BOOL *needsMore,NSError **error);
BOOL USLocalCapabilityMatches(NSString *provided,NSString *token);
