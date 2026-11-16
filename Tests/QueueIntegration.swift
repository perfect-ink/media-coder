import Foundation

@main
struct QueueIntegration {
    @MainActor
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("media-coder-queue-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("first.avi")
        let second = folder.appendingPathComponent("second.avi")
        let ffmpeg = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc2=size=320x240:rate=24", "-t", "0.2", "-c:v", "mpeg4", source.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { fatalError("Fixture failed") }
        try FileManager.default.copyItem(at: source, to: second)
        let model = ConverterModel()
        while model.isInspecting { try await Task.sleep(nanoseconds: 10_000_000) }
        assert(model.ffmpegURL == EngineLocation.discover())
        let app = folder.appendingPathComponent("MissingEngine.app")
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: [String: String] = ["CFBundleIdentifier": "test.missing-engine", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        let bundle = Bundle(url: app)!
        assert(EngineLocation.discover(in: bundle) == nil, "App bundles must not fall back to Homebrew")
        let bundledCodecs: Set<String> = ["h264_videotoolbox", "hevc_videotoolbox", "aac"]
        assert(OutputFormat.mp4.isSupported(by: bundledCodecs))
        assert(OutputFormat.hevc.isSupported(by: bundledCodecs))
        assert(!OutputFormat.mp4.isSupported(by: ["h264_videotoolbox"]))
        assert(!OutputFormat.webm.isSupported(by: bundledCodecs))
        let softwareAllowed = OutputFormat.mp4.arguments(encoders: bundledCodecs)
        assert(softwareAllowed.contains("h264_videotoolbox") && !softwareAllowed.contains("libx264"))
        assert(softwareAllowed[softwareAllowed.firstIndex(of: "-allow_sw")! + 1] == "1")
        assert(softwareAllowed[softwareAllowed.firstIndex(of: "-require_sw")! + 1] == "1")
        assert(model.hardwareAcceleration, "Hardware acceleration should default to enabled")
        assert(model.usesHardwareAcceleration == model.canUseHardwareAcceleration)
        model.format = .webm
        assert(!model.usesHardwareAcceleration)
        model.format = .mp4
        model.hardwareAcceleration = false
        model.add([source, second])
        let firstID = model.jobs[0].id
        let secondID = model.jobs[1].id
        model.place([second], before: firstID)
        assert(model.jobs.map(\.id) == [secondID, firstID])
        assert(model.selectedJobID == firstID)
        model.place([second], before: nil)
        assert(model.jobs.map(\.id) == [firstID, secondID])
        model.place([source], before: firstID)
        assert(model.jobs.map(\.id) == [firstID, secondID])
        model.add([source])
        assert(model.jobs.count == 2)
        let third = folder.appendingPathComponent("third.avi")
        let fourth = folder.appendingPathComponent("fourth.avi")
        try FileManager.default.copyItem(at: source, to: third)
        try FileManager.default.copyItem(at: source, to: fourth)
        model.place([third, fourth, third], before: secondID)
        assert(model.jobs.map(\.source) == [source, third, fourth, second])
        model.remove(model.jobs[1].id)
        model.remove(model.jobs[1].id)
        for size in VideoSize.allCases {
            let output = model.uniqueOutput(source: source, folder: folder, format: .mp4, size: size)
            let suffix = size == .custom ? "1920x1080" : size.filenameSuffix
            assert(output.lastPathComponent == "first-converted-\(suffix).mp4")
        }
        assert(OutputFormat.mp3.isSupported(by: ["libmp3lame"]))
        for size in VideoSize.allCases {
            assert(model.uniqueOutput(source: source, folder: folder, format: .mp3, size: size).lastPathComponent == "first-audio.mp3")
        }
        let audioOutput = folder.appendingPathComponent("first-audio.mp3")
        try Data().write(to: audioOutput)
        assert(model.uniqueOutput(source: source, folder: folder, format: .mp3, size: .hd).lastPathComponent == "first-audio-2.mp3")
        let duplicate = model.uniqueOutput(source: source, folder: folder, format: .mp4, size: .hd)
        try Data().write(to: duplicate)
        assert(model.uniqueOutput(source: source, folder: folder, format: .mp4, size: .hd).lastPathComponent == "first-converted-720p-2.mp4")
        try FileManager.default.removeItem(at: duplicate)
        model.size = .custom
        model.customWidth = "invalid"
        assert(!model.hasValidSize)
        model.start()
        assert(!model.isConverting)
        model.customWidth = "641"
        model.customHeight = "359"
        assert(model.hasValidSize)
        assert(model.uniqueOutput(source: source, folder: folder, format: .mp4, size: .custom).lastPathComponent == "first-converted-641x359.mp4")
        model.size = .hd
        model.start()
        while model.jobs.first(where: { $0.id == firstID })?.status == .waiting {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        model.place([source], before: nil)
        while model.isConverting { try await Task.sleep(nanoseconds: 10_000_000) }
        assert(model.jobs.first(where: { $0.id == firstID })?.status == .done)
        assert(model.jobs.first(where: { $0.id == secondID })?.status == .waiting)
        model.place([source], before: secondID)
        assert(model.jobs[0].status == .done, "First should complete")
        assert(model.jobs[1].status == .waiting, "Next must wait for user action")
        assert(model.jobs[0].output?.lastPathComponent == "first-converted-720p.mp4")
        model.start()
        while model.isConverting { try await Task.sleep(nanoseconds: 10_000_000) }
        assert(model.jobs[1].status == .done, "Next video should complete")
        assert(model.selectedJobID == model.jobs[1].id)
        print("PASS size suffixes, collision names, pause after completion, next video, and selection")
    }
}
