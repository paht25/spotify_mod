#include "USAudioSpectrum.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#endif
#define PI 3.14159265358979323846
static void tone(unsigned rate,float frequency) {
    USAudioSpectrum meter;USSpectrumInitialize(&meter);USSpectrumValue v;
    float input[4096];
    for(unsigned i=0;i<4096;i++)input[i]=.5f*sinf((float)(2*PI*frequency*i/rate));
    for(unsigned i=0;i<4096;i+=256)USSpectrumPush(&meter,input+i,256,rate);
    assert(USSpectrumRead(&meter,&v));assert(v.written==4096&&v.sampleRate==rate);
    assert(fabsf(v.rms-.353553f)<.02f && v.peak<=.501f);
    unsigned peak=0;for(unsigned i=0;i<USSpectrumBands;i++)if(v.bands[i]>v.bands[peak])peak=i;
    float ratio=powf(fminf(20000,rate*.5f)/20,1.f/USSpectrumBands);
    float lower=20*powf(ratio,(float)peak),upper=lower*ratio;
    assert(frequency>=lower-rate/(float)USSpectrumFrames && frequency<=upper+rate/(float)USSpectrumFrames);
}
typedef struct {USAudioSpectrum meter;atomic_bool done;} Concurrent;
#ifdef _WIN32
static DWORD WINAPI produce(LPVOID data) {
#else
static void *produce(void *data) {
#endif
    Concurrent *state=data;float samples[128];
    for(unsigned block=0;block<4000;block++){
        for(unsigned i=0;i<128;i++)samples[i]=.5f*sinf((float)(2*PI*1000*(block*128+i)/48000));
        USSpectrumPush(&state->meter,samples,128,48000);
    }
    atomic_store(&state->done,true);return 0;
}
static void concurrent(void) {
    Concurrent state;USSpectrumInitialize(&state.meter);atomic_init(&state.done,false);
#ifdef _WIN32
    HANDLE thread=CreateThread(NULL,0,produce,&state,0,NULL);assert(thread);
#else
    pthread_t thread;assert(!pthread_create(&thread,NULL,produce,&state));
#endif
    uint64_t previous=0;
    while(!atomic_load(&state.done)){
        USSpectrumValue value;
        if(USSpectrumRead(&state.meter,&value)){
            assert(value.written>=previous&&value.sampleRate==48000&&isfinite(value.rms)&&value.peak<=1);
            previous=value.written;
        }
    }
#ifdef _WIN32
    assert(WaitForSingleObject(thread,INFINITE)==WAIT_OBJECT_0);CloseHandle(thread);
#else
    assert(!pthread_join(thread,NULL));
#endif
    USSpectrumValue value;assert(USSpectrumRead(&state.meter,&value)&&value.written==4000*128);
}
int main(void) {
    USAudioSpectrum *s=calloc(1,sizeof(*s));assert(s);USSpectrumInitialize(s);
    USSpectrumValue v;float silence[4096]={0};
    assert(!USSpectrumRead(s,&v));
    USSpectrumPush(s,silence,4096,48000);assert(USSpectrumRead(s,&v));
    assert(v.rms==0&&v.peak==0);for(unsigned i=0;i<USSpectrumBands;i++)assert(v.bands[i]==0);
    USSpectrumPush(s,silence,100,1);assert(USSpectrumRead(s,&v)&&v.written==4096);
    float invalid[4096];for(unsigned i=0;i<4096;i++)invalid[i]=(i%2)?NAN:INFINITY;
    USSpectrumPush(s,invalid,4096,44100);assert(USSpectrumRead(s,&v)&&isfinite(v.rms)&&v.rms==0);
    for(unsigned i=0;i<4096;i++)invalid[i]=5;
    USSpectrumPush(s,invalid,4096,44100);assert(USSpectrumRead(s,&v)&&v.peak==1);
    free(s);
    tone(44100,1000);tone(48000,80);tone(48000,4000);tone(96000,15000);
    concurrent();
    USAudioSpectrum stereo;USSpectrumInitialize(&stereo);float left[2048],right[2048];
    for(unsigned i=0;i<2048;i++){left[i]=.5f*sinf((float)(2*PI*1000*i/48000));right[i]=-left[i];}
    USSpectrumPushStereo(&stereo,left,right,2048,48000);assert(USSpectrumRead(&stereo,&v)&&v.rms>.3f);
    float loudest=0;for(unsigned i=0;i<32;i++)loudest=fmaxf(loudest,v.bands[i]);assert(loudest>.7f);
    puts("PASS: production spectrum silence, tones, RMS, clipping, nonfinite, wrap, sample rate, concurrency and antiphase stereo");
    return 0;
}
