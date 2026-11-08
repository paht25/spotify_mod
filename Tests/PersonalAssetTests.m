#import <Foundation/Foundation.h>
#import "USAssetValidation.h"
#include <stdlib.h>
static NSData *bytes(NSString *s){return [s dataUsingEncoding:NSUTF8StringEncoding];}
static void check(BOOL ok,NSString *message){if(!ok){NSLog(@"FAIL: %@",message);exit(1);}}
int main(void){@autoreleasepool{
    NSDictionary *valid=@{@"schema":@"personal.audio-preset.v1",@"values":@{@"postGain":@(-3),@"bass":@YES,@"bassGain":@5}};
    NSData *data=[NSJSONSerialization dataWithJSONObject:valid options:0 error:nil];
    check([USPresetValues(data,nil) isEqual:valid[@"values"]],@"valid preset returns actual settings");
    check(!USPresetValues(bytes(@"not JSON"),nil),@"malformed input rejected");
    check(!USPresetValues(bytes(@"{\"schema\":\"personal.audio-preset.v1\",\"values\":{\"account\":true}}"),nil),@"cannot inject account settings");
    check(!USPresetValues(bytes(@"{\"schema\":\"personal.audio-preset.v1\",\"values\":{\"postGain\":true}}"),nil),@"boolean is not an audio gain");
    check(!USPresetValues(bytes(@"{\"schema\":\"personal.audio-preset.v1\",\"values\":{\"bass\":1}}"),nil),@"switch requires JSON boolean");
    check(!USPresetValues(bytes(@"{\"schema\":\"personal.audio-preset.v1\",\"values\":{\"equalizer\":[0]}}"),nil),@"bad EQ dimensions rejected");
    check(!USPresetValues(bytes(@"{\"schema\":\"personal.audio-preset.v1\",\"values\":{\"tubeDrive\":999}}"),nil),@"unsafe gain rejected");
    check(USValidateGraphicEQ(bytes(@"GraphicEQ: 20 -2; 100 0; 1000 3; 20000 -4;\n"),nil),@"AutoEq points and trailing separator accepted");
    check(!USValidateGraphicEQ(bytes(@"GraphicEQ: 1000 0; 20 0"),nil),@"out of order points rejected");
    check(!USValidateGraphicEQ(bytes(@"GraphicEQ: 20 100"),nil),@"unsafe correction gain rejected");
    check(!USValidateGraphicEQ(bytes(@"GraphicEQ: 20 0; ; 100 0"),nil),@"malformed middle pair rejected");
    check(!USValidateGraphicEQ(bytes(@"GraphicEQ:"),nil),@"empty curve rejected");
    NSLog(@"PASS: actual production preset and GraphicEQ validators; file UI/DSP playback remain untested");
}return 0;}
