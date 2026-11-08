// Local files only. No Chroma Workshop API, account, cookies or Plus checks.
#import "USAssetStore.h"
#import "Core/USAssetValidation.h"
#import "Core/USFontOverrides.h"
#import "Core/USRuntimeState.h"
#import "Shared/AudioEffects/AudioEffects.h"
#import <CoreText/CoreText.h>
#include <math.h>
static NSString *const changed=@"UnifiedPersonalLibraryChanged";
static NSString *const shaderKey=@"unifiedspotify.personal.shaderFile";
static NSString *const fontKey=@"unifiedspotify.personal.fontFile";
static void notify(void) {
    dispatch_async(dispatch_get_main_queue(),^{[NSNotificationCenter.defaultCenter postNotificationName:changed object:nil];});
}
static BOOL fail(NSError **error,NSString *reason) {
    if(error)*error=[NSError errorWithDomain:@"PersonalLibrary" code:1 userInfo:@{NSLocalizedDescriptionKey:reason}];return NO;
}
NSString *USPersonalLibraryDirectory(void) {
    NSString *documents=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    NSString *directory=[documents stringByAppendingPathComponent:@"UnifiedSpotify/Library"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return directory;
}
NSString *USPersonalAssetPath(NSString *name) {
    if(![name isKindOfClass:NSString.class]||!name.length||![name isEqual:name.lastPathComponent]||[name hasPrefix:@"."])return nil;
    NSString *directory=USPersonalLibraryDirectory();
    NSString *path=[directory stringByAppendingPathComponent:name];
    NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    return [attributes[NSFileType] isEqual:NSFileTypeRegular]?path:nil;
}
static NSString *kind(NSString *extension) {
    return @{@"metal":@"shader",@"ttf":@"font",@"otf":@"font",@"json":@"audio-preset",@"txt":@"headphone-eq"}[extension.lowercaseString];
}
NSArray<NSDictionary *> *USPersonalAssets(void) {
    NSMutableArray *assets=[NSMutableArray array];
    NSArray *names=[NSFileManager.defaultManager contentsOfDirectoryAtPath:USPersonalLibraryDirectory() error:nil];
    for(NSString *name in [names sortedArrayUsingSelector:@selector(localizedStandardCompare:)]){
        NSString *type=kind(name.pathExtension);
        if(type&&USPersonalAssetPath(name)){
            NSString *title=name.stringByDeletingPathExtension;
            if(title.length>37&&[title characterAtIndex:title.length-37]=='-'&&[[NSUUID alloc]initWithUUIDString:[title substringFromIndex:title.length-36]])
                title=[title substringToIndex:title.length-37];
            [assets addObject:@{@"name":name,@"title":title,@"kind":type}];
        }
    }
    return assets;
}
NSDictionary *USImportPersonalAsset(NSURL *url,NSError **error) {
    NSString *type=kind(url.pathExtension);if(!type){fail(error,@"Import a shader, font, audio-preset JSON or GraphicEQ text file");return nil;}
    BOOL accessed=[url startAccessingSecurityScopedResource];
    NSNumber *length=nil;[url getResourceValue:&length forKey:NSURLFileSizeKey error:nil];
    NSUInteger limit=[type isEqual:@"font"]?8*1024*1024:256*1024;
    NSData *data=nil;
    if(length.unsignedLongLongValue<=limit){
        NSFileHandle *handle=[NSFileHandle fileHandleForReadingFromURL:url error:error];
        data=[handle readDataUpToLength:limit+1 error:error];[handle closeAndReturnError:nil];
    }
    if(accessed)[url stopAccessingSecurityScopedResource];
    if(!data||!data.length||data.length>limit){fail(error,@"File is empty, unreadable or too large");return nil;}
    if([type isEqual:@"audio-preset"]&&!USPresetValues(data,error))return nil;
    if([type isEqual:@"headphone-eq"]&&!USValidateGraphicEQ(data,error))return nil;
    if([type isEqual:@"shader"]&&![[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]){fail(error,@"Shader source must be UTF-8");return nil;}
    // Import under an opaque unique filename. Never overwrite another asset.
    NSString *display=url.lastPathComponent.stringByDeletingPathExtension.precomposedStringWithCanonicalMapping;
    NSMutableCharacterSet *keep=[NSCharacterSet.alphanumericCharacterSet mutableCopy];[keep addCharactersInString:@" -_"];
    NSString *clean=[[display componentsSeparatedByCharactersInSet:keep.invertedSet] componentsJoinedByString:@""];
    NSString *name=[clean substringToIndex:MIN(48,clean.length)];
    if(!name.length)name=@"Imported";
    NSString *filename=[NSString stringWithFormat:@"%@-%@.%@",name,NSUUID.UUID.UUIDString,url.pathExtension.lowercaseString];
    NSString *path=[USPersonalLibraryDirectory() stringByAppendingPathComponent:filename];
    if(![data writeToFile:path options:NSDataWritingWithoutOverwriting error:error])return nil;
    NSDictionary *asset=@{@"name":filename,@"kind":type};
    if([type isEqual:@"font"]){
        CFErrorRef issue=NULL;BOOL registered=CTFontManagerRegisterFontsForURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],kCTFontManagerScopeProcess,&issue);
        if(issue)CFRelease(issue);
        if(!registered){[NSFileManager.defaultManager removeItemAtPath:path error:nil];fail(error,@"CoreText rejected this font");return nil;}
    }
    notify();return asset;
}
static BOOL useFont(NSString *path,NSError **error) {
    NSURL *url=[NSURL fileURLWithPath:path];CFErrorRef issue=NULL;
    CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url,kCTFontManagerScopeProcess,&issue);if(issue)CFRelease(issue);
    NSArray *descriptors=CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url));
    if(!descriptors.count)return fail(error,@"No font face found");
    NSString *name=CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)descriptors.firstObject,kCTFontNameAttribute));
    if(!name.length)return fail(error,@"Font has no PostScript name");USSetPersonalFontName(name);return YES;
}
BOOL USApplyPersonalAsset(NSDictionary *asset,NSError **error) {
    NSString *path=USPersonalAssetPath(asset[@"name"]),*type=kind(path.pathExtension);if(!path)return fail(error,@"Asset file is missing");
    NSData *data=[NSData dataWithContentsOfFile:path options:0 error:error];if(!data)return NO;
    NSUserDefaults *prefs=NSUserDefaults.standardUserDefaults;
    if([type isEqual:@"shader"])[prefs setObject:asset[@"name"] forKey:shaderKey];
    else if([type isEqual:@"font"]){if(!useFont(path,error))return NO;[prefs setObject:asset[@"name"] forKey:fontKey];}
    else if([type isEqual:@"headphone-eq"]){
        if(!USValidateGraphicEQ(data,error))return NO;
        SGDSPSetString(SGKeyDSPGraphicEqNodes,[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]);SGDSPSetSwitch(SGKeyDSPGraphicEq,YES);SGDSPSetSwitch(SGKeyDSP,YES);
    }else if([type isEqual:@"audio-preset"]){
        NSDictionary *values=USPresetValues(data,error);if(!values)return NO;
        NSDictionary *numbers=@{@"postGain":SGKeyDSPPostGain,@"bassGain":SGKeyDSPBassGain,@"width":SGKeyDSPStereoWideLevel,@"tubeDrive":SGKeyDSPTubeDrive};
        NSDictionary *switches=@{@"bass":SGKeyDSPBass,@"wide":SGKeyDSPStereoWide,@"tube":SGKeyDSPTube};
        for(NSString *key in numbers)if(values[key])SGDSPSetNumber(numbers[key],[values[key] doubleValue]);
        for(NSString *key in switches)if(values[key])SGDSPSetSwitch(switches[key],[values[key] boolValue]);
        if(values[@"equalizer"]){SGDSPSetGains(SGKeyDSPEqualizerGains,values[@"equalizer"]);SGDSPSetSwitch(SGKeyDSPEqualizer,YES);}
        SGDSPSetSwitch(SGKeyDSP,YES);
    }else return fail(error,@"Unsupported asset kind");
    notify();return YES;
}
BOOL USDeletePersonalAsset(NSDictionary *asset,NSError **error) {
    NSString *name=asset[@"name"],*path=USPersonalAssetPath(name);if(!path)return fail(error,@"Asset file is missing");
    if(![NSFileManager.defaultManager removeItemAtPath:path error:error])return NO;
    NSUserDefaults *prefs=NSUserDefaults.standardUserDefaults;
    if([[prefs stringForKey:shaderKey]isEqual:name])[prefs removeObjectForKey:shaderKey];
    if([[prefs stringForKey:fontKey]isEqual:name]){[prefs removeObjectForKey:fontKey];USSetPersonalFontName(nil);}
    notify();return YES;
}
NSString *USSelectedShaderSource(void) {
    NSString *path=USPersonalAssetPath([NSUserDefaults.standardUserDefaults stringForKey:shaderKey]);
    if(!path)return nil;
    NSFileHandle *handle=[NSFileHandle fileHandleForReadingAtPath:path];
    NSData *data=[handle readDataUpToLength:256*1024+1 error:nil];[handle closeAndReturnError:nil];
    if(!data||data.length>256*1024)return nil;
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
}
void USRestorePersonalFont(void) {
    NSString *path=USPersonalAssetPath([NSUserDefaults.standardUserDefaults stringForKey:fontKey]);
    if(path){NSError *error=nil;if(!useFont(path,&error))USStateSet(@"personal.font",error.localizedDescription);}
}
