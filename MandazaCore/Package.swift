// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MandazaKit",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "MandazaKit", targets: ["MandazaKit"])
    ],
    targets: [
        .target(
            name: "MandazaKit",
            path: ".",
            exclude: ["Package.swift"]
        )
    ]
)
