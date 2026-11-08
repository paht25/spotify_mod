# Personal local assets

Only locally imported files are supported. No Chroma Workshop item, account entitlement or proprietary backend is impersonated. Files keep a unique internal filename; the library presents their original readable stem. Import never overwrites another asset. Apply and delete are explicit actions. Audio/preset/font import does not download music.

## Audio preset JSON

```json
{
  "schema": "personal.audio-preset.v1",
  "values": {
    "postGain": -3,
    "bass": true,
    "bassGain": 4,
    "wide": false,
    "width": 60,
    "tube": false,
    "tubeDrive": 2,
    "equalizer": [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
  }
}
```

This is an overlay of explicitly supplied DSP settings, not a reset of unspecified effects. Gain ranges match the existing DSP setters: postGain -12..12 dB, bassGain 1..15 dB, width 0..100, tubeDrive 0..18 dB, EQ exactly 15 finite gains in ±12 dB. Switches are JSON booleans, not numbers. Unknown setting keys are rejected, so a preset cannot change account/network settings. Applying enables the real DSP engine.

## Headphone correction

Import UTF-8 `.txt` containing `GraphicEQ: 20 -2; 100 0; 1000 1; 20000 -3`. Supports 1–512 frequency/gain points, strictly increasing frequencies 20–20000 Hz, gains ±24 dB, and an optional trailing semicolon. Apply passes the validated curve to the existing GraphicEQ engine. A remote AutoEq catalogue/browser is not supplied by this importer.

## Fonts

Import a valid `.ttf` or `.otf`, at most 8 MiB. CoreText validates/registers the file. Apply selects its first font face for supported UIFont system-font creation APIs; restart for existing labels. Embedded icon fonts, bitmaps and custom-font APIs keep their original fonts. Use system font clears the override. This is not a claim that every Spotify text renderer is replaced.

## Metal shaders

Import UTF-8 `.metal`, at most 256 KiB. The renderer compiles on a worker queue and displays the error in Shader status; malformed entry points restore the built-in renderer. Asset names/ABIs from other apps are not assumed compatible.

Provide these types and functions, matching the generated built-in shader in `build/generated/PersonalSpectrum.metal`:

```metal
#include <metal_stdlib>
using namespace metal;
struct U {
  float2 size; float time; float energy; float bands[32];
  uint style; float gain; float2 padding;
};
struct V { float4 position [[position]]; float2 uv; };
vertex V us_vertex(uint i [[vertex_id]]);
fragment float4 us_fragment(V v [[stage_in]], constant U &u [[buffer(0)]]);
```

`size` is drawable pixels; `time` is visual time and holds at zero under Reduce Motion; `energy` is real RMS; bands are actual log-frequency FFT levels. The built-in renderer fades absent/stopped input rather than inventing a beat. Shader compilation and GPU output still need Apple/device validation for this branch.

## Web Display

`WebDisplay.html` is an independently authored local client embedded by the IPA assembler. It reads `/state` and optionally posts `/command` using a per-start bearer capability supplied in the link fragment. It sends no Spotify credentials, headers, audio or tokens to an external service. The phone listener binds a private Wi-Fi IPv4 address, uses HTTP locally, serves no arbitrary files, rejects duplicate/oversize/pipelined requests, limits connections/command frequency and invalidates old links when stopped. Internet relay, client-side visualizer shader transport and remote community content are not implemented.
