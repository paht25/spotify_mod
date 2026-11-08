#import "USLocalHTTP.h"
static NSDictionary *bad(NSError **error,NSString *reason) {
    if(error)*error=[NSError errorWithDomain:@"PersonalHTTP" code:400 userInfo:@{NSLocalizedDescriptionKey:reason}];return nil;
}
NSDictionary *USParseLocalRequest(NSData *data,BOOL *more,NSError **error) {
    if(more)*more=NO;if(data.length>18432)return bad(error,@"Request too large");
    NSData *separator=[@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    NSRange boundary=[data rangeOfData:separator options:0 range:NSMakeRange(0,data.length)];
    if(boundary.location==NSNotFound){if(data.length>=16384)return bad(error,@"Header too large");if(more)*more=YES;return nil;}
    if(boundary.location>16384)return bad(error,@"Header too large");
    NSString *header=[[NSString alloc]initWithData:[data subdataWithRange:NSMakeRange(0,boundary.location)] encoding:NSASCIIStringEncoding];
    if(!header)return bad(error,@"Non-ASCII header");
    NSArray *lines=[header componentsSeparatedByString:@"\r\n"],*first=[lines.firstObject componentsSeparatedByString:@" "];
    if(first.count!=3||![first[2] isEqual:@"HTTP/1.1"])return bad(error,@"Unsupported request line");
    NSString *method=first[0],*path=first[1];
    if(![@[@"GET",@"POST"]containsObject:method]||![@[@"/",@"/state",@"/command"]containsObject:path])return bad(error,@"Unsupported route");
    NSMutableDictionary *headers=[NSMutableDictionary dictionary];
    for(NSUInteger i=1;i<lines.count;i++){
        NSString *line=lines[i];NSRange colon=[line rangeOfString:@":"];
        if(colon.location==NSNotFound||!colon.location||[line hasPrefix:@" "]||[line hasPrefix:@"\t"])return bad(error,@"Invalid header");
        NSString *key=[[line substringToIndex:colon.location] lowercaseString];
        if(headers[key])return bad(error,@"Duplicate header");
        headers[key]=[[line substringFromIndex:colon.location+1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    if(headers[@"transfer-encoding"])return bad(error,@"Transfer encoding is unsupported");
    NSUInteger size=0;NSString *length=headers[@"content-length"];
    if(length){
        if(!length.length||length.length>4||[length rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location!=NSNotFound)return bad(error,@"Invalid body length");
        size=length.integerValue;
    }
    if(size>2048||([method isEqual:@"GET"]&&size))return bad(error,@"Body too large");
    NSUInteger start=NSMaxRange(boundary);
    if(data.length<start+size){if(more)*more=YES;return nil;}
    if(data.length!=start+size)return bad(error,@"Pipelined data rejected");
    if([method isEqual:@"POST"]&&(![path isEqual:@"/command"]||![headers[@"content-type"]hasPrefix:@"application/json"]))return bad(error,@"Expected a JSON command");
    if([path isEqual:@"/command"]&&![method isEqual:@"POST"])return bad(error,@"Command requires POST");
    return @{@"method":method,@"path":path,@"headers":headers,@"body":[data subdataWithRange:NSMakeRange(start,size)]};
}
BOOL USLocalCapabilityMatches(NSString *provided,NSString *token) {
    if(!provided.length||!token.length)return NO;
    NSData *a=[provided dataUsingEncoding:NSASCIIStringEncoding],*b=[[@"Bearer " stringByAppendingString:token] dataUsingEncoding:NSASCIIStringEncoding];
    if(!a||a.length!=b.length)return NO;
    const unsigned char *x=a.bytes,*y=b.bytes;unsigned char difference=0;
    for(NSUInteger i=0;i<a.length;i++)difference|=x[i]^y[i];return difference==0;
}
