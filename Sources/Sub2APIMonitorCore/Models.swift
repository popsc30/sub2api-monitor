import Foundation

public struct APIEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    public let code: Int
    public let message: String
    public let data: Value
}

public struct AccountPage: Decodable, Sendable {
    public let items: [Account]
    public let page: Int
    public let pageSize: Int
    public let pages: Int
    public let total: Int
}

public struct Account: Decodable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let platform: String?
    public let type: String?
    public let status: String?

    public var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Account \(id)"
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BatchUsageData: Decodable, Sendable {
    public let usage: [String: AccountUsage]
    public let errors: [String: String]
}

public struct AccountUsage: Decodable, Sendable {
    public let updatedAt: String?
    public let fiveHour: UsageWindow?
    public let sevenDay: UsageWindow?
}

public struct UsageWindow: Decodable, Sendable {
    public let utilization: Double?
    public let resetsAt: String?
    public let remainingSeconds: Int?
    public let windowStats: WindowStats?
}

public struct WindowStats: Decodable, Sendable {
    public let requests: Int?
    public let tokens: Int64?
    public let cost: Double?
    public let userCost: Double?

    public var displayedCost: Double? { userCost ?? cost }
}

public struct DashboardSnapshot: Sendable {
    public let accounts: [Account]
    public let usage: [String: AccountUsage]
    public let errors: [String: String]

    public init(
        accounts: [Account],
        usage: [String: AccountUsage],
        errors: [String: String]
    ) {
        self.accounts = accounts
        self.usage = usage
        self.errors = errors
    }
}
