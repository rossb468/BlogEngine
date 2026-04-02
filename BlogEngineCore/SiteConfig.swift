import Foundation

// MARK: - Site Configuration

public struct SiteConfig {
    public var values: [String: String]

    /// Keys that are user-editable in the GUI.
    public static let editableKeys: [(key: String, label: String)] = [
        ("site_title", "Site Title"),
        ("github", "GitHub Username"),
        ("email", "Email Address"),
    ]

    public init() {
        values = [:]
    }

    /// Load config from a file. Tries JSON first (site.json), then falls back to
    /// the legacy key=value format (site.conf).
    public init(file: String) throws {
        let url = URL(fileURLWithPath: file)
        let data = try Data(contentsOf: url)

        // Try JSON first (site.json)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            values = json
            return
        }

        // Fall back to legacy key=value format (site.conf)
        let content = String(data: data, encoding: .utf8) ?? ""
        var dict: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if let eqIndex = trimmed.firstIndex(of: "=") {
                let key = trimmed[trimmed.startIndex..<eqIndex].trimmingCharacters(in: .whitespaces)
                let value = trimmed[trimmed.index(after: eqIndex)...].trimmingCharacters(in: .whitespaces)
                dict[key] = value
            }
        }
        values = dict
    }

    public func get(_ key: String, default fallback: String = "") -> String {
        values[key] ?? fallback
    }

    /// Save config as JSON (site.json).
    public func saveAsJSON(to path: String) throws {
        let data = try JSONSerialization.data(
            withJSONObject: values,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: URL(fileURLWithPath: path))
    }
}

