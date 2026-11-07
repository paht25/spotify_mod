import Foundation
import EeveeSwiftProtobuf

extension UserDefaults {
    static var overwriteConfiguration: Bool {
        (standard.object(forKey: "overwriteConfiguration") as? Bool) ?? false
    }
}
final class BundleHelper {
    static let shared = BundleHelper()
    func resolveConfiguration() throws -> ResolveConfiguration {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "9.1.90"
        let name = BundledConfigurationPolicy.resourceName(for: version)
        let bytes = name == "resolveconfiguration_9_1_76" ? USConfigurationData.modern : USConfigurationData.legacy
        return try ResolveConfiguration(serializedBytes: bytes)
    }
}

enum USPremiumModule {
    static var enabled: Bool {
        if let requested = UserDefaults.standard.object(forKey: "unifiedspotify.premiumPatching") as? Bool { return requested }
        if UserDefaults.standard.bool(forKey: "spotifyglass.stock") { return false }
        // Respect an explicitly disabled legacy Eevee setting.
        return (UserDefaults.standard.object(forKey: "patchType") as? Int) != 1
    }
    static func attach(to transaction: USResponseTransaction) -> Bool {
        transaction.addTransform(owner: "eevee.account-configuration") { input, _ in
            guard enabled, let path = input.response.url?.path.lowercased() else { return nil }
            do {
                let transformed: Data
                if path.contains("/v1/bootstrap") {
                    var message = try BootstrapMessage(serializedBytes: input.data)
                    let defaults = UserDefaults.standard
                    // Preserve Eevee's first-bootstrap account detection. An
                    // explicit unified switch remains the user's override.
                    if defaults.object(forKey: "unifiedspotify.premiumPatching") == nil &&
                        defaults.integer(forKey: "patchType") == 0 {
                        if message.attributes["type"]?.stringValue == "premium" {
                            defaults.set(1, forKey: "patchType")
                            defaults.set(false, forKey: "unifiedspotify.premiumPatching")
                            return nil
                        }
                        defaults.set(2, forKey: "patchType")
                    }
                    var response = message.ucsResponse
                    try modifyRemoteConfiguration(&response)
                    message.ucsResponse = response
                    transformed = try message.serializedData()
                    defaults.set(true, forKey: "hasPatchedBootstrap")
                } else if path.contains("/v1/customize") {
                    var message = try CustomizeMessage(serializedBytes: input.data)
                    try modifyRemoteConfiguration(&message.response)
                    transformed = try message.serializedData()
                } else { return nil }
                return USResponseValue(response: input.response, data: transformed)
            } catch {
                // A schema mismatch must not turn a successful network request
                // into a failed login/bootstrap. Leave its original bytes intact.
                writeDebugLog("[Premium] Original response retained: \(error.localizedDescription)")
                return nil
            }
        }
    }
}
@_cdecl("USAttachEeveePremium")
public func USAttachEeveePremium(_ pointer: UnsafeMutableRawPointer?) -> Bool {
    guard let pointer = pointer else { return false }
    return USPremiumModule.attach(to: Unmanaged<USResponseTransaction>.fromOpaque(pointer).takeUnretainedValue())
}
