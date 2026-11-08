// Independently authored spectrum shader renderer; no Chroma binary/assets used.
#import "USReactiveView.h"
#import "USAssetStore.h"
#import "Core/USAudioTap.h"
#import "Core/USRuntimeState.h"
#import <MetalKit/MetalKit.h>
#import <simd/simd.h>
#include <string.h>
#include <math.h>

static NSString *const builtin =
@"#include <metal_stdlib>\nusing namespace metal;\n"
"struct U{float2 size;float time;float energy;float bands[32];uint style;float gain;float2 padding;};\n"
"struct V{float4 position [[position]];float2 uv;};\n"
"vertex V us_vertex(uint i [[vertex_id]]){float2 p=float2((i<<1)&2,i&2);V v;v.position=float4(p*2-1,0,1);v.uv=float2(p.x,1-p.y);return v;}\n"
"fragment float4 us_fragment(V v [[stage_in]],constant U&u [[buffer(0)]]){\n"
"float2 uv=v.uv;float2 q=(uv-.5)*float2(u.size.x/max(u.size.y,1.0f),1);\n"
"uint b=min(uint(clamp(uv.x,0.0f,.999f)*32),31u);float amp=clamp(u.bands[b]*u.gain,0.0f,1.0f);float glow=0;\n"
"if(u.style==0){float x=fract(uv.x*32);glow=step(.005f,amp)*(1-smoothstep(amp*.65,amp*.65+.01,1-uv.y))*smoothstep(0.0f,.12f,x)*(1-smoothstep(.88f,1.0f,x));}\n"
"else if(u.style==1){float a=(atan2(q.y,q.x)+3.14159265f)/6.2831853f;uint k=min(uint(a*32),31u);float r=.18+u.bands[k]*.2*u.gain;glow=exp(-65*abs(length(q)-r))*u.energy*5;}\n"
"else{float wave=sin(q.x*12-u.time*1.2f)*amp*.2;glow=exp(-75*abs(q.y-wave))*amp;}\n"
"float3 colour=.55+.45*cos(float3(0,2,4)+uv.x*3+u.time*.08);return float4(float3(.008,.012,.018)+colour*clamp(glow,0.0f,1.0f),1);}\n";
typedef struct {vector_float2 size;float time,energy;float bands[32];uint32_t style;float gain;vector_float2 padding;} USUniforms;
_Static_assert(sizeof(USUniforms)==160,"Metal uniform layout changed");
@interface USReactiveView : MTKView <MTKViewDelegate>
@end
@implementation USReactiveView {
    id<MTLCommandQueue> _commands;
    id<MTLRenderPipelineState> _pipeline;
    CFTimeInterval _start,_lastAudio;
    uint64_t _lastWritten;
    float _bands[32],_energy;
    BOOL _reading;
    dispatch_queue_t _shaderQueue;
    NSUInteger _shaderGeneration;
}
- (instancetype)init {
    id<MTLDevice> device=MTLCreateSystemDefaultDevice();if(!device)return nil;
    if(!(self=[super initWithFrame:CGRectZero device:device]))return nil;
    self.delegate=self;self.userInteractionEnabled=NO;self.accessibilityElementsHidden=YES;
    self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;self.colorPixelFormat=MTLPixelFormatBGRA8Unorm;
    self.framebufferOnly=YES;self.preferredFramesPerSecond=30;self.paused=YES;
    self.autoResizeDrawable=NO;
    _commands=[device newCommandQueue];_start=CACurrentMediaTime();
    _shaderQueue=dispatch_queue_create("personal.shader.compile",DISPATCH_QUEUE_SERIAL);self.hidden=YES;
    [self reloadShader];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(libraryChanged:) name:@"UnifiedPersonalLibraryChanged" object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appChanged:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appChanged:) name:UIApplicationDidBecomeActiveNotification object:nil];
    return self;
}
- (void)dealloc {if(_reading)USAudioTapReleaseReader();[NSNotificationCenter.defaultCenter removeObserver:self];}
- (void)libraryChanged:(NSNotification *)notification {(void)notification;[self reloadShader];}
- (void)appChanged:(NSNotification *)notification {(void)notification;[self activityChanged];}
- (void)reloadShader {
    NSString *source=USSelectedShaderSource()?:builtin;id<MTLDevice> device=self.device;
    NSUInteger generation=++_shaderGeneration;MTLPixelFormat pixelFormat=self.colorPixelFormat;
    dispatch_async(_shaderQueue,^{
        NSError *error=nil;NSString *note=nil;
        id<MTLLibrary> library=[device newLibraryWithSource:source options:nil error:&error];
        id<MTLFunction> vertex=[library newFunctionWithName:@"us_vertex"],fragment=[library newFunctionWithName:@"us_fragment"];
        if(!vertex||!fragment){
            note=error.localizedDescription?:@"Shader must define us_vertex and us_fragment; built-in restored";
            library=[device newLibraryWithSource:builtin options:nil error:nil];
            vertex=[library newFunctionWithName:@"us_vertex"];fragment=[library newFunctionWithName:@"us_fragment"];
        }
        id<MTLRenderPipelineState> pipeline=nil;
        if(vertex&&fragment){
            MTLRenderPipelineDescriptor *description=[MTLRenderPipelineDescriptor new];
            description.vertexFunction=vertex;description.fragmentFunction=fragment;description.colorAttachments[0].pixelFormat=pixelFormat;
            pipeline=[device newRenderPipelineStateWithDescriptor:description error:&error];
        }
        NSString *status=pipeline?(note?:@"compiled on device"):(error.localizedDescription?:@"Metal pipeline rejected");
        dispatch_async(dispatch_get_main_queue(),^{
            if(generation!=self->_shaderGeneration)return;
            if(pipeline){self->_pipeline=pipeline;self.hidden=NO;}
            USStateSet(@"personal.shader",status);
        });
    });
}
- (void)didMoveToWindow {[super didMoveToWindow];[self activityChanged];}
- (void)layoutSubviews {
    [super layoutSubviews];CGFloat edge=MAX(self.bounds.size.width,self.bounds.size.height);
    if(edge>0){CGFloat scale=MIN(1.5,1280/edge);self.drawableSize=CGSizeMake(MAX(1,self.bounds.size.width*scale),MAX(1,self.bounds.size.height*scale));}
}
- (void)activityChanged {
    BOOL active=self.window&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive&&
        USSettingEnabled(@"unifiedspotify.personal.visualizer",NO);
    self.paused=!active;
    if(active!=_reading){if(active)USAudioTapRetainReader();else USAudioTapReleaseReader();_reading=active;}
}
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {(void)view;(void)size;}
- (void)drawInMTKView:(MTKView *)view {
    (void)view;
    if(!_pipeline||!_commands)return;
    NSProcessInfo *process=NSProcessInfo.processInfo;
    self.preferredFramesPerSecond=(process.lowPowerModeEnabled||process.thermalState>=NSProcessInfoThermalStateSerious||UIAccessibilityIsReduceMotionEnabled())?15:30;
    if(process.thermalState==NSProcessInfoThermalStateCritical)return;
    CFTimeInterval now=CACurrentMediaTime();USSpectrumValue spectrum={0};const USAudioSpectrum *meter=USCurrentAudioSpectrum();
    BOOL fresh=meter&&USSpectrumRead(meter,&spectrum);
    if(fresh&&spectrum.written!=_lastWritten){_lastWritten=spectrum.written;_lastAudio=now;}
    BOOL sounding=fresh&&now-_lastAudio<.25;
    for(unsigned i=0;i<32;i++)_bands[i]=_bands[i]*.72f+(sounding?spectrum.bands[i]:0)*.28f;
    _energy=_energy*.72f+(sounding?spectrum.rms:0)*.28f;
    USUniforms u={0};u.size=(vector_float2){(float)self.drawableSize.width,(float)self.drawableSize.height};
    u.time=UIAccessibilityIsReduceMotionEnabled()?0:(float)(now-_start);u.energy=_energy;
    memcpy(u.bands,_bands,sizeof(_bands));u.style=(uint32_t)MAX(0,MIN(2,[NSUserDefaults.standardUserDefaults integerForKey:@"unifiedspotify.personal.visualizerStyle"]));
    double gain=[NSUserDefaults.standardUserDefaults doubleForKey:@"unifiedspotify.personal.visualizerGain"];
    u.gain=isfinite(gain)&&gain>0?(float)MAX(.2,MIN(4,gain)):1;
    MTLRenderPassDescriptor *pass=self.currentRenderPassDescriptor;id<CAMetalDrawable> drawable=self.currentDrawable;
    if(!pass||!drawable)return;
    id<MTLCommandBuffer> command=[_commands commandBuffer];id<MTLRenderCommandEncoder> encoder=[command renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:_pipeline];[encoder setFragmentBytes:&u length:sizeof(u) atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];[encoder endEncoding];
    [command presentDrawable:drawable];[command commit];
}
@end
UIView *USCreateReactiveBackground(void) {
    if(!USSettingEnabled(@"unifiedspotify.personal.visualizer",NO))return nil;
    return [USReactiveView new];
}
