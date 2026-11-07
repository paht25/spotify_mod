# Dependency and target findings

Update after supplied IPA inspection: the Eevee 7.0.0 / Spotify 9.1.88 IPA includes an Orion framework declaring 1.0.2, EeveeSwiftProtobuf declaring 1.29.0 and an ElleKit 1.1.3 compatibility framework. All 83 required Orion export names are available in its export trie. See `ipa-analysis/README.vi.md` and JSON reports. This resolves availability for that supplied IPA, not source-commit identity or all runtime compatibility. The current target is 9.1.88/iOS 27 and the user also supplied a NoEevee base, which is preferred. Historical payload-only findings below remain accurate for the original extracted directories.

## Binary facts

`binary/mach-o.json` contains each thin Mach-O slice, its dependencies, runpaths and undefined symbol names with library ordinals. This is a reproducible record rather than a guessed dependency list.

| Input | Architecture | Mach-O minimum OS | SDK recorded by build |
|---|---|---|---|
| Chroma spotifyglass.dylib | arm64 | 16.0 | 27.0 |
| EeveeSpotify.dylib | arm64 | 14.0 | 26.2 |
| EeveeSwiftProtobuf | arm64 and arm64e | 14.0 | 26.2 |

These values do not prove compatibility on iOS 27. EeveeSpotify's source package control file requires firmware >=16.1, despite the binary deployment target of 14.0. Chroma's source guidance also distinguishes the host application's OS floor from its own compiler deployment target. Actual availability of Spotify 9.1.90 APIs on the requested device must be established.

## Orion

EeveeSpotify loads `@rpath/Orion.framework/Orion` with current and compatibility version fields both set to 1.0.0. This is a dylib ABI version field, not proof that Orion release 1.0.0 rather than 1.0.2 was used. The exact original runtime release and build commit cannot be established from that field.

Its required imports include ClassHook glue, AnyHook/HookGroup metadata, DefaultGroup, OrionHookError, and generated hook activation APIs. All imports and their weak/required flags are listed in `binary/mach-o.json`. The ordinal-based dependency extraction identifies 83 imports attributed to Orion in this binary. No Orion framework is present in either input. A stub library would fail to provide the real generated glue and hook behavior and is not supplied.

The official source is available at [theos/orion](https://github.com/theos/orion). The checked-out source's control file advertises 1.0.2 and a mobilesubstrate dependency; it is MIT licensed. That establishes an official implementation route, not that it has been built or proven ABI-compatible here. Its Makefile selects subpackages by OS range and Swift toolchain; its iOS 14 subpackage range in this checkout ends below 26. Do not assume that unmodified package metadata is suitable for the requested iOS 27 device. Review the runtime and loader against that environment before changing ranges or selecting a package.

EeveeSpotify's source uses Theos's `${ORION}` dependency substitution. Its workflow checks out a moving Theos revision rather than pinning an exact Orion commit, so that workflow does not settle the original runtime version. For an existing binary, compare all required symbol exports, architecture, Swift ABI/toolchain and loader backend against a real candidate framework, then test activation on device. Rebuilding the unified source and Orion against a pinned matching toolchain is preferable once integration is permitted.

## Other dependencies

- EeveeSwiftProtobuf is present. The versioned Eevee source builds apple/swift-protobuf 1.29.0 with the module renamed to EeveeSwiftProtobuf to avoid Objective-C/Swift class-name collisions with Spotify's bundled protobuf implementation. Preserve this module identity. The payload's Swift module files and bundle metadata are available for comparison; the original build has not been reproduced.
- Eevee source links libroot for rootless, and libroothide only for its distinct RootHide configuration. The supplied dylib's direct load commands do not name a separate libroot dylib; do not infer a new direct dynamic dependency solely from a source linker flag. Transitive/runtime requirements still need validation.
- Chroma's source uses the Logos internal generator, runtime swizzling and a static audio library assembled from its vendor audio dependencies. It also has an optional Live Activity extension outside the dylib tree. That extension is absent from the supplied extracted payloads, so standalone dylib preservation cannot establish all extension workflows.
- Eevee's Metal shader, application support bundle, localized settings and configuration snapshots are present. Source rebuilds use Xcode's Metal compiler. Existing source comments explicitly flag the shader staging rule as untested; the presence of a supplied metallib does not test that source rule.
- System Apple frameworks and Swift libraries must be provided by iOS. Chroma also uses network-based lyrics services; availability, credentials and API behavior require live validation. Secrets or signing material are not included in this project.

## Rootless plan and baseline build procedure

The requested packaging scheme is rootless, using Theos `THEOS_PACKAGE_SCHEME=rootless`, with a candidate package architecture `iphoneos-arm64`. It must stage resources under the rootless prefix once, not combine a rootful `/Library` tree and `/var/jb/Library` tree by path rewriting. Chroma's original install ID is `/Library/MobileSubstrate/DynamicLibraries/spotifyglass.dylib`; Eevee uses @rpath and has `/var/jb/Library/Frameworks`, `/var/jb/usr/lib` plus RootHide-relative fallback runpaths. These are different loading assumptions that need source-level replacement by one path service.

For the unmodified Eevee baseline only, a macOS machine with Xcode, iPhoneOS SDK, Theos and Orion build dependencies can follow its checked-in build workflow: initialize the required Theos submodules, install make/dpkg/ldid, set THEOS and THEOS_PACKAGE_SCHEME=rootless, run `make build-eeveeswiftprotobuf`, then `make package FINALPACKAGE=1`. Inspect the scripts first: the dependency builder writes into THEOS and temporary build directories. This sequence has not been run here and does not build Chroma or a unified implementation.

There is no valid installation command for a unified package yet. Required remaining inputs: exact jailbreak and loader on the stated OS, a compatible build environment, a lawfully available Spotify 9.1.90 runtime/class surface, Chroma integration permission, and a target device for testing. No package manager action or device modification has been attempted.
