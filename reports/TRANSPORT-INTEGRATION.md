# Transport milestone

## Implemented code

- `USResponseTransaction` buffers a single response, registers ordered named transformers, rejects duplicate owners and accepts completion once. It performs transforms asynchronously on an explicit work queue, then delivers on the adapter's chosen queue. Network cancellation/error skips transformations. A transformer error rolls back the whole transform chain to the original response/body and propagates the error. Successful rewrites normalize content length and remove stale wire compression/transfer headers. Empty responses still complete.
- Actual Chroma `Protobuf.h/.m` is now part of the iOS archive, copied unchanged with provenance and license notices. Tests exercise its real parse/serialize functions and unknown fields.
- Actual Eevee `BrowsitaSectionStripper.swift` is copied unchanged. `USEeveeFeedModule.attach` registers that algorithm in the shared transaction, with real diagnostic logging. Its original regression suite and a new pipeline integration test are included.

These are implemented components, not a finished Spotify tweak. The upstream reference checkouts and original extracted payloads remain untouched.

## Evidence and limits

The user screenshot confirms the PREVIOUS core-only workflow passed macOS tests, ARM64 iOS compilation and artifact upload. Exact SDK/toolchain versions were not visible in the screenshot. That result does not validate these NEW transport/module changes. New scripts have local Bash syntax validation only; Apple compilation and execution must run in the updated cloud job.

There is no installed Spotify hook adapter yet. The transaction must be attached to actual task identity, not integer task ID alone. Delegate response disposition, redirects, intermediate responses, cached 304 synthesis, asynchronous lyrics provider results, request rewriting/donor tracks and stream-size limits are not implemented by this class. It deliberately does not claim completion of those original behaviors. Buffering is intended for selected transformable responses, not media streams; a bounded passthrough policy is still required before production activation. It is not safe to route all Spotify network traffic through it indiscriminately.

Other original feature families, unified settings UI, single hook registration, dependency staging and `.deb` generation remain incomplete. No injectable dylib/package is produced at this milestone.

## Updated cloud job

The new kit must replace `Sources`, `Tests`, `scripts`, `.github/workflows/build-core.yml` and include `Licenses` in the private repository. Run the workflow. It now builds the shared transaction and original wire/feed code, runs the original Eevee regression suite, and executes the actual Eevee-transform-to-transaction integration test. The final artifact remains a static integration archive, not a Sideloadly input.
