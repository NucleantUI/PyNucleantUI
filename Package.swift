// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let nucleantDev = true
let pskDev = true

let env = ProcessInfo.processInfo.environment

let PSK_DEVELOPMENT = env["PSK_DEVELOPMENT"] == "1"
let PIP_MODE = env["PIP_MODE"] == "1"


enum PythonMode {
    case pip
    case android
    case development
    case normal
    
    static let shared = Self.current()
    
    static func current() -> Self {
        if PIP_MODE { return .pip }
        if PSK_DEVELOPMENT { return .development }
        if env["SWIFT_ANDROID_HOME"] != nil { return .android }
        return .normal
    }
    
    var cSettings: [CSetting] {
        switch self {
        case .pip:
            [.define("PIP_MODE")]
        case .normal:
            [.define("FRAMEWORK_MODE")]
        case .android:
            [.define("PIP_MODE")]
        case .development:
            []
        }
    }
    
    var linkerSettings: [LinkerSetting] {
        switch self {
        case .pip:
            PSK_DEVELOPMENT ? [
                .linkedFramework("Python"),
                .linkedFramework("MoltenVK")
            ] : []
        case .normal:
            [.linkedFramework("Python")]
        case .android:
            []
        case .development:
            []
        }
    }
}


/// Dependencies on modules vended by the NucleantApplication package.
///
/// In PIP_MODE that package ships a *single* dynamic library holding all of its
/// targets, so every module it vends — NucleantApplication, NucleantWindow,
/// Platform_MacOS, Platform_iOS — is reached through the one product name. A
/// library product vends all of its targets' modules, so the `import`s are
/// unaffected. In static mode each module keeps its own product, as before.
func nucleantApplication(_ modules: Target.Dependency...) -> [Target.Dependency] {
    PIP_MODE
        ? [.product(name: "NucleantApplication", package: "NucleantApplication")]
        : modules
}

/// Where the local PySwiftKit checkout lives, which differs per machine: it is
/// a sibling of this package in the Linux tree, and sits on an external volume
/// on the macOS box. Hardcoding either one breaks the other, so take the first
/// that actually exists. Every other `pskDev`-style dependency above is a
/// plain sibling and needs no such treatment.
func localPySwiftKitPath() -> String {
    let candidates = [
        "../PySwiftKit",
        "/Volumes/CodeSSD/dev_projects/pyswiftkit/PySwiftKit",
    ]
    let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    for candidate in candidates {
        let absolute = candidate.hasPrefix("/")
            ? candidate
            : packageDir.appendingPathComponent(candidate).standardized.path
        if FileManager.default.fileExists(atPath: absolute) { return candidate }
    }
    // Nothing found — return the sibling so SwiftPM reports the missing path
    // rather than this function silently picking an equally absent one.
    return candidates[0]
}

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
            .package(path: localPySwiftKitPath()),
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

