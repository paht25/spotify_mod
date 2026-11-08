#import "USAssetValidation.h"
#include <math.h>
static BOOL fail(NSError **error,NSString *reason) {
    if(error)*error=[NSError errorWithDomain:@"PersonalLibrary" code:1 userInfo:@{NSLocalizedDescriptionKey:reason}];return NO;
}
NSDictionary *USPresetValues(NSData *data,NSError **error) {
    if(!data.length){fail(error,@"Preset is empty");return nil;}
    id json=[NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if(![json isKindOfClass:NSDictionary.class]||![json[@"schema"] isEqual:@"personal.audio-preset.v1"]||![json[@"values"] isKindOfClass:NSDictionary.class]){
        fail(error,@"Expected personal.audio-preset.v1 JSON with a values dictionary");return nil;
    }
    NSDictionary *ranges=@{@"postGain":@[@(-12),@12],@"bassGain":@[@1,@15],@"width":@[@0,@100],@"tubeDrive":@[@0,@18]};
    NSSet *allowed=[NSSet setWithArray:@[@"postGain",@"bassGain",@"width",@"tubeDrive",@"equalizer",@"bass",@"wide",@"tube"]];
    NSDictionary *values=json[@"values"];
    for(NSString *key in values){
        if(![allowed containsObject:key]){fail(error,[@"Unknown preset value: " stringByAppendingString:key]);return nil;}
        id v=values[key];
        if([key isEqual:@"equalizer"]){
            if(![v isKindOfClass:NSArray.class]||[v count]!=15){fail(error,@"Equalizer needs 15 gains");return nil;}
            for(id gain in v)if(![gain isKindOfClass:NSNumber.class]||CFGetTypeID((__bridge CFTypeRef)gain)==CFBooleanGetTypeID()||!isfinite([gain doubleValue])||fabs([gain doubleValue])>12){fail(error,@"EQ gains must be finite and within ±12 dB");return nil;}
        }else if(ranges[key]){
            NSArray *range=ranges[key];
            if(![v isKindOfClass:NSNumber.class]||CFGetTypeID((__bridge CFTypeRef)v)==CFBooleanGetTypeID()||!isfinite([v doubleValue])||[v doubleValue]<[range[0] doubleValue]||[v doubleValue]>[range[1] doubleValue]){fail(error,@"Preset number is outside its allowed range");return nil;}
        }else if(![v isKindOfClass:NSNumber.class]||CFGetTypeID((__bridge CFTypeRef)v)!=CFBooleanGetTypeID()){
            fail(error,@"Effect switches must be JSON booleans");return nil;
        }
    }
    return values;
}
BOOL USValidateGraphicEQ(NSData *data,NSError **error) {
    if(!data.length)return fail(error,@"GraphicEQ is empty");
    NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    if(![text hasPrefix:@"GraphicEQ:"])return fail(error,@"Expected a GraphicEQ: frequency gain; ... text file");
    NSMutableArray *pairs=[[[text substringFromIndex:10] componentsSeparatedByString:@";"] mutableCopy];
    while(pairs.count && ![[pairs.lastObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] length])[pairs removeLastObject];
    if(!pairs.count||pairs.count>512)return fail(error,@"GraphicEQ needs 1–512 points");
    double last=0;
    for(NSString *pair in pairs){
        NSScanner *scanner=[NSScanner scannerWithString:pair];double hz=0,db=0;
        if(![scanner scanDouble:&hz]||![scanner scanDouble:&db]||!scanner.isAtEnd||!isfinite(hz)||!isfinite(db)||hz<20||hz>20000||hz<=last||fabs(db)>24)
            return fail(error,@"GraphicEQ points must be sorted, 20–20000 Hz and within ±24 dB");
        last=hz;
    }
    return YES;
}
