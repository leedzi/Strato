import Foundation
import GoogleMaps3D
import Observation
import Security

/// Device-local access to the optional Google scene. Keys never enter app settings or exports.
@MainActor
@Observable
final class GoogleSceneAccess {
    static let shared = GoogleSceneAccess()

    private static var sdkConfigured = false
    private static let enabledPreference = "strato.google3d.enabled"
    private static let keychainService = "com.strato.focus.google3d"
    private static let keychainAccount = "api-key"

    @ObservationIgnored private let defaults: UserDefaults

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledPreference) }
    }
    private(set) var isConfigured = false
    private(set) var requiresRestart = false

    var canOpenScene: Bool { isEnabled && isConfigured && !requiresRestart }

    private init() {
        defaults = .standard
        isEnabled = defaults.bool(forKey: Self.enabledPreference)
        isConfigured = key() != nil
    }

    func refreshConfiguration() {
        isConfigured = key() != nil
    }

    func key() -> String? {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else { return nil }
        return value
    }

    func saveKey(_ input: String) throws {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= 256,
              !value.contains(where: { $0.isWhitespace }) else {
            throw AccessError.invalidKey
        }
        let previous = key()
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemUpdate(keychainQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = keychainQuery
            item.merge(attributes) { _, new in new }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw AccessError.cannotSave }
        isConfigured = true
        if Self.sdkConfigured && previous != value { requiresRestart = true }
    }

    func clearKey() throws {
        let status = SecItemDelete(keychainQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AccessError.cannotRemove
        }
        isConfigured = false
        isEnabled = false
        if Self.sdkConfigured { requiresRestart = true }
    }

    /// Call only after the user opens an allowed scene. The SDK receives a key once per process.
    func prepareMap() -> Bool {
        guard canOpenScene, let value = key() else {
            refreshConfiguration()
            return false
        }
        if !Self.sdkConfigured {
            GoogleMaps3D.Map.apiKey = value
            Self.sdkConfigured = true
        }
        return true
    }

    private var keychainQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecAttrSynchronizable as String: false
        ]
    }

    enum AccessError: LocalizedError {
        case invalidKey, cannotSave, cannotRemove

        var errorDescription: String? {
            switch self {
            case .invalidKey: return "请输入完整的 Google API key，内容中不能包含空格或换行。"
            case .cannotSave: return "暂时无法保存密钥，请解锁设备后再试。"
            case .cannotRemove: return "暂时无法移除密钥，请解锁设备后再试。"
            }
        }
    }
}
