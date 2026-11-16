import Foundation

/// Runs inside a signed sandboxed app with no Homebrew engine discovery.
@main
struct BundledIntegration {
    static func main() async throws {
        guard let executable = EngineLocation.discover(),
              let source = Bundle.main.url(forResource: "fixture", withExtension: "avi") else {
            fatalError("Missing embedded engine or fixture")
        }
        let capabilities = try await CodecCapabilities.inspect(executable)
        assert(capabilities.decoders.contains("h264"))
        assert(!capabilities.encoders.contains("libx264"))
        assert(OutputFormat.mp4.isSupported(by: capabilities.encoders))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for format in OutputFormat.allCases where format.isSupported(by: capabilities.encoders) {
            let output = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(format.fileExtension)
            try await ConversionEngine().convert(executable: executable, source: source, destination: output,
                                                 format: format, size: .small, hardwareAcceleration: format.hardwareEncoder != nil, encoders: capabilities.encoders) { _ in }
            let specs = try await SourceSpecs.inspect(executable: executable, source: output)
            assert(specs.audio != "No audio track")
            if !format.isAudioOnly { assert(specs.resolution == "160 × 120") }
            print("PASS sandboxed bundled conversion: \(format.rawValue)")
        }
    }
}
