import Foundation

// Uses the real upstream feed protobuf transformer. No service response is
// fabricated here; a nil transformation retains the existing bytes.
func writeDebugLog(_ message: String) {
    NSLog("[UnifiedSpotify][EeveeFeed] %@", message)
}

@objc public final class USEeveeFeedModule: NSObject {
    @objc public static func attach(to transaction: USResponseTransaction) -> Bool {
        transaction.addTransform(owner: "eevee.feed-sections") { input, _ in
            guard let url = input.response.url,
                  BrowsitaSectionStripper.shouldHandle(url),
                  let changed = BrowsitaSectionStripper.strip(input.data, url: url) else {
                return nil
            }
            return USResponseValue(response: input.response, data: changed)
        }
    }
}
