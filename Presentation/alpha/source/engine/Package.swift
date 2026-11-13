// swift-tools-version: 6.0
// A small program that asks the icu4swift astronomy engine for the numbers the presentation needs.
// It uses the repository three folders up as a library and changes nothing in it.
import PackageDescription

let package = Package(
    name: "EveningNumbers",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../..")],
    targets: [
        .executableTarget(
            name: "EveningNumbers",
            dependencies: [
                .product(name: "CalendarAstronomical", package: "icu4swift"),
                .product(name: "AstronomicalEngine", package: "icu4swift"),
                .product(name: "CalendarSimple", package: "icu4swift"),
                .product(name: "CalendarCore", package: "icu4swift"),
            ]
        )
    ]
)
