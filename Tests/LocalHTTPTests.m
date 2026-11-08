#import <Foundation/Foundation.h>
#import "USLocalHTTP.h"
#include <stdlib.h>
static NSData *text(NSString *s){return [s dataUsingEncoding:NSASCIIStringEncoding];}
static void check(BOOL ok,NSString *message){if(!ok){NSLog(@"FAIL local HTTP: %@",message);exit(1);}}
int main(void){@autoreleasepool{
    BOOL more=NO;NSError *error=nil;
    NSDictionary *request=USParseLocalRequest(text(@"GET /state HTTP/1.1\r\nHost: 192.168.1.1\r\nAuthorization: Bearer abc\r\n\r\n"),&more,&error);
    check(request&&!more&&!error,@"valid state read");
    check(USLocalCapabilityMatches(request[@"headers"][@"authorization"],@"abc"),@"correct capability");
    check(!USLocalCapabilityMatches(@"Bearer abd",@"abc")&&!USLocalCapabilityMatches(nil,@"abc"),@"wrong or missing capability rejected");
    check(!USParseLocalRequest(text(@"GET /state HTTP/1.1\r\n"),&more,&error)&&more,@"partial header waits");
    check(!USParseLocalRequest(text(@"POST /command HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{"),&more,&error)&&more,@"fragmented command waits");
    check(USParseLocalRequest(text(@"POST /command HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}"),&more,&error)!=nil,@"complete command parsed");
    for(NSString *bad in @[@"GET /../secret HTTP/1.1\r\n\r\n",@"GET /state HTTP/1.1\r\nAuthorization: x\r\nAuthorization: y\r\n\r\n",@"POST /command HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n",@"POST /command HTTP/1.1\r\nContent-Length: -1\r\n\r\n",@"GET / HTTP/1.1\r\n\r\nextra"]){
        error=nil;more=NO;check(!USParseLocalRequest(text(bad),&more,&error)&&error&&!more,@"malformed request rejected");
    }
    NSLog(@"PASS: real local HTTP parser and capability checks; listener/device commands remain untested");
}return 0;}
