import Foundation

// MARK: - Build Errors

public enum BuildError: LocalizedError {
    case invalidInputDirectory(String)
    case noConfigFound

    public var errorDescription: String? {
        switch self {
        case .invalidInputDirectory(let path):
            return "Input directory does not exist: \(path)"
        case .noConfigFound:
            return "No site.json or site.conf found in input directory"
        }
    }
}

// MARK: - Site Builder

/// Encapsulates the full site generation pipeline. Works for both CLI and GUI:
/// assign `onLog` to receive progress messages, then call `build(...)`.
public class SiteBuilder {

    /// Called with each log message as the build progresses.
    public var onLog: ((String) -> Void)?

    public init() {}

    /// Generate a static site from Markdown source files.
    /// - Parameters:
    ///   - inputPath: Directory containing .md files and site.json / site.conf.
    ///   - outputPath: Directory where HTML output will be written.
    ///   - templatesPath: Directory containing page.html, post.html, index.html, style.css.
    public func build(inputPath: String, outputPath: String, templatesPath: String) throws {
        let fm = FileManager.default

        // Validate input directory
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: inputPath, isDirectory: &isDir), isDir.boolValue else {
            throw BuildError.invalidInputDirectory(inputPath)
        }

        // Load config — prefer site.json, fall back to site.conf
        let jsonConfigPath = (inputPath as NSString).appendingPathComponent("site.json")
        let confConfigPath = (inputPath as NSString).appendingPathComponent("site.conf")
        let configPath: String
        if fm.fileExists(atPath: jsonConfigPath) {
            configPath = jsonConfigPath
            log("Using config: site.json")
        } else if fm.fileExists(atPath: confConfigPath) {
            configPath = confConfigPath
            log("Using config: site.conf (legacy format)")
        } else {
            throw BuildError.noConfigFound
        }
        _ = try SiteConfig(file: configPath)

        // Load templates
        let templates = try Templates(directory: templatesPath)
        log("Loaded templates from: \(templatesPath)")

        // Create output directory
        try fm.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

        // Copy CSS — prefer input/style.css, fall back to template's style.css
        let inputCssPath = (inputPath as NSString).appendingPathComponent("style.css")
        let outputCssPath = (outputPath as NSString).appendingPathComponent("style.css")
        if fm.fileExists(atPath: outputCssPath) {
            try fm.removeItem(atPath: outputCssPath)
        }
        if fm.fileExists(atPath: inputCssPath) {
            try fm.copyItem(atPath: inputCssPath, toPath: outputCssPath)
            log("Copied style.css from input directory")
        } else {
            try templates.css.write(toFile: outputCssPath, atomically: true, encoding: .utf8)
            log("Copied style.css from templates")
        }

        // Copy images directory if present
        let inputImagesPath = (inputPath as NSString).appendingPathComponent("images")
        let outputImagesPath = (outputPath as NSString).appendingPathComponent("images")
        var imagesIsDir: ObjCBool = false
        if fm.fileExists(atPath: inputImagesPath, isDirectory: &imagesIsDir), imagesIsDir.boolValue {
            if fm.fileExists(atPath: outputImagesPath) {
                try fm.removeItem(atPath: outputImagesPath)
            }
            try fm.copyItem(atPath: inputImagesPath, toPath: outputImagesPath)
            log("Copied images/ directory")
        }

        // Discover and parse posts from Posts/ directory (case-insensitive)
        var posts: [Post] = []
        let inputContents = try fm.contentsOfDirectory(atPath: inputPath)
        let postsDir = inputContents.first { $0.lowercased() == "posts" }
        if let postsDir = postsDir {
            let postsDirPath = (inputPath as NSString).appendingPathComponent(postsDir)
            var postsIsDir: ObjCBool = false
            if fm.fileExists(atPath: postsDirPath, isDirectory: &postsIsDir), postsIsDir.boolValue {
                let mdFiles = try fm.contentsOfDirectory(atPath: postsDirPath)
                    .filter { $0.hasSuffix(".md") }
                    .sorted()
                for filename in mdFiles {
                    let filePath = (postsDirPath as NSString).appendingPathComponent(filename)
                    let content = try String(contentsOfFile: filePath, encoding: .utf8)
                    posts.append(parsePost(filename: filename, content: content))
                }
                log("Found \(posts.count) post(s) in \(postsDir)/")
            }
        } else {
            log("Warning: No Posts directory found in \(inputPath)")
        }

        // Sort by date descending, then slug ascending
        posts.sort { a, b in
            if !a.date.isEmpty && !b.date.isEmpty { return a.date > b.date }
            return a.slug < b.slug
        }

        // Discover and parse pages from pages/ subdirectory
        var pages: [Page] = []
        let pagesPath = (inputPath as NSString).appendingPathComponent("pages")
        var pagesIsDir: ObjCBool = false
        if fm.fileExists(atPath: pagesPath, isDirectory: &pagesIsDir), pagesIsDir.boolValue {
            let pageFiles = try fm.contentsOfDirectory(atPath: pagesPath)
                .filter { $0.hasSuffix(".md") }
                .sorted()
            for filename in pageFiles {
                let filePath = (pagesPath as NSString).appendingPathComponent(filename)
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                pages.append(parsePage(filename: filename, content: content))
            }
        }

        // Build navigation links from pages
        let navLinks = pages.map { render(templates.navLink, ["slug": $0.slug, "title": $0.title]) }.joined()

        // Render individual post pages
        for post in posts {
            let html = postPage(post: post, templates: templates, navLinks: navLinks)
            let outFile = (outputPath as NSString).appendingPathComponent("\(post.slug).html")
            try html.write(toFile: outFile, atomically: true, encoding: .utf8)
            log("Generated: \(post.slug).html")
        }

        // Render static pages
        for page in pages {
            let html = staticPage(page: page, templates: templates, navLinks: navLinks)
            let outFile = (outputPath as NSString).appendingPathComponent("\(page.slug).html")
            try html.write(toFile: outFile, atomically: true, encoding: .utf8)
            log("Generated: \(page.slug).html")
        }

        // Render index page
        let html = indexPage(posts: posts, templates: templates, navLinks: navLinks)
        let indexFile = (outputPath as NSString).appendingPathComponent("index.html")
        try html.write(toFile: indexFile, atomically: true, encoding: .utf8)
        log("Generated: index.html")

        log("Done! \(posts.count) post(s) and \(pages.count) page(s) generated in \(outputPath)")
    }

    private func log(_ message: String) {
        onLog?(message)
    }
}
