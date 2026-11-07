import Foundation
import EeveeSwiftProtobuf

func check(_ condition: Bool, _ message: String) { if !condition { fatalError(message) } }
let defaults = UserDefaults.standard
let oldEnabled = defaults.object(forKey: "unifiedspotify.premiumPatching")
let oldOverwrite = defaults.object(forKey: "overwriteConfiguration")
let oldPatchType = defaults.object(forKey: "patchType")
let oldPatched = defaults.object(forKey: "hasPatchedBootstrap")
defer {
    if let oldEnabled = oldEnabled { defaults.set(oldEnabled, forKey: "unifiedspotify.premiumPatching") }
    else { defaults.removeObject(forKey: "unifiedspotify.premiumPatching") }
    if let oldOverwrite = oldOverwrite { defaults.set(oldOverwrite, forKey: "overwriteConfiguration") }
    else { defaults.removeObject(forKey: "overwriteConfiguration") }
    if let oldPatchType = oldPatchType { defaults.set(oldPatchType, forKey: "patchType") }
    else { defaults.removeObject(forKey: "patchType") }
    if let oldPatched = oldPatched { defaults.set(oldPatched, forKey: "hasPatchedBootstrap") }
    else { defaults.removeObject(forKey: "hasPatchedBootstrap") }
}
defaults.set(true, forKey: "unifiedspotify.premiumPatching")
defaults.set(false, forKey: "overwriteConfiguration")
var configuration = UcsResponse()
configuration.attributes.accountAttributes["ads"] = AccountAttribute.with { $0.boolValue = true }
configuration.attributes.accountAttributes["offline"] = AccountAttribute.with { $0.boolValue = false }
configuration.attributes.accountAttributes["custom-preserved"] = AccountAttribute.with { $0.stringValue = "original" }
var bootstrap = BootstrapMessage(); bootstrap.ucsResponse = configuration
let original = try bootstrap.serializedData()

func transformed(_ data: Data, path: String) -> Data {
    let response = HTTPURLResponse(url: URL(string: "https://spclient.wg.spotify.com\(path)")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
    let transaction = USResponseTransaction(response: response)
    check(USPremiumModule.attach(to: transaction), "Attach real original configuration algorithm")
    _ = transaction.append(data)
    let done = DispatchSemaphore(value: 0)
    var output = Data()
    check(transaction.finish(error: nil, workQueue: .global(), deliveryQueue: DispatchQueue(label: "premium.test")) { value, issue in
        check(issue == nil, "Do not inject network errors on schema mismatch")
        output = value.data; done.signal()
    }, "Finish transaction")
    check(done.wait(timeout: .now() + 10) == .success, "Configuration transformation completes")
    return output
}
let changed = transformed(original, path: "/v1/bootstrap")
let result = try BootstrapMessage(serializedBytes: changed)
check(result.attributes["ads"]?.boolValue == false, "Original Eevee account ad attribute transform runs")
check(result.attributes["offline"]?.boolValue == false, "Real server entitlements are retained")
check(result.attributes["custom-preserved"]?.stringValue == "original", "Unrelated account attributes remain")
var customize = CustomizeMessage(); customize.response = configuration
let customizeResult = try CustomizeMessage(serializedBytes: transformed(try customize.serializedData(), path: "/v1/customize"))
check(customizeResult.response.attributes.accountAttributes["ads"]?.boolValue == false, "Customize uses the same implementation")
defaults.set(false, forKey: "unifiedspotify.premiumPatching")
check(transformed(original, path: "/v1/bootstrap") == original, "Disabled patching retains original bytes")
defaults.set(true, forKey: "unifiedspotify.premiumPatching")
let invalid = Data([0xff, 0xff, 0xff])
check(transformed(invalid, path: "/v1/bootstrap") == invalid, "Malformed responses pass through intact")
defaults.set(true, forKey: "overwriteConfiguration")
let snapshot = try BundleHelper.shared.resolveConfiguration()
check(!snapshot.assignedValues.isEmpty, "Original modern configuration snapshot decodes")
_ = transformed(original, path: "/v1/bootstrap")
defaults.removeObject(forKey: "unifiedspotify.premiumPatching")
defaults.removeObject(forKey: "patchType")
var paid = bootstrap
paid.attributes["type"] = AccountAttribute.with { $0.stringValue = "premium" }
let paidBytes = try paid.serializedData()
check(transformed(paidBytes, path: "/v1/bootstrap") == paidBytes, "First bootstrap for a paid account is retained")
check(defaults.integer(forKey: "patchType") == 1 && !USPremiumModule.enabled, "Paid account auto-detection disables patching")
print("Original Eevee configuration transforms, real protobuf runtime and snapshots passed; server behavior is not tested")
