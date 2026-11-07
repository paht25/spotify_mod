import Foundation

extension UserDefaults {
    static var cleanShareLinks: Bool {
        (standard.object(forKey: "unifiedspotify.cleanShareLinks") as? Bool)
            ?? (standard.object(forKey: "cleanShareLinks") as? Bool) ?? false
    }
}

// Return a +1 object to the ARC caller; no autorelease/lifetime guessing at
// the Swift-C boundary. NSURL/NSString/Data and pasteboard item arrays use the
// real Eevee algorithms, while unknown values remain unchanged.
@_cdecl("USCleanSharedObject")
public func USCleanSharedObject(_ pointer: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    guard let pointer = pointer else { return nil }
    let object = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    let result: Any
    if let items = object as? [[String: Any]] {
        result = CleanShareLinks.cleanPasteboardItems(items)
    } else {
        result = CleanShareLinks.cleanedValue(object)
    }
    return Unmanaged.passRetained(result as AnyObject).toOpaque()
}
@_cdecl("USCleanDeepLink")
public func USCleanDeepLink(_ pointer: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    guard let pointer = pointer else { return nil }
    let object = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    let result: AnyObject
    if let url = object as? URL { result = CleanShareLinks.cleanedDeepLinkURL(url) as NSURL }
    else { result = object }
    return Unmanaged.passRetained(result).toOpaque()
}
