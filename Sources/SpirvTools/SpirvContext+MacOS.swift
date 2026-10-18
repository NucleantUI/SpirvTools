//
//  SpirvContext+MacOS.swift
//  SpirvTools
//
//  SpirvContext on macOS: SPIRV-Tools' C API, from the prebuilt
//  CSpirvTools.xcframework (scripts/build_spirv_tools.py).
//

#if os(macOS)
import CSpirvTools
import Foundation

extension SpirvTargetEnvironment {
    /// The environment named `name`, as `--target-env` spells it; nil for an unknown name.
    public init?(name: String) {
        var env = SPV_ENV_UNIVERSAL_1_0
        guard spvParseTargetEnv(name, &env) else { return nil }
        self.init(validName: name)
    }

    var raw: spv_target_env {
        var env = SPV_ENV_UNIVERSAL_1_0
        _ = spvParseTargetEnv(description, &env)
        return env
    }
}

extension SpirvDiagnostic {
    init(_ diagnostic: spv_diagnostic) {
        let d = diagnostic.pointee
        let message = d.error.map { String(cString: $0) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if d.isTextSource {
            self.init(message: message, line: Int(d.position.line), column: Int(d.position.column))
        } else {
            self.init(message: message, instruction: Int(d.position.index))
        }
    }
}

/// SPIRV-Tools for one target environment: the validator, the disassembler
/// and assembler, and the optimizer, in process.
public final class SpirvContext {
    public let environment: SpirvTargetEnvironment
    private let context: spv_context

    public init(environment: SpirvTargetEnvironment = .vulkan1_0) {
        self.environment = environment
        context = spvContextCreate(environment.raw)
    }

    deinit {
        spvContextDestroy(context)
    }

    /// The SPIRV-Tools version linked in.
    public static var version: String {
        String(cString: spvSoftwareVersionDetailsString())
    }

    // MARK: Validate

    /// Validates the module; nil when it is valid, else the first error. The
    /// message names ids by their `OpName` when `friendlyNames` is set.
    public func validate(_ words: [UInt32], friendlyNames: Bool = true) -> SpirvDiagnostic? {
        let options = spvValidatorOptionsCreate()
        defer { spvValidatorOptionsDestroy(options) }
        spvValidatorOptionsSetFriendlyNames(options, friendlyNames)
        var diagnostic: spv_diagnostic?
        defer { spvDiagnosticDestroy(diagnostic) }
        let result = words.withUnsafeBufferPointer { buffer -> spv_result_t in
            var binary = spv_const_binary_t(code: buffer.baseAddress, wordCount: buffer.count)
            return spvValidateWithOptions(context, options, &binary, &diagnostic)
        }
        guard result != SPV_SUCCESS else { return nil }
        if let diagnostic { return SpirvDiagnostic(diagnostic) }
        return SpirvDiagnostic(message: "validation failed (\(result.rawValue))")
    }

    // MARK: Disassemble / assemble

    /// The module as assembly text.
    public func disassemble(_ words: [UInt32], options: DisassemblyOptions = [.friendlyNames, .indent]) throws -> String {
        var text: spv_text?
        var diagnostic: spv_diagnostic?
        defer {
            spvTextDestroy(text)
            spvDiagnosticDestroy(diagnostic)
        }
        let flags = Self.flags(options)
        let result = words.withUnsafeBufferPointer { buffer in
            spvBinaryToText(context, buffer.baseAddress, buffer.count, flags, &text, &diagnostic)
        }
        guard result == SPV_SUCCESS, let text, let str = text.pointee.str else {
            throw diagnostic.map(SpirvDiagnostic.init) ?? SpirvDiagnostic(message: "disassembly failed (\(result.rawValue))")
        }
        let bytes = UnsafeRawBufferPointer(start: str, count: text.pointee.length)
        return String(decoding: bytes, as: UTF8.self)
    }

