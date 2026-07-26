// swift-tools-version:5.10
//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PackageDescription

let package = Package(
    name: "Readium",
    defaultLocalization: "en",
    platforms: [.iOS("15.0")],
    products: [
        .library(name: "ReadiumShared", targets: ["ReadiumShared"]),
        .library(name: "ReadiumStreamer", targets: ["ReadiumStreamer"]),
        .library(name: "ReadiumNavigator", targets: ["ReadiumNavigator"]),
        .library(name: "ReadiumOPDS", targets: ["ReadiumOPDS"]),
        .library(name: "ReadiumLCP", targets: ["ReadiumLCP"]),

        // Adapters to third-party dependencies.
        .library(name: "ReadiumAdapterGCDWebServer", targets: ["ReadiumAdapterGCDWebServer"]),
        .library(name: "ReadiumAdapterLCPSQLite", targets: ["ReadiumAdapterLCPSQLite"]),
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.10.0"),
        // WINCATALYST PORT BRANCH ONLY -- upstream is
        // `.package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.2")`.
        //
        // Sibling checkout on `wincat/port`, carrying a ONE-LINE portability fix:
        // `unzGetCurrentFileInfo64`'s buffer-size parameter is zlib's `uLong`
        // (C `unsigned long`), which is 64-bit on LP64 and 32-bit on LLP64, so the
        // `UInt(fileNameSize)` upstream passes does not convert on Windows. Naming
        // the zlib typealias is correct on every platform. Same relative-path
        // convention as the ZIPFoundation entry below.
        .package(path: "../Zip"),
        .package(url: "https://github.com/ra1028/DifferenceKit.git", from: "1.3.0"),
        .package(url: "https://github.com/readium/Fuzi.git", from: "4.0.0"),
        .package(url: "https://github.com/readium/GCDWebServer.git", from: "4.0.0"),
        // WINCATALYST PORT BRANCH ONLY -- upstream is
        // `.package(url: "https://github.com/readium/ZIPFoundation.git", from: "3.0.1")`.
        //
        // Repointed at a sibling checkout on the `wincat/port` branch, which makes
        // ZIPFoundation's non-Apple (zlib) arm COMPILE. That arm has never been
        // built by anyone: this fork's own .github/workflows/swift.yml disables its
        // Linux job outright (`# Linux is disabled for this fork` / `if: false`),
        // and as written it is invalid Swift everywhere -- `encode`/`decode`
        // `try await consumer(...)` INSIDE the synchronous
        // `Data.withUnsafeMutableBytes` closure. Plus two platform type
        // assumptions: `time_t` for WinSock's 32-bit `timeval.tv_sec`, and
        // `POSIXError(_:userInfo:)`, which exists only on a `_BridgedStoredNSError`
        // POSIXError. Details in that branch's commit message.
        //
        // The path is relative and deliberately `../`, so it resolves identically
        // from this checkout (`~/dev/ZIPFoundation`) and from the short staged tree
        // `make readium-harvest` builds in (which mirrors the clone alongside it).
        .package(path: "../ZIPFoundation"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.13.5"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.16.0"),
        // WINCATALYST PORT BRANCH ONLY -- upstream keeps
        // `.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.5.0")`.
        //
        // Dropped here because it is a DOCUMENTATION plugin that no target in this
        // manifest references (it is declared for `swift package generate-documentation`
        // only), and on Windows it is actively hostile to resolution: its checkout
        // contains symlinks, and resolving `1.5.0` off a partially-populated SwiftPM
        // cache fails outright with `Couldn't get revision '1.5.0^{commit}'` --
        // which aborts the whole graph and so blocks compiling every OTHER target.
        // Nothing about the port needs it.

    ],
    targets: [
        .target(
            name: "ReadiumShared",
            dependencies: [
                "ReadiumInternal",
                "SwiftSoup",
                "Zip",
                .product(name: "ReadiumFuzi", package: "Fuzi"),
                .product(name: "ReadiumZIPFoundation", package: "ZIPFoundation"),
            ],
            path: "Sources/Shared",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("CoreServices"),
                .linkedFramework("UIKit"),
            ]
        ),
        .testTarget(
            name: "ReadiumSharedTests",
            dependencies: [
                "ReadiumShared",
                "TestPublications",
            ],
            path: "Tests/SharedTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),

        .target(
            name: "ReadiumStreamer",
            dependencies: [
                "CryptoSwift",
                "ReadiumShared",
                .product(name: "ReadiumFuzi", package: "Fuzi"),
            ],
            path: "Sources/Streamer",
            resources: [
                .copy("Assets"),
            ]
        ),
        .testTarget(
            name: "ReadiumStreamerTests",
            dependencies: ["ReadiumStreamer", "TestPublications"],
            path: "Tests/StreamerTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),

        .target(
            name: "ReadiumNavigator",
            dependencies: [
                "ReadiumInternal",
                "ReadiumShared",
                "DifferenceKit",
                "SwiftSoup",
            ],
            path: "Sources/Navigator",
            exclude: [
                "EPUB/Scripts",
            ],
            resources: [
                .copy("EPUB/Assets"),
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ReadiumNavigatorTests",
            dependencies: ["ReadiumNavigator"],
            path: "Tests/NavigatorTests",
            exclude: [
                "UITests",
            ]
        ),

        .target(
            name: "ReadiumOPDS",
            dependencies: [
                "ReadiumShared",
                .product(name: "ReadiumFuzi", package: "Fuzi"),
            ],
            path: "Sources/OPDS"
        ),
        .testTarget(
            name: "ReadiumOPDSTests",
            dependencies: ["ReadiumOPDS"],
            path: "Tests/OPDSTests",
            resources: [
                .copy("Samples"),
            ]
        ),

        .target(
            name: "ReadiumLCP",
            dependencies: [
                "CryptoSwift",
                "ReadiumInternal",
                "ReadiumShared",
                .product(name: "ReadiumZIPFoundation", package: "ZIPFoundation"),
            ],
            path: "Sources/LCP",
            resources: [
                .process("Resources"),
            ]
        ),
        // These tests require a R2LCPClient.framework to run.
        // TODO: Find a solution to run the tests with GitHub action.
        // .testTarget(
        //     name: "ReadiumLCPTests",
        //     dependencies: [
        //         "ReadiumLCP",
        //         "ReadiumShared",
        //         "ReadiumStreamer",
        //         "TestPublications",
        //     ],
        //     path: "Tests/LCPTests"
        // ),

        .target(
            name: "ReadiumAdapterGCDWebServer",
            dependencies: [
                .product(name: "ReadiumGCDWebServer", package: "GCDWebServer"),
                "ReadiumShared",
            ],
            path: "Sources/Adapters/GCDWebServer"
        ),

        .target(
            name: "ReadiumAdapterLCPSQLite",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                "ReadiumLCP",
            ],
            path: "Sources/Adapters/LCPSQLite"
        ),

        .target(
            name: "ReadiumInternal",
            path: "Sources/Internal"
        ),
        .testTarget(
            name: "ReadiumInternalTests",
            dependencies: ["ReadiumInternal"],
            path: "Tests/InternalTests"
        ),

        // Shared test publications used across multiple test targets.
        .target(
            name: "TestPublications",
            path: "Tests/Publications",
            resources: [
                .copy("Publications"),
            ]
        ),
    ]
)
