// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let nucleantDev = true
let pskDev = false

func getDependencies() -> [Package.Dependency] {
    var deps = [Package.Dependency]()
    
    
    
    if nucleantDev {
        deps.append(contentsOf: [
            .package(path: "../NucleantApplication"),
            .package(path: "../NucleantVulkan"),
            .package(path: "../NucleantSkia"),
            .package(path: "../NucleantThorVG"),
        ])
    } else {
        deps.append(contentsOf: [
            .package(url: "https://github.com/NucleantUI/NucleantApplication", branch: "master"),
            .package(url: "https://github.com/NucleantUI/NucleantVulkan", branch: "master"),
            .package(url: "https://github.com/NucleantUI/NucleantSkia", branch: "master"),
            .package(url: "https://github.com/NucleantUI/NucleantThorVG", branch: "master")
        ])
    }
    
    if pskDev {
        deps.append(contentsOf: [
            .package(path: "/Volumes/CodeSSD/dev_projects/pyswiftkit/PySwiftKit"),
        ])
    } else {
        deps.append(contentsOf: [
            .package(url: "https://github.com/Py-Swift/PySwiftKit", branch: "master"),
        ])
    }
    
    deps.append(contentsOf: [
        .package(url: "https://github.com/Py-Swift/SwiftyKvLang", branch: "master"),
        .package(url: "https://github.com/Py-Swift/PySwiftAST.git", branch: "master"),
        //.package(path: "/Volumes/CodeSSD/dev_projects/pyswiftkit/PyFileGenerator")
    ])
    
    return deps
}

let package = Package(
    name: "PyNucleantUI",
    platforms: [
        // v14 floor: SulphurFrame is @Observable (Observation framework).
        // If a pre-14 target ever matters, a patched OpenObservation clone
        // is parked at /Volumes/CodeSSD/dev_projects/OpenObservation.
        // iOS 17 is the same Observation floor on iOS.
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PyNucleantUI",
            targets: ["PyNucleantUI"]
        ),
    ],
    dependencies: getDependencies(),
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PyNucleantUI",
            dependencies: [
                "KvLangBuilder",
                "PyNucleantBuffer",
                //.product(name: "SulphurCore", package: "SulphurCore"),
                .product(name: "NucleantApplication", package: "NucleantApplication"),
                .product(name: "NucleantWindow", package: "NucleantApplication"),
                .product(name: "Platform_MacOS", package: "NucleantApplication", condition: .when(platforms: [.macOS])),
                .product(name: "NucleantSkia", package: "NucleantSkia"),
                .product(name: "NucleantThorVG", package: "NucleantThorVG"),
                .product(name: "NucleantVulkan", package: "NucleantVulkan"),
                .product(name: "VulkanCore", package: "NucleantVulkan"),
                //.product(name: "NucleanShader", package: "NucleantVulkan"),
                .product(name: "PySwiftKit", package: "PySwiftKit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("Python")
            ]
        ),
        // The Python-buffer node kind, kept out of the engine (it speaks
        // CPython, so it is the opposite of the "generic only" bar for
        // shader-node code living in VulkanRenderEngine) and out of the
        // PyNucleantUI target itself, so the node and its engine extension
        // can be built and reasoned about without the whole PyApi surface.
            .target(
                name: "PyNucleantBuffer",
                dependencies: [
                    .product(name: "NucleantVulkan", package: "NucleantVulkan"),
                    .product(name: "VulkanCore", package: "NucleantVulkan"),
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
                //.product(name: "SulphurCore", package: "SulphurCore"),
                //.product(name: "SulphurApplication", package: "SulphurCore"),
                //.product(name: "SulphurUI", package: "SulphurUI"),
                //.product(name: "SulphurVulkan", package: "SulphurVulkan"),
                //.product(name: "VulkanCore", package: "SulphurVulkan"),
                //.product(name: "SulphurShader", package: "SulphurShader"),
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
    ],
    cxxLanguageStandard: .cxx17
)
