import Foundation
import Observation
import BlogEngineCore

/// Observable wrapper around ``SiteBuilder`` for use with SwiftUI.
/// Manages security-scoped resource access and collects log messages for display.
@Observable
@MainActor
class SiteGenerator {
    var logMessages: [String] = []
    var isGenerating = false

    func generate(inputURL: URL, outputURL: URL, templatesURL: URL) async {
        logMessages = []
        isGenerating = true
        defer { isGenerating = false }

        // Acquire security-scoped access for the sandbox
        let inputAccess = inputURL.startAccessingSecurityScopedResource()
        let outputAccess = outputURL.startAccessingSecurityScopedResource()
        let templatesAccess = templatesURL.startAccessingSecurityScopedResource()
        defer {
            if inputAccess { inputURL.stopAccessingSecurityScopedResource() }
            if outputAccess { outputURL.stopAccessingSecurityScopedResource() }
            if templatesAccess { templatesURL.stopAccessingSecurityScopedResource() }
        }

        let builder = SiteBuilder()
        builder.onLog = { [weak self] message in
            self?.logMessages.append(message)
        }

        do {
            try builder.build(
                inputPath: inputURL.path,
                outputPath: outputURL.path,
                templatesPath: templatesURL.path
            )
        } catch {
            logMessages.append("Error: \(error.localizedDescription)")
        }
    }
}
