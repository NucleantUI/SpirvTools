# SpirvTools

[SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools) in Swift: the validator,
disassembler, assembler and optimizer, in process, through SPIRV-Tools' C API.
PyShader's `pyshaderc` and the `claude-spirv-tools` plugin use it.

```swift
.package(url: "https://github.com/NucleantUI/SpirvTools.git", .upToNextMinor(from: "0.0.1")),
```

```swift
import SpirvTools

let tools = SpirvContext()                       // vulkan1.0; SpirvTargetEnvironment(name: "vulkan1.3")
let words = try tools.assemble(text)
if let error = tools.validate(words) { print(error) }        // first error, with its instruction
let optimized = try tools.optimize(words, flags: ["-O"])      // spirv-opt flags
print(try tools.disassemble(optimized, options: [.friendlyNames, .indent]))
```

## Platforms

| Platform | SPIRV-Tools |
|---|---|
| macOS (arm64, x86_64) | Prebuilt static libraries, `CSpirvTools.xcframework.zip` on each release |
| Everything else | Not built yet. `SpirvContext` compiles with the same API, and every call fails with an error saying so, so packages that depend on SpirvTools still build there. |

## Building SPIRV-Tools

A release builds it in CI. To build it here (CMake, Ninja and Xcode's command
line tools):

```sh
uv run scripts/build_spirv_tools.py        # -> Artifacts/CSpirvTools.xcframework.zip
SPIRV_TOOLS_ARTIFACTS=1 swift test         # against it, instead of the release's
```

SPIRV-Tools and SPIRV-Headers are cloned at one Vulkan SDK tag (`SDK_REF` in the
script) into `scripts/.work`, so repeated runs are incremental.

## Releasing

Actions → **release** → Run workflow on `master` with the version. It builds and
tests the archive, writes its URL and checksum into `Package.swift`
(`releasedCSpirvTools`), tags and publishes the release, then checks that a
package depending on it builds on macOS and Linux.
