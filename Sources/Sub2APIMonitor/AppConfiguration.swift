import Foundation
import Sub2APIMonitorCore

@MainActor
enum AppConfiguration {
    private static let serverKey = "serverBaseURL"
    private static let selectedAccountKey = "selectedAccountID"

    // Each SecItemCopyMatching call retains ~16 KB inside Security.framework,
    // so the key is read from the Keychain once and cached for the app's lifetime.
    private static var cachedKey: String??

    static var serverURLString: String? {
        get { UserDefaults.standard.string(forKey: serverKey) }
        set { UserDefaults.standard.set(newValue, forKey: serverKey) }
    }

    static var selectedAccountID: Int? {
        get {
            let value = UserDefaults.standard.integer(forKey: selectedAccountKey)
            return value > 0 ? value : nil
        }
        set { UserDefaults.standard.set(newValue, forKey: selectedAccountKey) }
    }

    static func current() throws -> (url: URL, key: String)? {
        guard let serverURLString,
              let key = try storedKey(),
              !key.isEmpty
        else {
            return nil
        }
        return (try ServerURL.normalize(serverURLString), key)
    }

    static func save(server: String, key: String?) throws {
        let normalized = try ServerURL.normalize(server)
        if let key, !key.isEmpty {
            guard key.hasPrefix("admin-") else {
                throw NSError(
                    domain: "Sub2APIMonitor",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Admin API Key must start with admin-."]
                )
            }
            try KeychainStore.save(key)
            cachedKey = key
        } else if try storedKey() == nil {
            throw NSError(
                domain: "Sub2APIMonitor",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Enter an Admin API Key."]
            )
        }
        serverURLString = normalized.absoluteString
    }

    static func storedKey() throws -> String? {
        if let cachedKey { return cachedKey }
        let key = try KeychainStore.read()
        cachedKey = key
        return key
    }

    static func migrateLegacyConfigurationIfNeeded() {
        if serverURLString == nil {
            let path = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Sub2APIMenubar/config.json")
            if let data = try? Data(contentsOf: path),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let server = object["base_url"] as? String,
               let normalized = try? ServerURL.normalize(server)
            {
                serverURLString = normalized.absoluteString
            }
        }

        guard (try? storedKey()) == nil,
              let legacy = try? KeychainStore.read(
                  service: "co.agenticai.sub2api-menubar",
                  account: NSUserName()
              ),
              !legacy.isEmpty
        else {
            return
        }
        if (try? KeychainStore.save(legacy)) != nil {
            cachedKey = legacy
        }
    }
}
