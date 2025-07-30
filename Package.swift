// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Matcha",
    platforms: [
        .macOS(.v14),
        .custom("linux", versionString: "1.0.0"),
    ],
    products: [
        // Main library
        .library(
            name: "Matcha",
            targets: ["Matcha"]
        ),
        // Optional styling library (Lip Gloss equivalent)
        .library(
            name: "MatchaStyle",
            targets: ["MatchaStyle"]
        ),
        // Component library (Bubbles equivalent)
        .library(
            name: "MatchaBubbles",
            targets: ["MatchaBubbles"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        // Main library target
        .target(
            name: "Matcha",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // Styling library
        .target(
            name: "MatchaStyle",
            dependencies: ["Matcha"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // Component library
        .target(
            name: "MatchaBubbles",
            dependencies: ["Matcha", "MatchaStyle"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // Test targets
        .testTarget(
            name: "MatchaTests",
            dependencies: ["Matcha"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // Example executables
        .executableTarget(
            name: "SimpleExample",
            dependencies: ["Matcha"],
            path: "Examples/Simple",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "CounterExample",
            dependencies: ["Matcha"],
            path: "Examples/Counter",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "TimerExample",
            dependencies: ["Matcha"],
            path: "Examples/Timer",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "AltScreenExample",
            dependencies: ["Matcha"],
            path: "Examples/AltScreen",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "MouseExample",
            dependencies: ["Matcha"],
            path: "Examples/Mouse",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "FocusExample",
            dependencies: ["Matcha"],
            path: "Examples/Focus",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "TextInputExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/TextInput",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "ListExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/List",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "ExecExample",
            dependencies: ["Matcha", "MatchaStyle"],
            path: "Examples/ExecExample"
        ),
        .executableTarget(
            name: "ProgressExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/ProgressExample"
        ),
        .executableTarget(
            name: "ViewportExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/ViewportExample"
        ),
        .executableTarget(
            name: "TableExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/TableExample"
        ),
        .executableTarget(
            name: "PaginatorExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/PaginatorExample"
        ),
        .executableTarget(
            name: "SpinnerExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/SpinnerExample"
        ),
        .executableTarget(
            name: "StopwatchExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/StopwatchExample"
        ),
        .executableTarget(
            name: "HelpExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/HelpExample"
        ),
        .executableTarget(
            name: "FullScreen",
            dependencies: ["Matcha", "MatchaStyle"],
            path: "Examples/FullScreen"
        ),
        .executableTarget(
            name: "SplitPanes",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/SplitPanes"
        ),
        .executableTarget(
            name: "RealTimeUpdates",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/RealTimeUpdates"
        ),
        .executableTarget(
            name: "TextAreaExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/TextAreaExample"
        ),
        .executableTarget(
            name: "KeyBindingExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/KeyBindingExample"
        ),
        .executableTarget(
            name: "TabsExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/TabsExample"
        ),
        .executableTarget(
            name: "FileBrowserExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/FileBrowserExample"
        ),
        .executableTarget(
            name: "ConfirmationExample",
            dependencies: ["Matcha", "MatchaBubbles", "MatchaStyle"],
            path: "Examples/ConfirmationExample"
        ),
    ]
)
