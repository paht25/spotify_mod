# Source provenance

- `Sources/Chroma/Wire/Protobuf.h` and `.m` are copied unchanged from Chroma v0.51.0, commit `425d68bc1761e90a6b5828864720511bcef79fa9`, `tweak/Sources/Shared/Lyrics/`. Copyright and original terms remain with upstream. Separate integration permission was confirmed by the user for private testing; no public redistribution right is inferred.
- `Sources/Eevee/Feed/BrowsitaSectionStripper.swift` and `Tests/EeveeFeed/main.swift` are copied unchanged from EeveeSpotify v7.0.0, commit `d1da1d69715935e41d1dc97a25d11bcc42ebd170`, `Sources/EeveeSpotify/Premium/Helpers/` and `Tests/BrowsitaSectionStripper/`. See `EeveeSpotify-GPL-3.0.txt` and the upstream repository for authorship/history.
- The upstream feed test includes a no-op diagnostic function for its test executable only. Production uses the real NSLog diagnostic function in `USEeveeFeedModule.swift`.
- Core/Transport code and the adapter are newly authored integration work. Source notices are retained; this test kit is not a public combined distribution or a claim of resolved combined licensing.
