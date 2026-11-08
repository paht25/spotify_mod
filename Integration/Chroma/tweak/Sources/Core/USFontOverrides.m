#import "USFontOverrides.h"
#import "USHookRegistry.h"
#import "USRuntimeState.h"
#import <UIKit/UIKit.h>
#include <math.h>
static NSString *selectedFont;
static _Thread_local BOOL resolving;
static UIFont *font(CGFloat size,CGFloat weight) {
    if(resolving||!isfinite(size)||size<=0)return nil;
    NSString *name;@synchronized(UIFont.class){name=selectedFont;}
    if(!name.length)return nil;
    resolving=YES;
    @try {
        UIFont *base=[UIFont fontWithName:name size:size];if(!base)return nil;
        UIFontDescriptor *descriptor=[base.fontDescriptor fontDescriptorByAddingAttributes:@{UIFontDescriptorTraitsAttribute:@{UIFontWeightTrait:@(weight)}}];
        return [UIFont fontWithDescriptor:descriptor size:size]?:base;
    } @finally {resolving=NO;}
}
void USSetPersonalFontName(NSString *name) {
    @synchronized(UIFont.class){selectedFont=[name copy];}
    static dispatch_once_t once;dispatch_once(&once,^{
        Class meta=object_getClass(UIFont.class);
        for(NSString *method in @[@"systemFontOfSize:",@"boldSystemFontOfSize:",@"systemFontOfSize:weight:"]){
            SEL selector=NSSelectorFromString(method);Method m=class_getInstanceMethod(meta,selector);
            if(!m)continue;
            unsigned args=method_getNumberOfArguments(m);char type[32]={0};method_getReturnType(m,type,sizeof(type));
            if(type[0]!='@'||(args!=3&&args!=4))continue;
            BOOL valid=YES;for(unsigned i=2;i<args;i++){method_getArgumentType(m,i,type,sizeof(type));if(type[0]!='d')valid=NO;}
            if(!valid)continue;
            IMP original=method_getImplementation(m),replacement;
            if(args==4)replacement=imp_implementationWithBlock(^UIFont *(id cls,CGFloat size,CGFloat weight){
                return font(size,weight)?:((id(*)(id,SEL,CGFloat,CGFloat))original)(cls,selector,size,weight);
            });
            else {BOOL bold=[method hasPrefix:@"bold"];
                replacement=imp_implementationWithBlock(^UIFont *(id cls,CGFloat size){
                    return font(size,bold?UIFontWeightBold:UIFontWeightRegular)?:((id(*)(id,SEL,CGFloat))original)(cls,selector,size);
                });
            }
            NSError *error=nil;
            if(![[USHookRegistry new]installOnClass:meta selector:selector owner:@"personal.font" expectedEncoding:method_getTypeEncoding(m) expectedOriginal:original replacement:replacement error:&error]){
                imp_removeBlock(replacement);USStateSet(@"personal.font",error.localizedDescription);
            }
        }
    });
}
