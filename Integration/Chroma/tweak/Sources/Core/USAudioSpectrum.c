// Independently authored personal module. No code from Chroma Plus.
#include "USAudioSpectrum.h"
#include <math.h>
#include <string.h>
#define US_PI 3.14159265358979323846f
_Static_assert(ATOMIC_BOOL_LOCK_FREE==2&&ATOMIC_INT_LOCK_FREE==2,"Audio publication must be lock-free");
void USSpectrumInitialize(USAudioSpectrum *s) {
    for(unsigned i=0;i<USSpectrumFrames*2;i++)atomic_init(&s->samples[i],0);
    atomic_init(&s->sequence,0);atomic_init(&s->written,0);atomic_init(&s->sampleRate,0);
    atomic_init(&s->writing,false);
}
void USSpectrumPush(USAudioSpectrum *s,const float *mono,unsigned count,unsigned rate) {
    USSpectrumPushStereo(s,mono,mono,count,rate);
}
void USSpectrumPushStereo(USAudioSpectrum *s,const float *left,const float *right,unsigned count,unsigned rate) {
    if(!s||!left||!right||!count||rate<8000||rate>384000)return;
    if(atomic_exchange_explicit(&s->writing,true,memory_order_acquire))return;
    atomic_fetch_add_explicit(&s->sequence,1,memory_order_acq_rel);
    uint64_t written=atomic_load_explicit(&s->written,memory_order_relaxed);
    unsigned first=count>USSpectrumFrames?count-USSpectrumFrames:0;
    for(unsigned i=first;i<count;i++){
        for(unsigned channel=0;channel<2;channel++){
            float input=channel?right[i]:left[i];float f=isfinite(input)?fmaxf(-1,fminf(1,input)):0;
            uint32_t bits;memcpy(&bits,&f,sizeof(bits));
            atomic_store_explicit(&s->samples[2*((written+i)%USSpectrumFrames)+channel],bits,memory_order_relaxed);
        }
    }
    atomic_store_explicit(&s->sampleRate,rate,memory_order_relaxed);
    atomic_store_explicit(&s->written,written+count,memory_order_relaxed);
    atomic_fetch_add_explicit(&s->sequence,1,memory_order_release);
    atomic_store_explicit(&s->writing,false,memory_order_release);
}
static void fft(float *real,float *imag) {
    for(unsigned i=1,j=0;i<USSpectrumFrames;i++){
        unsigned bit=USSpectrumFrames>>1;
        for(;j&bit;bit>>=1)j^=bit;
        j^=bit;
        if(i<j){float t=real[i];real[i]=real[j];real[j]=t;}
    }
    for(unsigned size=2;size<=USSpectrumFrames;size<<=1){
        float angle=-2*US_PI/(float)size,wrStep=cosf(angle),wiStep=sinf(angle);
        for(unsigned block=0;block<USSpectrumFrames;block+=size){
            float wr=1,wi=0;
            for(unsigned j=0;j<size/2;j++){
                unsigned a=block+j,b=a+size/2;
                float tr=wr*real[b]-wi*imag[b],ti=wr*imag[b]+wi*real[b];
                real[b]=real[a]-tr;imag[b]=imag[a]-ti;real[a]+=tr;imag[a]+=ti;
                float next=wr*wrStep-wi*wiStep;wi=wr*wiStep+wi*wrStep;wr=next;
            }
        }
    }
}
bool USSpectrumRead(const USAudioSpectrum *s,USSpectrumValue *out) {
    if(!s||!out)return false;
    float real[USSpectrumFrames],imag[USSpectrumFrames]={0},right[USSpectrumFrames],rightImag[USSpectrumFrames]={0};
    uint64_t written=0;unsigned rate=0;bool copied=false;
    for(unsigned attempt=0;attempt<3;attempt++){
        unsigned before=atomic_load_explicit(&s->sequence,memory_order_acquire);
        if(before&1)continue;
        written=atomic_load_explicit(&s->written,memory_order_relaxed);
        rate=atomic_load_explicit(&s->sampleRate,memory_order_relaxed);
        if(written<USSpectrumFrames||!rate)return false;
        for(unsigned i=0;i<USSpectrumFrames;i++){
            unsigned at=2*((written-USSpectrumFrames+i)%USSpectrumFrames);
            uint32_t bits=atomic_load_explicit(&s->samples[at],memory_order_relaxed);
            memcpy(&real[i],&bits,sizeof(bits));
            bits=atomic_load_explicit(&s->samples[at+1],memory_order_relaxed);memcpy(&right[i],&bits,sizeof(bits));
        }
        atomic_thread_fence(memory_order_acquire);
        if(before==atomic_load_explicit(&s->sequence,memory_order_acquire)){copied=true;break;}
    }
    if(!copied)return false;
    float sum=0,peak=0;
    for(unsigned i=0;i<USSpectrumFrames;i++){
        float a=real[i],b=right[i];sum+=(a*a+b*b)*.5f;peak=fmaxf(peak,fmaxf(fabsf(a),fabsf(b)));
        float window=.5f-.5f*cosf(2*US_PI*i/(USSpectrumFrames-1));real[i]*=window;right[i]*=window;
    }
    fft(real,imag);fft(right,rightImag);memset(out,0,sizeof(*out));
    out->rms=sqrtf(sum/USSpectrumFrames);out->peak=peak;out->written=written;out->sampleRate=rate;
    float top=fminf(20000,rate*.5f),ratio=powf(top/20,1.0f/USSpectrumBands);
    for(unsigned band=0;band<USSpectrumBands;band++){
        float lo=20*powf(ratio,(float)band),hi=lo*ratio,maxAmp=0;
        unsigned start=(unsigned)fmaxf(1,ceilf(lo*USSpectrumFrames/rate));
        unsigned end=(unsigned)fminf(USSpectrumFrames/2,ceilf(hi*USSpectrumFrames/rate));
        if(end<=start)end=start+1;
        for(unsigned k=start;k<end&&k<USSpectrumFrames/2;k++)
            maxAmp=fmaxf(maxAmp,sqrtf((real[k]*real[k]+imag[k]*imag[k]+right[k]*right[k]+rightImag[k]*rightImag[k])*.5f)*4/USSpectrumFrames);
        // dBFS -72..0 maps to 0..1. True silence stays zero.
        out->bands[band]=maxAmp>0?fmaxf(0,fminf(1,(20*log10f(maxAmp)+72)/72)):0;
    }
    return true;
}
