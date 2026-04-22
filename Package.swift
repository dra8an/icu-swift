// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftICU",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "CalendarCore", targets: ["CalendarCore"]),
        .library(name: "CalendarSimple", targets: ["CalendarSimple"]),
        .library(name: "CalendarComplex", targets: ["CalendarComplex"]),
        .library(name: "DateArithmetic", targets: ["DateArithmetic"]),
        .library(name: "CalendarJapanese", targets: ["CalendarJapanese"]),
        .library(name: "AstronomicalEngine", targets: ["AstronomicalEngine"]),
        .library(name: "CalendarAstronomical", targets: ["CalendarAstronomical"]),
        .library(name: "CalendarHindu", targets: ["CalendarHindu"]),
        .library(name: "CalendarFoundation", targets: ["CalendarFoundation"]),
    ],
    targets: [
        .target(
            name: "CalendarCore",
            path: "Sources/CalendarCore"
        ),
        .target(
            name: "CalendarSimple",
            dependencies: ["CalendarCore"],
            path: "Sources/CalendarSimple"
        ),
        .testTarget(
            name: "CalendarCoreTests",
            dependencies: ["CalendarCore", "CalendarSimple"],
            path: "Tests/CalendarCoreTests"
        ),
        .target(
            name: "CalendarComplex",
            dependencies: ["CalendarCore", "CalendarSimple"],
            path: "Sources/CalendarComplex"
        ),
        .testTarget(
            name: "CalendarSimpleTests",
            dependencies: ["CalendarSimple", "CalendarCore"],
            path: "Tests/CalendarSimpleTests"
        ),
        .target(
            name: "DateArithmetic",
            dependencies: ["CalendarCore"],
            path: "Sources/DateArithmetic"
        ),
        .testTarget(
            name: "CalendarComplexTests",
            dependencies: ["CalendarComplex", "CalendarSimple", "CalendarCore"],
            path: "Tests/CalendarComplexTests"
        ),
        .target(
            name: "CalendarJapanese",
            dependencies: ["CalendarCore", "CalendarSimple"],
            path: "Sources/CalendarJapanese"
        ),
        .target(
            name: "CalendarHindu",
            dependencies: ["CalendarCore", "CalendarSimple", "AstronomicalEngine"],
            path: "Sources/CalendarHindu"
        ),
        .testTarget(
            name: "CalendarHinduTests",
            dependencies: ["CalendarHindu", "CalendarSimple", "AstronomicalEngine", "CalendarCore"],
            path: "Tests/CalendarHinduTests"
        ),
        .testTarget(
            name: "DateArithmeticTests",
            dependencies: ["DateArithmetic", "CalendarSimple", "CalendarCore"],
            path: "Tests/DateArithmeticTests"
        ),
        .target(
            name: "AstronomicalEngine",
            dependencies: ["CalendarCore"],
            path: "Sources/AstronomicalEngine"
        ),
        .target(
            name: "CalendarAstronomical",
            dependencies: ["CalendarCore", "CalendarSimple", "AstronomicalEngine"],
            path: "Sources/CalendarAstronomical"
        ),
        .testTarget(
            name: "CalendarAstronomicalTests",
            dependencies: ["CalendarAstronomical", "CalendarSimple", "AstronomicalEngine", "CalendarCore"],
            path: "Tests/CalendarAstronomicalTests"
        ),
        .testTarget(
            name: "AstronomicalEngineTests",
            dependencies: ["AstronomicalEngine", "CalendarCore"],
            path: "Tests/AstronomicalEngineTests"
        ),
        .testTarget(
            name: "CalendarJapaneseTests",
            dependencies: ["CalendarJapanese", "CalendarSimple", "CalendarCore"],
            path: "Tests/CalendarJapaneseTests"
        ),
        .target(
            name: "CalendarFoundation",
            dependencies: ["CalendarCore"],
            path: "Sources/CalendarFoundation"
        ),
        .testTarget(
            name: "CalendarFoundationTests",
            dependencies: ["CalendarFoundation", "CalendarCore"],
            path: "Tests/CalendarFoundationTests"
        ),
    ]
)
