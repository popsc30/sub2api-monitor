import Foundation

public enum UsageFormatter {
    public static func percent(_ value: Double?) -> Int? {
        guard let value, value.isFinite else { return nil }
        return max(0, min(100, Int(value.rounded())))
    }

    public static func percentText(_ value: Double?) -> String {
        percent(value).map { "\($0)%" } ?? "--%"
    }

    public static func duration(seconds: Int?) -> String {
        guard let seconds else { return "unknown" }
        let remaining = max(0, seconds)
        guard remaining > 0 else { return "reset now" }
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let minutes = (remaining % 3_600) / 60
        if days > 0 { return "resets in \(days)d \(hours)h" }
        if hours > 0 { return "resets in \(hours)h \(minutes)m" }
        return "resets in \(max(1, minutes))m"
    }

    public static func compact(_ value: Int64?) -> String {
        guard let value else { return "--" }
        let number = Double(value)
        for (divisor, suffix) in [(1e12, "T"), (1e9, "G"), (1e6, "M"), (1e3, "K")] {
            if abs(number) >= divisor {
                return String(format: "%.1f%@", number / divisor, suffix)
            }
        }
        return String(value)
    }

    public static func updated(_ value: String?) -> String? {
        guard let value else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]
        guard let date = withFraction.date(from: value) ?? withoutFraction.date(from: value) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
