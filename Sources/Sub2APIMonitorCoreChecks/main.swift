import Foundation
import Sub2APIMonitorCore

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message): message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw CheckFailure.failed(message) }
}

let normalized = try ServerURL.normalize(" https://example.com/admin/accounts?x=1 ")
try expect(normalized.absoluteString == "https://example.com", "server URL normalization")

do {
    _ = try ServerURL.normalize("http://example.com")
    throw CheckFailure.failed("insecure remote URL was accepted")
} catch is Sub2APIError {
    // Expected.
}

let json = #"""
{"code":0,"message":"success","data":{"errors":{},"usage":{"4":{"updated_at":"2026-09-08T15:00:12.130815856+12:00","five_hour":{"utilization":0,"remaining_seconds":0,"window_stats":{"requests":1687,"tokens":183763944,"user_cost":149.58}},"seven_day":{"utilization":3,"remaining_seconds":599168}}}}}
"""#
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
let envelope = try decoder.decode(APIEnvelope<BatchUsageData>.self, from: Data(json.utf8))
try expect(
    envelope.data.usage["4"]?.fiveHour?.windowStats?.tokens == 183_763_944,
    "usage stats decoding"
)
try expect(envelope.data.usage["4"]?.sevenDay?.utilization == 3, "usage window decoding")
try expect(UsageFormatter.percentText(95.4) == "95%", "percentage formatting")
try expect(UsageFormatter.percentText(nil) == "--%", "missing percentage formatting")
try expect(
    UsageFormatter.duration(seconds: 331_187) == "resets in 3d 19h",
    "duration formatting"
)
try expect(UsageFormatter.compact(84_917_784) == "84.9M", "compact number formatting")
try expect(
    UsageFormatter.updated("2026-09-08T15:00:12.130815856+12:00") != nil,
    "nanosecond timestamp formatting"
)

print("All core checks passed.")
