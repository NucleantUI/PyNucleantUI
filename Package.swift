// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PyNucleantUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PyNucleantUI",
            targets: ["PyNucleantUI"]
        ),
    ],
    dependencies: [
        .package(path: "/Volumes/CodeSSD/dev_projects/sulphur_dev/SulphurCore"),
        .package(path: "/Volumes/CodeSSD/dev_projects/sulphur_dev/SulphurUI"),
        .package(path: "/Volumes/CodeSSD/dev_projects/sulphur_dev/SulphurVulkan"),
        .package(path: "/Volumes/CodeSSD/dev_projects/sulphur_dev/SulphurShader"),
        .package(path: "/Volumes/CodeSSD/dev_projects/pyswiftkit/PySwiftKit")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .systemLibrary(
            name: "CWgpu",
            path: "Sources/CWgpu"
        ),
        .target(
            name: "PyNucleantUI",
            dependencies: [
                "CWgpu",
                .product(name: "SulphurCore", package: "SulphurCore"),
                .product(name: "SulphurApplication", package: "SulphurCore"),
                .product(name: "SulphurUI", package: "SulphurUI"),
                .product(name: "SulphurVulkan", package: "SulphurVulkan"),
                .product(name: "VulkanCore", package: "SulphurVulkan"),
                .product(name: "SulphurShader", package: "SulphurShader"),
                .product(name: "PySwiftKit", package: "PySwiftKit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("Python")
            ]
        ),
        .testTarget(
            name: "PyNucleantUITests",
            dependencies: ["PyNucleantUI"]
        ),
    ]
)
