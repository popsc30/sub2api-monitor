import Foundation
import Sub2APIMonitorCore

enum AppConfiguration {
    private static let serverKey = "serverBaseURL"
    private static let selectedAccountKey = "selectedAccountID"

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
              let key = try KeychainStore.read(),
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
        } else if try KeychainStore.read() == nil {
            throw NSError(
                domain: "Sub2APIMonitor",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Enter an Admin API Key."]
            )
        }
        serverURLString = normalized.absoluteString
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

        guard (try? KeychainStore.read()) == nil,
              let legacy = try? KeychainStore.read(
                  service: "co.agenticai.sub2api-menubar",
                  account: NSUserName()
              ),
              !legacy.isEmpty
        else {
            return
        }
        try? KeychainStore.save(legacy)
    }
}
