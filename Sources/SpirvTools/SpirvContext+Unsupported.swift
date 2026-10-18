//
//  SpirvContext+Unsupported.swift
//  SpirvTools
//
//  SpirvContext where SPIRV-Tools is not built yet (everywhere but macOS):
//  the same API, so packages that depend on SpirvTools still build there,
//  and every call fails with an error that says so.
//

#if !os(macOS)
extension SpirvTargetEnvironment {
    /// The environment named `name`; any name, since nothing here can check it.
    public init?(name: String) {
        self.init(validName: name)
    }
}

/// SpirvContext with no SPIRV-Tools behind it: every call fails.
public final class SpirvContext {
    public let environment: SpirvTargetEnvironment

    public init(environment: SpirvTargetEnvironment = .vulkan1_0) {
        self.environment = environment
    }

    public static var version: String { "unavailable" }

    static let unsupported = SpirvDiagnostic(message: "SPIRV-Tools is not built for this platform yet; only macOS has it so far")

    public func validate(_ words: [UInt32], friendlyNames: Bool = true) -> SpirvDiagnostic? {
        Self.unsupported
    }

    public func disassemble(_ words: [UInt32], options: DisassemblyOptions = [.friendlyNames, .indent]) throws -> String {
        throw Self.unsupported
    }

    public func assemble(_ source: String) throws -> [UInt32] {
        throw Self.unsupported
    }

    public func optimize(_ words: [UInt32], flags: [String]) throws -> [UInt32] {
        throw Self.unsupported
    }
}
#endif
