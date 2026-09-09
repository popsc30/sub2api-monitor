import Foundation

public enum Sub2APIError: LocalizedError, Sendable {
    case invalidServerURL
    case invalidResponse
    case server(status: Int, message: String)
    case api(message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Enter a valid HTTPS server URL."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .server(status, message):
            return "HTTP \(status): \(message)"
        case let .api(message):
            return message
        }
    }
}

public enum ServerURL {
    public static func normalize(_ input: String) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty
        else {
            throw Sub2APIError.invalidServerURL
        }

        let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1"
        guard scheme == "https" || (scheme == "http" && isLoopback) else {
            throw Sub2APIError.invalidServerURL
        }
        guard components.user == nil, components.password == nil else {
            throw Sub2APIError.invalidServerURL
        }

        components.scheme = scheme
        components.path = ""
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw Sub2APIError.invalidServerURL }
        return url
    }
}

public struct Sub2APIClient: Sendable {
    private let baseURL: URL
    private let adminKey: String
    private let session: URLSession

    public init(baseURL: URL, adminKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.adminKey = adminKey
        self.session = session
    }

    public func fetchSnapshot(force: Bool = false) async throws -> DashboardSnapshot {
        let accounts = try await fetchAllAccounts()
        guard !accounts.isEmpty else {
            return DashboardSnapshot(accounts: [], usage: [:], errors: [:])
        }
        let batch = try await fetchUsage(accountIDs: accounts.map(\.id), force: force)
        return DashboardSnapshot(accounts: accounts, usage: batch.usage, errors: batch.errors)
    }

    public func fetchAllAccounts() async throws -> [Account] {
        var page = 1
        var allAccounts: [Account] = []

        while true {
            var components = URLComponents(
                url: endpoint("api/v1/admin/accounts"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "page_size", value: "100"),
                URLQueryItem(name: "lite", value: "1"),
            ]
            guard let url = components?.url else { throw Sub2APIError.invalidServerURL }
            let envelope: APIEnvelope<AccountPage> = try await send(url: url)
            guard envelope.code == 0 else { throw Sub2APIError.api(message: envelope.message) }
            allAccounts.append(contentsOf: envelope.data.items)

            guard page < envelope.data.pages else { break }
            page += 1
        }

        return allAccounts.sorted { $0.id < $1.id }
    }

    public func fetchUsage(accountIDs: [Int], force: Bool) async throws -> BatchUsageData {
        var request = authorizedRequest(url: endpoint("api/v1/admin/accounts/usage/batch"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "X-Admin-UI-Request")
        request.httpBody = try JSONEncoder().encode(
            UsageRequest(accountIDs: accountIDs, force: force)
        )
        let envelope: APIEnvelope<BatchUsageData> = try await send(request: request)
        guard envelope.code == 0 else { throw Sub2APIError.api(message: envelope.message) }
        return envelope.data
    }

    private func endpoint(_ path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(adminKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Sub2APIMonitor/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func send<Value: Decodable & Sendable>(url: URL) async throws -> APIEnvelope<Value> {
        try await send(request: authorizedRequest(url: url))
    }

    private func send<Value: Decodable & Sendable>(
        request: URLRequest
    ) async throws -> APIEnvelope<Value> {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Sub2APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = Self.errorMessage(from: data) ?? HTTPURLResponse.localizedString(
                forStatusCode: httpResponse.statusCode
            )
            throw Sub2APIError.server(status: httpResponse.statusCode, message: message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(APIEnvelope<Value>.self, from: data)
        } catch {
            throw Sub2APIError.invalidResponse
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return (object["message"] as? String) ?? (object["error"] as? String)
    }
}

private struct UsageRequest: Encodable {
    let accountIDs: [Int]
    let force: Bool

    enum CodingKeys: String, CodingKey {
        case accountIDs = "account_ids"
        case force
    }
}
