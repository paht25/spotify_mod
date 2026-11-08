#ifndef US_AUDIO_SPECTRUM_H
#define US_AUDIO_SPECTRUM_H
#include <stdbool.h>
#include <stdint.h>
#include <stdatomic.h>
enum { USSpectrumFrames=2048, USSpectrumBands=32 };
typedef struct {
    atomic_uint samples[USSpectrumFrames*2];
    atomic_uint sequence;
    atomic_uint_fast64_t written;
    atomic_uint sampleRate;
    atomic_bool writing;
} USAudioSpectrum;
typedef struct {
    float bands[USSpectrumBands];
    float rms,peak;
    uint64_t written;
    unsigned sampleRate;
} USSpectrumValue;
void USSpectrumInitialize(USAudioSpectrum *s);
// Real audio thread: bounded, no allocation, locks, FFT, I/O or Objective-C.
void USSpectrumPush(USAudioSpectrum *s,const float *mono,unsigned count,unsigned sampleRate);
void USSpectrumPushStereo(USAudioSpectrum *s,const float *left,const float *right,unsigned count,unsigned sampleRate);
// Consumer thread: compute a Hann-windowed FFT from a consistent atomic snapshot.
bool USSpectrumRead(const USAudioSpectrum *s,USSpectrumValue *value);
#endif
