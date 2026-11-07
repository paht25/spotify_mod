import Foundation

func check(_ condition: Bool, _ message: String) { if !condition { fatalError(message) } }
let defaults = UserDefaults.standard
let old = defaults.object(forKey: "unifiedspotify.cleanShareLinks")
defer { if let old = old { defaults.set(old, forKey: "unifiedspotify.cleanShareLinks") }
        else { defaults.removeObject(forKey: "unifiedspotify.cleanShareLinks") } }
let input = URL(string: "https://open.spotify.com/track/abc?si=tracking&utm_source=share&context=spotify%3Aalbum%3Axyz#fragment")!
defaults.set(false, forKey: "unifiedspotify.cleanShareLinks")
check(CleanShareLinks.cleanedURL(from: input) == input, "Disabled means no changes")
defaults.set(true, forKey: "unifiedspotify.cleanShareLinks")
let clean = CleanShareLinks.cleanedURL(from: input)
check(clean.absoluteString == "https://open.spotify.com/track/abc?context=spotify%3Aalbum%3Axyz#fragment", "Remove only tracking, retain context encoding and fragment")
let external = URL(string: "https://example.test/track/abc?si=keep&utm_source=keep")!
check(CleanShareLinks.cleanedURL(from: external) == external, "Do not change non-Spotify links")
let message = "Listen: \(input.absoluteString)"
check(CleanShareLinks.cleanedString(from: message) == "Listen: \(clean.absoluteString)", "Clean links inside text")
var deep = URLComponents(string: "whatsapp://send")!
deep.queryItems = [URLQueryItem(name: "text", value: message)]
let deepResult = CleanShareLinks.cleanedDeepLinkURL(deep.url!)
check(URLComponents(url: deepResult, resolvingAgainstBaseURL: false)!.queryItems!.first!.value == "Listen: \(clean.absoluteString)", "Clean nested deep links")
let original: AnyObject = input as NSURL
let pointer = USCleanSharedObject(Unmanaged.passUnretained(original).toOpaque())!
let returned = Unmanaged<AnyObject>.fromOpaque(pointer).takeRetainedValue()
check((returned as? URL) == clean, "C bridge returns the actual cleaned object with owned lifetime")
check(USCleanSharedObject(nil) == nil, "Null bridge input is accepted")
let binary = Data([0xff, 0x01, 0x80])
check(CleanShareLinks.cleanedData(binary) == binary, "Unknown binary pasteboard payload is unchanged")
print("Original Eevee share-link algorithm and ownership bridge tests passed")
