import SwiftUI
import BlogEngineCore

struct ContentView: View {
    @State private var generator = SiteGenerator()

    @State private var inputURL: URL?
    @State private var outputURL: URL?
    @State private var templatesURL: URL?

    @State private var siteConfig = SiteConfig()
    @State private var configStatus = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Blog Engine")
                .font(.title)
                .fontWeight(.bold)

            // Directory pickers
            DirectoryPicker(label: "Input Directory", url: $inputURL, bookmarkKey: "inputBookmark")
                .onChange(of: inputURL) { loadConfig() }
            DirectoryPicker(label: "Output Directory", url: $outputURL, bookmarkKey: "outputBookmark")
            DirectoryPicker(label: "Templates Directory", url: $templatesURL, bookmarkKey: "templatesBookmark")

            Divider()

            // Site configuration fields
            Text("Site Configuration")
                .font(.headline)

            ForEach(SiteConfig.editableKeys, id: \.key) { entry in
                ConfigField(label: entry.label, value: binding(for: entry.key))
            }

            HStack {
                Button("Save Config") {
                    saveConfig()
                }
                .disabled(inputURL == nil)

                if !configStatus.isEmpty {
                    Text(configStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Generate
            HStack {
                Button("Generate Site") {
                    saveConfig()
                    Task {
                        await generator.generate(
                            inputURL: inputURL!,
                            outputURL: outputURL!,
                            templatesURL: templatesURL!
                        )
                    }
                }
                .disabled(generator.isGenerating || inputURL == nil || outputURL == nil || templatesURL == nil)

                if generator.isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Button("Clear Log") {
                    generator.logMessages = []
                }
                .disabled(generator.logMessages.isEmpty)
            }

            // Log output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(generator.logMessages.enumerated()), id: \.offset) { index, message in
                            Text(message)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: generator.logMessages.count) {
                    if let last = generator.logMessages.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 550)
        .onAppear {
            inputURL = BookmarkManager.resolveBookmark(key: "inputBookmark")
            outputURL = BookmarkManager.resolveBookmark(key: "outputBookmark")
            templatesURL = BookmarkManager.resolveBookmark(key: "templatesBookmark")
            loadConfig()
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { siteConfig.values[key] ?? "" },
            set: { siteConfig.values[key] = $0 }
        )
    }

    private func loadConfig() {
        guard let url = inputURL else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let inputPath = url.path
        let jsonPath = (inputPath as NSString).appendingPathComponent("site.json")
        let confPath = (inputPath as NSString).appendingPathComponent("site.conf")

        if FileManager.default.fileExists(atPath: jsonPath),
           let config = try? SiteConfig(file: jsonPath) {
            siteConfig = config
            configStatus = "Loaded site.json"
        } else if FileManager.default.fileExists(atPath: confPath),
                  let config = try? SiteConfig(file: confPath) {
            siteConfig = config
            configStatus = "Loaded site.conf (legacy)"
        } else {
            siteConfig = SiteConfig()
            configStatus = "No config found — enter values and save"
        }
    }

    private func saveConfig() {
        guard let url = inputURL else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let jsonPath = (url.path as NSString).appendingPathComponent("site.json")
        do {
            try siteConfig.saveAsJSON(to: jsonPath)
            configStatus = "Saved site.json"
        } catch {
            configStatus = "Save failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Config Field

struct ConfigField: View {
    let label: String
    @Binding var value: String

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 140, alignment: .trailing)
            TextField(label, text: $value)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Bookmark Manager

enum BookmarkManager {
    static func saveBookmark(url: URL, key: String) {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save bookmark for \(key): \(error)")
        }
    }

    static func resolveBookmark(key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                saveBookmark(url: url, key: key)
            }
            return url
        } catch {
            print("Failed to resolve bookmark for \(key): \(error)")
            return nil
        }
    }
}

// MARK: - Directory Picker

struct DirectoryPicker: View {
    let label: String
    @Binding var url: URL?
    let bookmarkKey: String

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 140, alignment: .trailing)
            Text(url?.path ?? "No directory selected")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(url == nil ? .secondary : .primary)
            Button("Browse...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                if let existing = url {
                    panel.directoryURL = existing
                }
                if panel.runModal() == .OK, let selected = panel.url {
                    url = selected
                    BookmarkManager.saveBookmark(url: selected, key: bookmarkKey)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