    /// `options` as SPIRV-Tools' `SPV_BINARY_TO_TEXT_OPTION_*` bits.
    private static func flags(_ options: DisassemblyOptions) -> UInt32 {
        let bits: [(DisassemblyOptions, spv_binary_to_text_options_t)] = [
            (.friendlyNames, SPV_BINARY_TO_TEXT_OPTION_FRIENDLY_NAMES),
            (.indent, SPV_BINARY_TO_TEXT_OPTION_INDENT),
            (.nestedIndent, SPV_BINARY_TO_TEXT_OPTION_NESTED_INDENT),
            (.comment, SPV_BINARY_TO_TEXT_OPTION_COMMENT),
            (.noHeader, SPV_BINARY_TO_TEXT_OPTION_NO_HEADER),
            (.byteOffsets, SPV_BINARY_TO_TEXT_OPTION_SHOW_BYTE_OFFSET),
        ]
        return bits.reduce(0) { options.contains($1.0) ? $0 | $1.1.rawValue : $0 }
    }

    /// The module the assembly text describes.
    public func assemble(_ source: String) throws -> [UInt32] {
        var binary: spv_binary?
        var diagnostic: spv_diagnostic?
        defer {
            spvBinaryDestroy(binary)
            spvDiagnosticDestroy(diagnostic)
        }
        let utf8 = Array(source.utf8)
        let result = utf8.withUnsafeBufferPointer { buffer in
            buffer.withMemoryRebound(to: CChar.self) { chars in
                spvTextToBinaryWithOptions(context, chars.baseAddress, chars.count,
                                           SPV_TEXT_TO_BINARY_OPTION_PRESERVE_NUMERIC_IDS.rawValue, &binary, &diagnostic)
            }
        }
        guard result == SPV_SUCCESS, let binary else {
            throw diagnostic.map(SpirvDiagnostic.init) ?? SpirvDiagnostic(message: "assembly failed (\(result.rawValue))")
        }
        return Array(UnsafeBufferPointer(start: binary.pointee.code, count: binary.pointee.wordCount))
    }

    // MARK: Optimize

    /// Runs the optimizer passes `flags` name, as `spirv-opt` spells them:
    /// `-O`, `-Os`, `--eliminate-dead-code-aggressive`, `--strip-debug`, …
    /// Throws for an unknown flag or a pass that fails, with the optimizer's
    /// messages.
    public func optimize(_ words: [UInt32], flags: [String]) throws -> [UInt32] {
        let optimizer = spvOptimizerCreate(environment.raw)
        defer { spvOptimizerDestroy(optimizer) }
        for flag in flags where !spvOptimizerRegisterPassFromFlag(optimizer, flag) {
            throw SpirvDiagnostic(message: "unknown optimizer flag \(flag)")
        }
        let options = spvOptimizerOptionsCreate()
        defer { spvOptimizerOptionsDestroy(options) }
        spvOptimizerOptionsSetRunValidator(options, false)

        var binary: spv_binary?
        defer { spvBinaryDestroy(binary) }
        let (result, messages) = OptimizerMessages.collect {
            spvOptimizerSetMessageConsumer(optimizer, OptimizerMessages.consumer)
            return words.withUnsafeBufferPointer { buffer in
                spvOptimizerRun(optimizer, buffer.baseAddress, buffer.count, &binary, options)
            }
        }
        guard result == SPV_SUCCESS, let binary else {
            let detail = messages.isEmpty ? "error \(result.rawValue)" : messages.joined(separator: "\n")
            throw SpirvDiagnostic(message: "optimizer failed: \(detail)")
        }
        return Array(UnsafeBufferPointer(start: binary.pointee.code, count: binary.pointee.wordCount))
    }
}

/// The optimizer reports through a C function pointer with no context, so its
/// messages go to one collector at a time, behind a lock.
final class OptimizerMessages: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var current: [String] = []

    static let consumer: spv_message_consumer = { level, _, _, message in
        guard level.rawValue <= SPV_MSG_WARNING.rawValue, let message else { return }
        current.append(String(cString: message))
    }

    static func collect<T>(_ body: () -> T) -> (T, [String]) {
        lock.lock()
        defer { lock.unlock() }
        current = []
        let value = body()
        return (value, current)
    }
}
#endif
