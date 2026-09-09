// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Sub2APIMonitor",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Sub2APIMonitorCore", targets: ["Sub2APIMonitorCore"]),
        .executable(name: "Sub2APIMonitor", targets: ["Sub2APIMonitor"]),
        .executable(name: "Sub2APIMonitorCoreChecks", targets: ["Sub2APIMonitorCoreChecks"]),
    ],
    targets: [
        .target(name: "Sub2APIMonitorCore"),
        .executableTarget(
            name: "Sub2APIMonitor",
            dependencies: ["Sub2APIMonitorCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
            ]
        ),
        .executableTarget(
            name: "Sub2APIMonitorCoreChecks",
            dependencies: ["Sub2APIMonitorCore"]
        ),
    ]
)
