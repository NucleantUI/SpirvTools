// swift-tools-version: 6.1

import Foundation
import PackageDescription

/// Whether this build is for macOS, the one platform SPIRV-Tools is prebuilt
/// for so far. Package.swift is compiled by the *host* toolchain even when
/// cross-compiling, so `#if os(...)` only ever describes the host: an
/// Android or wasm build from a Mac opts out through the environment, as in
/// NucleantSkia and NucleantVulkan. Elsewhere `SpirvContext` compiles without
/// SPIRV-Tools and throws when it is used.
let buildsForMac: Bool = {
#if os(macOS)
    let env = ProcessInfo.processInfo.environment
    return env["SWIFT_ANDROID_HOME"] == nil && env["ANDROID_BUILD"] == nil && env["WASM_BUILD"] != "1"
#else
    return false
#endif
}()

/// CSpirvTools.xcframework.zip on the latest GitHub release: its URL and
/// checksum. Written here by .github/workflows/release.yml, which commits it
/// to master with the release, so master and the release's tag build from
/// the same archive. nil only before the first release.
let releasedCSpirvTools: (url: String, checksum: String)? = (
    url: "https://github.com/NucleantUI/SpirvTools/releases/download/0.0.1/CSpirvTools.xcframework.zip",
    checksum: "174e598ffde2e0c466b70d5505b22b6484318aa76ef04e237f1a083365326a5c"
)

/// SPIRV-Tools' static libraries and C API (spirv-tools/libspirv.h), as the
/// "CSpirvTools" binary target:
///   * with SPIRV_TOOLS_ARTIFACTS=1, or before the first release,
///     Artifacts/CSpirvTools.xcframework.zip — what
///     scripts/build_spirv_tools.py builds;
///   * otherwise the release's archive.
func cSpirvTools() -> Target {
    if ProcessInfo.processInfo.environment["SPIRV_TOOLS_ARTIFACTS"] != "1", let release = releasedCSpirvTools {
        return .binaryTarget(name: "CSpirvTools", url: release.url, checksum: release.checksum)
    }
    return .binaryTarget(name: "CSpirvTools", path: "Artifacts/CSpirvTools.xcframework.zip")
}

let package = Package(
    name: "SpirvTools",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "SpirvTools",
            targets: ["SpirvTools"]
        ),
    ],
    targets: (buildsForMac ? [cSpirvTools()] : []) + [
        // Swift over the C API: validate, disassemble, assemble, optimize.
        .target(
            name: "SpirvTools",
            dependencies: buildsForMac ? [.target(name: "CSpirvTools", condition: .when(platforms: [.macOS]))] : []
        ),
        .testTarget(
            name: "SpirvToolsTests",
            dependencies: ["SpirvTools"]
        ),
    ]
)
