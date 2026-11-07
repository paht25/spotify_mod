# Dependencies — personal-v6-9190

The integrated target uses Chroma's Logos internal generator, Objective-C ownership checks, Apple frameworks, actual vendor audio C code, adapted Eevee Swift transforms and real SwiftProtobuf 1.29.0. It does not load the original Eevee dylib or require a placeholder Orion framework.

The original Eevee binary requires Orion. The earlier Eevee IPA contains Orion declaring 1.0.2 and all 83 required export names. That establishes availability, not an exact original source commit. V6 ports selected hooks to the Objective-C registry and algorithms to C/Swift bridges; it is not a complete Orion-based Eevee rebuild. Remaining modules are explicitly incomplete.

Build: working `xcode-27` runner with iPhoneOS SDK >=27, Node.js, Python 3, GNU make, dpkg, ldid, recursive Theos checkout `8167f59de02fd32cf45b16bfcb1330dfa5c9974c`, official apple/swift-protobuf tag 1.29.0 (resolved commit recorded during build). Protobuf retains Eevee's renamed module to avoid Spotify collisions. The main image retains spotifyglass module identity for Live Activity intents.

Runtime: iOS 27 system frameworks/Swift runtime, Spotify 9.1.90 build 919002269, a signed injected image. Lyrics/artwork also depend on real network services, credentials and system media behavior. DSP file effects need imported user files. No fake provider, SDK, library or license entitlement is supplied.

Live Activity requires compiling/embedding the extension, merging host intents and valid signing. Dylibs in a Debian payload alone do not do this. Assembly embeds but does not sign.

Delivery is Sideloadly IPA injection. Rootless is a separate unvalidated packaging configuration; this Debian is not a rootless installer. Inputs and extracted originals stay untouched. Original licenses are included in source and package.
