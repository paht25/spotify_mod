import Foundation

// A direct C entry point avoids depending on Swift's native class symbols or
// runtime class discovery. The caller retains the object through this call;
// attach stores its transform in the transaction and does not consume ownership.
@_cdecl("USAttachEeveeFeed")
public func USAttachEeveeFeed(_ pointer: UnsafeMutableRawPointer?) -> Bool {
    guard let pointer = pointer else { return false }
    let transaction = Unmanaged<USResponseTransaction>.fromOpaque(pointer).takeUnretainedValue()
    return USEeveeFeedModule.attach(to: transaction)
}

// Uses the real upstream feed protobuf transformer. No service response is
// fabricated here; a nil transformation retains the existing bytes.
func writeDebugLog(_ message: String) {
    NSLog("[UnifiedSpotify][EeveeFeed] %@", message)
}

// The Objective-C hook references this class by its unmangled runtime name.
// An explicit @objc name makes that symbol stable across Swift module names.
@objc(USEeveeFeedModule) public final class USEeveeFeedModule: NSObject {
    @objc(attachTo:) public static func attach(to transaction: USResponseTransaction) -> Bool {
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
