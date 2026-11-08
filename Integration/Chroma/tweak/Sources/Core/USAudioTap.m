// Personal read-only output observer. Never records, exports or rewrites audio.
#import "USAudioTap.h"
#import "SGRebind.h"
#import "USRuntimeState.h"
#import <AudioToolbox/AudioToolbox.h>
#include <stdlib.h>
#include <math.h>
typedef struct {
    USAudioSpectrum spectrum;
    atomic_uint_fast64_t format;
    atomic_uint rate;
} USTap;
static _Atomic(USTap *) current;
static atomic_uint readers;
void USAudioTapRetainReader(void){atomic_fetch_add(&readers,1);}
void USAudioTapReleaseReader(void){unsigned n=atomic_load(&readers);while(n&&!atomic_compare_exchange_weak(&readers,&n,n-1)){} }
static OSStatus (*originalStart)(AudioUnit);
const USAudioSpectrum *USCurrentAudioSpectrum(void) {
    USTap *tap=atomic_load_explicit(&current,memory_order_acquire);
    return tap?&tap->spectrum:NULL;
}
static OSStatus rendered(void *ref,AudioUnitRenderActionFlags *flags,const AudioTimeStamp *time,UInt32 bus,UInt32 frames,AudioBufferList *data) {
    (void)time;
    if(!atomic_load_explicit(&readers,memory_order_relaxed)||!flags||!(*flags&kAudioUnitRenderAction_PostRender)||bus||!data||!frames)return noErr;
    USTap *tap=ref;uint64_t layout=atomic_load_explicit(&tap->format,memory_order_acquire);
    UInt32 format=(UInt32)layout,channels=(UInt32)(layout>>32)&0xffff,bytes=(UInt32)(layout>>48);
    BOOL split=(format&kAudioFormatFlagIsNonInterleaved)!=0,isFloat=(format&kAudioFormatFlagIsFloat)!=0;
    BOOL silent=(*flags&kAudioUnitRenderAction_OutputIsSilence)!=0;
    if(!channels||!bytes||(!silent&&(split?data->mNumberBuffers!=channels:data->mNumberBuffers!=1)))return noErr;
    if(!silent)for(UInt32 b=0;b<data->mNumberBuffers;b++)
        if(!data->mBuffers[b].mData||data->mBuffers[b].mDataByteSize<(uint64_t)frames*bytes*(split?1:channels))return noErr;
    float lanes[2][256];
    unsigned rate=atomic_load_explicit(&tap->rate,memory_order_relaxed);
    UInt32 fraction=(format&kLinearPCMFormatFlagsSampleFractionMask)>>kLinearPCMFormatFlagsSampleFractionShift;
    for(UInt32 done=0;done<frames;){
        UInt32 count=MIN(256,frames-done);
        for(UInt32 i=0;i<count;i++){
            lanes[0][i]=lanes[1][i]=0;
            if(!silent)for(UInt32 c=0;c<MIN(channels,2);c++){
                const void *buffer=data->mBuffers[split?c:0].mData;
                UInt32 at=(done+i)*(split?1:channels)+(split?0:c);
                if(bytes==4&&isFloat)lanes[c][i]=((const float *)buffer)[at];
                else if(bytes==4)lanes[c][i]=(float)(((const int32_t *)buffer)[at]/(fraction?ldexp(1.0,(int)fraction):2147483648.0));
                else lanes[c][i]=((const int16_t *)buffer)[at]/32768.f;
            }
            if(channels==1)lanes[1][i]=lanes[0][i];
        }
        USSpectrumPushStereo(&tap->spectrum,lanes[0],lanes[1],count,rate);done+=count;
    }
    return noErr;
}
static void attach(AudioUnit unit) {
    AudioComponentDescription component={0};
    if(!unit||AudioComponentGetDescription(AudioComponentInstanceGetComponent(unit),&component)!=noErr||
       component.componentType!=kAudioUnitType_Output||component.componentSubType!=kAudioUnitSubType_RemoteIO)return;
    AudioStreamBasicDescription format={0};UInt32 size=sizeof(format);
    if(AudioUnitGetProperty(unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output,0,&format,&size)!=noErr)return;
    unsigned bytes=format.mBitsPerChannel/8;
    if(format.mFormatID!=kAudioFormatLinearPCM||format.mSampleRate<8000||format.mSampleRate>384000||
       format.mChannelsPerFrame<1||format.mChannelsPerFrame>32||
       (format.mFormatFlags&kAudioFormatFlagIsBigEndian)||
       !((bytes==4&&(format.mFormatFlags&(kAudioFormatFlagIsFloat|kAudioFormatFlagIsSignedInteger)))||
         (bytes==2&&(format.mFormatFlags&kAudioFormatFlagIsSignedInteger))))return;
    // Audio units may restart. One notify per unit; contexts remain alive for the
    // process lifetime, so an in-flight render cannot access freed memory.
    static NSMutableDictionary<NSValue *,NSValue *> *contexts;
    @synchronized(NSProcessInfo.class){
        if(!contexts)contexts=[NSMutableDictionary dictionary];
        NSValue *key=[NSValue valueWithPointer:unit];USTap *tap=[contexts[key] pointerValue];
        if(!tap){
            tap=calloc(1,sizeof(*tap));if(!tap)return;USSpectrumInitialize(&tap->spectrum);
            atomic_init(&tap->format,0);atomic_init(&tap->rate,0);
            contexts[key]=[NSValue valueWithPointer:tap];
        }
        atomic_store_explicit(&tap->rate,(unsigned)format.mSampleRate,memory_order_relaxed);
        atomic_store_explicit(&tap->format,(uint64_t)format.mFormatFlags|((uint64_t)format.mChannelsPerFrame<<32)|((uint64_t)bytes<<48),memory_order_release);
        // Also handles a disposed output unit address being reused. Remove only
        // our own observer before installing it on the currently valid unit.
        AudioUnitRemoveRenderNotify(unit,rendered,tap);
        if(AudioUnitAddRenderNotify(unit,rendered,tap)!=noErr){USStateSet(@"personal.audioTap",@"render notify rejected");return;}
        atomic_store_explicit(&current,tap,memory_order_release);
    }
    USStateSet(@"personal.audioTap",@"attached to real output");
}
static OSStatus start(AudioUnit unit) {attach(unit);return originalStart(unit);}
void USInstallAudioTap(void) {
    static dispatch_once_t once;dispatch_once(&once,^{
        BOOL ok=SGRebindImport("AudioOutputUnitStart",(void *)start,(void **)&originalStart);
        USStateSet(@"personal.audioTap",ok?@"waiting for audio output":@"Spotify audio import unavailable");
    });
}
