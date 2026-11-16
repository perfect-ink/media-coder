import SwiftUI
import AppKit

struct CodecSupportView: View {
    @ObservedObject var model: ConverterModel
    @State private var search = ""
    @State private var showEncoders = false

    private var names: [String] {
        let values = showEncoders ? model.capabilities?.encoders : model.capabilities?.decoders
        return (values ?? []).filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                FilmIconArtwork(size: 40)
                Text("Codec support").font(.title2.bold())
            }
            Text("The video engine and its codecs are included with Media Coder. Conversion works offline.")
                .font(.callout).foregroundStyle(.secondary)
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Active engine", systemImage: "cpu")
                        Spacer()
                        if model.isInspecting { ProgressView().controlSize(.small) }
                    }
                    Text(model.capabilities?.version ?? (model.ffmpegURL == nil ? "Bundled engine missing" : "Checking engine…"))
                        .font(.caption).textSelection(.enabled)
                    if let url = model.ffmpegURL {
                        Text(url.path).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    if let error = model.capabilityError { Text(error).font(.caption).foregroundStyle(.red) }
                    if let capabilities = model.capabilities {
                        Text("\(capabilities.decoders.count) decoders · \(capabilities.encoders.count) encoders · \(model.availableFormats.count) output presets")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            HStack {
                Picker("Codec list", selection: $showEncoders) {
                    Text("Read / decode").tag(false)
                    Text("Write / encode").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 260)
                TextField("Search codecs", text: $search).textFieldStyle(.roundedBorder)
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 7) {
                    ForEach(names, id: \.self) { Text($0).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                }.padding(8)
                if names.isEmpty { Text("No matching codecs").foregroundStyle(.secondary).padding() }
            }.background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Text("Videos stay on your Mac. No engine downloads are required.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let resources = Bundle.main.resourceURL?.appendingPathComponent("FFmpeg") {
                    Button("FFmpeg source & licenses") { NSWorkspace.shared.open(resources) }
                }
            }
        }.padding(24).frame(width: 690, height: 680)
    }
}
