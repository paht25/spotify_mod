import Foundation

enum CleanShareLinks {
    private static let spotifyShareURLPattern = #"https?://(?:[a-z0-9-]+\.)*open\.spotify\.com/[^\s"<>]+"#
    private static let spotifyShareURLRegex = try! NSRegularExpression(
        pattern: spotifyShareURLPattern,
        options: [.caseInsensitive]
    )

    /// Returns a copy of the URL with Spotify's `si` tracking parameter
    /// (and any `utm_*` marketing parameters) removed.
    static func cleanedURL(from url: URL) -> URL {
        guard UserDefaults.cleanShareLinks,
              let host = url.host?.lowercased(),
              host == "open.spotify.com" || host.hasSuffix(".open.spotify.com"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.percentEncodedQueryItems, !items.isEmpty
        else {
            return url
        }

        // percentEncodedQueryItems preserves the original query encoding
        // (e.g. `context=spotify%3Aalbum%3A...`) instead of re-encoding it.
        let cleanedItems = items.filter { item in
            let name = item.name.lowercased()
            return name != "si" && !name.hasPrefix("utm_")
        }

        guard cleanedItems.count != items.count else { return url }

        components.percentEncodedQueryItems = cleanedItems.isEmpty ? nil : cleanedItems
        return components.url ?? url
    }

    /// Returns a copy of the string with any Spotify share links cleaned.
    static func cleanedString(from string: String) -> String {
        guard UserDefaults.cleanShareLinks else { return string }

        let nsString = string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        var replacements: [(NSRange, String)] = []

        for match in spotifyShareURLRegex.matches(in: string, options: [], range: fullRange) {
            let urlString = nsString.substring(with: match.range)
            guard let url = URL(string: urlString) else { continue }

            let cleanedURLString = cleanedURL(from: url).absoluteString
            if cleanedURLString != urlString {
                replacements.append((match.range, cleanedURLString))
            }
        }

        guard !replacements.isEmpty else { return string }

        var result = string
        for (range, replacement) in replacements.reversed() {
            result = (result as NSString).replacingCharacters(in: range, with: replacement)
        }
        return result
    }

    static func cleanedActivityItem(_ item: Any) -> Any {
        if let url = item as? URL {
            return cleanedURL(from: url)
        }
        if let string = item as? String {
            return cleanedString(from: string)
        }
        return item
    }

    // MARK: - Deep link cleaning

    /// Returns a copy of the URL being opened by the system with any Spotify share
    /// links embedded in it cleaned of tracking parameters.
    ///
    /// The in-app share sheet's direct-destination buttons (Instagram Stories,
    /// WhatsApp, Telegram, Messenger, …) hand the Spotify share URL to another app
    /// through a deep link instead of the pasteboard or the share sheet, e.g.
    ///
    ///     whatsapp://send?text=...https://open.spotify.com/track/...?si=...
    ///     instagram-stories://share?source_application=...&content_url=...%3Fsi%3D...
    ///
    /// Hooking `UIApplication.openURL` lets us clean the Spotify URL right before
    /// it leaves the process.
    static func cleanedDeepLinkURL(_ url: URL) -> URL {
        guard UserDefaults.cleanShareLinks else { return url }

        // The URL being opened is itself a Spotify share link.
        if let host = url.host?.lowercased(),
           host == "open.spotify.com" || host.hasSuffix(".open.spotify.com") {
            return cleanedURL(from: url)
        }

        // Clean Spotify URLs embedded in query-item values. URLComponents
        // percent-decodes each value, so the regex can find the plain
        // `https://...?si=...` form; assigning back re-encodes the values.
        // Note: only the changed values trigger a rebuild, and receivers like
        // WhatsApp/Instagram decode query strings leniently, so the re-encoding
        // of untouched items (`+` -> `%20`, `%3F` -> `?`) is semantically safe.
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = components.queryItems, !items.isEmpty {
            var changed = false
            let cleanedItems = items.map { item -> URLQueryItem in
                guard let value = item.value else { return item }
                let cleaned = cleanedString(from: value)
                if cleaned != value { changed = true }
                return URLQueryItem(name: item.name, value: cleaned)
            }
            if changed {
                components.queryItems = cleanedItems
                if let rebuilt = components.url {
                    return rebuilt
                }
            }
        }

        // Fallback for payloads URLComponents can't parse (e.g. a raw, unencoded
        // Spotify URL in the query): clean any Spotify URLs in the raw string.
        let raw = url.absoluteString
        let cleanedRaw = cleanedString(from: raw)
        return cleanedRaw == raw ? url : (URL(string: cleanedRaw) ?? url)
    }

    // MARK: - Pasteboard value cleaning

    static func cleanPasteboardItems(_ items: [[String: Any]]) -> [[String: Any]] {
        items.map { item in
            item.mapValues { value in cleanedValue(value) }
        }
    }

    static func cleanedValue(_ value: Any) -> Any {
        if let url = value as? URL {
            return cleanedURL(from: url)
        }
        if let string = value as? String {
            return cleanedString(from: string)
        }
        if let data = value as? Data {
            return cleanedData(data) ?? data
        }
        if let urls = value as? [URL] {
            return urls.map { cleanedURL(from: $0) }
        }
        if let strings = value as? [String] {
            return strings.map { cleanedString(from: $0) }
        }
        return value
    }

    /// Cleans pasteboard data written through `setData:forPasteboardType:`.
    ///
    /// Handles both representations of a URL pasteboard type:
    /// 1. The raw URL string (UTF-8), used by `public.utf8-plain-text` and `public.url`.
    /// 2. A keyed-archived `NSURL` object.
    static func cleanedData(_ data: Data?) -> Data? {
        guard let data = data else { return nil }

        // Plain-text representation.
        if let string = String(data: data, encoding: .utf8) {
            let cleaned = cleanedString(from: string)
            return cleaned == string ? data : cleaned.data(using: .utf8)
        }

        // Keyed-archived NSURL.
        if let url = unarchiveURL(from: data) {
            let cleaned = cleanedURL(from: url)
            if cleaned != url {
                // Prefer a secure-coded archive so consumers that unarchive with
                // `requiringSecureCoding: true` still succeed.
                if let rearchived = try? NSKeyedArchiver.archivedData(
                    withRootObject: cleaned as NSURL,
                    requiringSecureCoding: true
                ) {
                    return rearchived
                }
                if let rearchived = try? NSKeyedArchiver.archivedData(
                    withRootObject: cleaned as NSURL,
                    requiringSecureCoding: false
                ) {
                    return rearchived
                }
            }
        }

        return data
    }

    private static func unarchiveURL(from data: Data) -> URL? {
        if let url = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: data) {
            return url as URL
        }
        if let object = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data),
           let url = object as? URL {
            return url
        }
        return nil
    }
}


