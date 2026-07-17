// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PyNucleantUI",
    platforms: [
        // v14 floor: SulphurFrame is @Observable (Observation framework).
        // If a pre-14 target ever matters, a patched OpenObservation clone
        // is parked at /Volumes/CodeSSD/dev_projects/OpenObservation.
        .macOS(.v14)
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
        .package(path: "/Volumes/CodeSSD/dev_projects/pyswiftkit/PySwiftKit"),
        .package(url: "https://github.com/Py-Swift/SwiftyKvLang", branch: "master"),
        .package(url: "https://github.com/Py-Swift/PySwiftAST.git", branch: "master")
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
                "KvLangBuilder",
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
        .target(
            name: "KvLangBuilder",
            dependencies: [
                .product(name: "SulphurCore", package: "SulphurCore"),
                .product(name: "SulphurApplication", package: "SulphurCore"),
                .product(name: "SulphurUI", package: "SulphurUI"),
                .product(name: "SulphurVulkan", package: "SulphurVulkan"),
                .product(name: "VulkanCore", package: "SulphurVulkan"),
                .product(name: "SulphurShader", package: "SulphurShader"),
                .product(name: "PySwiftKit", package: "PySwiftKit"),
                .product(name: "KvParser", package: "SwiftyKvLang"),
                .product(name: "KivyWidgetRegistry", package: "SwiftyKvLang"),
                .product(name: "PySwiftAST", package: "PySwiftAST")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
        ),
        .testTarget(
            name: "PyNucleantUITests",
            dependencies: ["PyNucleantUI"]
        ),
    ]
)