func pipTargets() -> [Target] {
    var targets = [Target]()
    
    if PIP_MODE {
        targets.append(
            contentsOf: [
                .target(
                    name: "PNU_App",
                    dependencies: [
                        .product(name: "PySwiftKit", package: "PySwiftKit"),
                        .product(name: "NucleantApplication", package: "NucleantApplication"),
                        .product(name: "NucleantThorVG", package: "NucleantThorVG"),
                    ],
                    path: "PyApi/App",
                    swiftSettings: [.swiftLanguageMode(.v5)],
                    linkerSettings: PythonMode.shared.linkerSettings,
                ),
                .target(
                    name: "PNU_Canvas",
                    dependencies: [
                        "PNU_Core",
                        .product(name: "PySwiftKit", package: "PySwiftKit"),
                        //.product(name: "NucleantApplication", package: "NucleantApplication"),
                        
                    ],
                    path: "PyApi/Canvas",
                    swiftSettings: [.swiftLanguageMode(.v5)],
                    linkerSettings: PythonMode.shared.linkerSettings,
                ),
                .target(
                    name: "PNU_Core",
                    dependencies: [
                        "PNU_Layout",
                        .product(name: "PySwiftKit", package: "PySwiftKit"),
                        .product(name: "NucleantApplication", package: "NucleantApplication"),
                        //.product(name: "NucleantThorVG", package: "NucleantThorVG"),
                        .product(name: "NucleantVulkan", package: "NucleantVulkan"),
                        .product(name: "VulkanCore", package: "NucleantVulkan"),
                        .product(name: "NucleantSkia", package: "NucleantSkia"),
                        .product(name: "NucleantThorVG", package: "NucleantThorVG"),
                    ],
                    path: "PyApi/Core",
                    swiftSettings: [
                        .swiftLanguageMode(.v5)
                    ],
                    linkerSettings: PythonMode.shared.linkerSettings,
                ),
                .target(
                    name: "PNU_Widget",
                    dependencies: [
                        "PNU_Core",
                        .product(name: "PySwiftKit", package: "PySwiftKit"),
                        .product(name: "NucleantApplication", package: "NucleantApplication"),
                        //.product(name: "NucleantThorVG", package: "NucleantThorVG"),
                    ],
                    path: "PyApi/Widget",
                    swiftSettings: [
                        .swiftLanguageMode(.v5)
                    ],
                    linkerSettings: PythonMode.shared.linkerSettings,
                ),
                .target(
                    name: "PNU_Layout",
                    dependencies: [
                        "PyNucleantUI",
                        .product(name: "PySwiftKit", package: "PySwiftKit"),
                        .product(name: "NucleantApplication", package: "NucleantApplication"),
                        //.product(name: "NucleantThorVG", package: "NucleantThorVG"),
                    ],
                    path: "PyApi/Layout",
                    swiftSettings: [
                        .swiftLanguageMode(.v5)
                    ],
                    linkerSettings: PythonMode.shared.linkerSettings,
                ),
                .target(
                    name: "PNU_Window",
                    dependencies: [
                        "PyNucleantUI",
                        "PNU_Widget",
                        "PNU_App",
                        .product(name: "PySwiftKit", package: "PySwiftKit"),
                        //.product(name: "NucleantThorVG", package: "NucleantThorVG"),
                    ] + nucleantApplication(
                        .product(name: "NucleantApplication", package: "NucleantApplication"),
                        .product(name: "NucleantWindow", package: "NucleantApplication")
                    ),
                    path: "PyApi/Window",
                    swiftSettings: [
                        .swiftLanguageMode(.v5)
                    ],
                    linkerSettings: PythonMode.shared.linkerSettings,
                ),
            ]
        )
    }
    
    return targets
}

func pyModules() -> [Product] {
    var products =  [Product]()
    if PIP_MODE {
        // One dynamic library for every Python module, not one per module.
        //
        // SwiftPM links a same-package target dependency *statically* even when
        // that target is also its own dynamic product. With a product per
        // module, PNU_Core landed in canvas/widget/window, PNU_Layout in four
        // images, PyNucleantUI in four and PNU_App in two — and two copies of a
        // Swift module in one process means two type descriptors, so
        // conformance lookup and generic metadata instantiation break across
        // the boundary (widget's PyWidgetBase is not window's). Collapsing the
        // targets into a single image leaves exactly one descriptor each.
        //
        // Each @PyModule still emits its own @_cdecl("PyInit_<name>"), so the
        // five entry points simply share a library; nucleant/__init__.py points
        // the module names at it.
        products.append(
            .library(
                name: "core",
                type: .dynamic,
                targets: ["PNU_App", "PNU_Canvas", "PNU_Core", "PNU_Layout", "PNU_Widget", "PNU_Window"]
            )
        )
    }
    return products
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
        // Static in both modes. This product exists for the Xcode app, which
        // links it and calls PyNucleantUI_Package.addToImports(); in PIP_MODE
        // nothing consumes it, and the PNU_* targets pull the PyNucleantUI
        // module into _nucleant.so directly. Making it dynamic there only built
        // a second, unshipped libPyNucleantUI.dylib holding a duplicate copy.
        .library(
            name: "PyNucleantUI",
            type: .static,
            targets: ["PyNucleantUI"]
        ),
    ] + pyModules(),
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
                .product(name: "NucleantSkia", package: "NucleantSkia"),
                .product(name: "NucleantThorVG", package: "NucleantThorVG"),
                .product(name: "NucleantVulkan", package: "NucleantVulkan"),
                .product(name: "VulkanCore", package: "NucleantVulkan"),
                //.product(name: "NucleanShader", package: "NucleantVulkan"),
                .product(name: "PySwiftKit", package: "PySwiftKit"),
            ] + nucleantApplication(
                .product(name: "NucleantApplication", package: "NucleantApplication"),
                .product(name: "NucleantWindow", package: "NucleantApplication"),
                .product(name: "Platform_MacOS", package: "NucleantApplication", condition: .when(platforms: [.macOS]))
            ),
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                //.linkedFramework("Python")
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
                linkerSettings: PSK_DEVELOPMENT ? [
                    .linkedFramework("Python"),
                ] : []
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
    ] + pipTargets(),
    cxxLanguageStandard: .cxx17
)
