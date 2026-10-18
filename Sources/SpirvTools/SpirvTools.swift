//
//  SpirvTools.swift
//  SpirvTools
//
//  What every platform's `SpirvContext` takes and gives: target
//  environments, diagnostics and disassembly options. The context itself is
//  in the platform files: SpirvContext+MacOS.swift over SPIRV-Tools'
//  C API, SpirvContext+Unsupported.swift wherever SPIRV-Tools is not built
//  yet.
//

/// The environment SPIR-V is checked and transformed against: `vulkan1.0`,
/// `vulkan1.3`, `spv1.6`, … — the names `spirv-val --target-env` takes.
public struct SpirvTargetEnvironment: Sendable, CustomStringConvertible {
    /// The name, as `--target-env` spells it.
    public let description: String

    /// Vulkan 1.0, what PyShader's modules are written for.
    public static let vulkan1_0 = SpirvTargetEnvironment(validName: "vulkan1.0")

    /// A name the platform's `init?(name:)` has accepted.
    init(validName: String) {
        description = validName
    }
}

/// A message from SPIRV-Tools about a module or an assembly text.
public struct SpirvDiagnostic: Error, Sendable, CustomStringConvertible {
    public let message: String
    /// For a module: the 1-based number of the instruction at fault, counted
    /// from the first after the header; 0 when the message names none.
    public let instruction: Int
    /// For an assembly text: the 0-based line and column.
    public let line: Int
    public let column: Int

    public init(message: String, instruction: Int = 0, line: Int = 0, column: Int = 0) {
        self.message = message
        self.instruction = instruction
        self.line = line
        self.column = column
    }

    public var description: String { message }
}

extension SpirvContext {
    /// How `disassemble` writes the text.
    public struct DisassemblyOptions: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        /// `%main` for an id with an `OpName`, instead of `%12`.
        public static let friendlyNames = DisassemblyOptions(rawValue: 1 << 0)
        /// Results lined up in a column.
        public static let indent = DisassemblyOptions(rawValue: 1 << 1)
        /// Block contents indented by nesting depth.
        public static let nestedIndent = DisassemblyOptions(rawValue: 1 << 2)
        /// Comments on what an instruction refers to (adds lines).
        public static let comment = DisassemblyOptions(rawValue: 1 << 3)
        /// Leaves out the `; SPIR-V` header lines.
        public static let noHeader = DisassemblyOptions(rawValue: 1 << 4)
        /// Each instruction's word offset in a comment.
        public static let byteOffsets = DisassemblyOptions(rawValue: 1 << 5)
    }
}
