import Foundation

struct CodecCapabilities: Sendable {
    var version = ""
    var encoders: Set<String> = []
    var decoders: Set<String> = []

    static func inspect(_ executable: URL) async throws -> CodecCapabilities {
        try await Task.detached {
            let version = try run(executable, ["-version"]).components(separatedBy: .newlines).first ?? "FFmpeg"
            let encoders = parse(try run(executable, ["-hide_banner", "-encoders"]))
            let decoders = parse(try run(executable, ["-hide_banner", "-decoders"]))
            return CodecCapabilities(version: version, encoders: encoders, decoders: decoders)
        }.value
    }

    static func parse(_ output: String) -> Set<String> {
        Set(output.split(separator: "\n").compactMap { line in
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2, parts[0].count == 6,
                  ["V", "A", "S"].contains(String(parts[0].prefix(1))), parts[1] != "=" else { return nil }
            return String(parts[1])
        })
    }

    private static func run(_ executable: URL, _ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ConversionFailure(message: "Unable to inspect this FFmpeg executable.") }
        return String(decoding: data, as: UTF8.self)
    }
}

/// App bundles never execute an engine from preferences, PATH, or a downloaded location.
enum EngineLocation {
    static var isAppBundle: Bool { Bundle.main.bundleURL.pathExtension == "app" }
    static func discover(in bundle: Bundle = .main) -> URL? {
        let embedded = bundle.bundleURL.appendingPathComponent("Contents/Helpers/ffmpeg")
        if FileManager.default.isExecutableFile(atPath: embedded.path) { return embedded }
        guard bundle.bundleURL.pathExtension != "app" else { return nil }
        // SwiftPM and integration-test executables are development tools only.
        let candidates = ["build/engine/universal/ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0) }
    }
}

/// Retains a user-selected sandbox extension until all queued/async users release it.
final class FileAccess {
    let url: URL
    private let scoped: Bool
    init(_ url: URL) { self.url = url; scoped = url.startAccessingSecurityScopedResource() }
    deinit { if scoped { url.stopAccessingSecurityScopedResource() } }
}
