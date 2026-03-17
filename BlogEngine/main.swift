import Foundation

let args = CommandLine.arguments

guard args.count == 4 else {
    let name = (args.first! as NSString).lastPathComponent
    print("Usage: \(name) <input-directory> <output-directory> <templates-directory>")
    print("  input-directory:    Path to folder containing .md files")
    print("  output-directory:   Path to folder where HTML files will be written")
    print("  templates-directory: Path to folder containing template files")
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2]
let templatesPath = args[3]
let fm = FileManager.default

do {
    // Validate input directory
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: inputPath, isDirectory: &isDir), isDir.boolValue else {
        print("Error: Input directory does not exist: \(inputPath)")
        exit(1)
    }

    // Load config
    let configPath = (inputPath as NSString).appendingPathComponent("site.conf")
    var config = try SiteConfig(file: configPath)

    // Load header
    let headerPath = (inputPath as NSString).appendingPathComponent("header.md")
    if fm.fileExists(atPath: headerPath) {
        let headerMd = try String(contentsOfFile: headerPath, encoding: .utf8)
        config.values["header"] = parseMarkdown(headerMd)
    } else {
        config.values["header"] = "<h1>\(config.get("site_title", default: "My Blog"))</h1>"
    }

    // Load achievements — split by ### headings into columns
    let achievementsPath = (inputPath as NSString).appendingPathComponent("achievements.md")
    if fm.fileExists(atPath: achievementsPath) {
        let achievementsMd = try String(contentsOfFile: achievementsPath, encoding: .utf8)
        let sections = achievementsMd.components(separatedBy: "\n### ")
        var columns = ""
        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let md = trimmed.hasPrefix("### ") ? trimmed : "### " + trimmed
            columns += "<div class=\"achievement-col\">" + parseMarkdown(md) + "</div>"
        }
        config.values["achievements"] = "<div class=\"achievements\">" + columns + "</div>"
    } else {
        config.values["achievements"] = ""
    }

    // Load templates
    let templates = try Templates(directory: templatesPath)

    // Create output directory
    try fm.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

    // Copy CSS file to output (prefer input/style.css, fall back to templates)
    let inputCssPath = (inputPath as NSString).appendingPathComponent("style.css")
    let outputCssPath = (outputPath as NSString).appendingPathComponent("style.css")
    if fm.fileExists(atPath: inputCssPath) {
        try fm.copyItem(atPath: inputCssPath, toPath: outputCssPath)
    } else {
        try templates.css.write(toFile: outputCssPath, atomically: true, encoding: .utf8)
    }

    // Find markdown files
    let files = try fm.contentsOfDirectory(atPath: inputPath)
    let reserved: Set<String> = ["header.md", "intro.md", "achievements.md"]
    let mdFiles = files.filter { $0.hasSuffix(".md") && !reserved.contains($0) }.sorted()

    if mdFiles.isEmpty {
        print("No .md files found in \(inputPath)")
    }

    // Parse all posts
    var posts: [Post] = []
    for filename in mdFiles {
        let filePath = (inputPath as NSString).appendingPathComponent(filename)
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        let post = parsePost(filename: filename, content: content)
        posts.append(post)
    }

    // Sort by date descending, then slug ascending
    posts.sort { a, b in
        if !a.date.isEmpty && !b.date.isEmpty {
            return a.date > b.date
        }
        return a.slug < b.slug
    }

    // Parse pages from pages/ subdirectory
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

    let contact = buildContact(config: config)

    // Write individual post pages
    for post in posts {
        let html = postPage(post: post, templates: templates, contact: contact, config: config)
        let outFile = (outputPath as NSString).appendingPathComponent("\(post.slug).html")
        try html.write(toFile: outFile, atomically: true, encoding: .utf8)
        print("  Generated: \(post.slug).html")
    }

    // Write static pages
    for page in pages {
        let html = staticPage(page: page, templates: templates, contact: contact, config: config)
        let outFile = (outputPath as NSString).appendingPathComponent("\(page.slug).html")
        try html.write(toFile: outFile, atomically: true, encoding: .utf8)
        print("  Generated: \(page.slug).html")
    }

    // Load intro for index page
    var intro = ""
    let introPath = (inputPath as NSString).appendingPathComponent("intro.md")
    if fm.fileExists(atPath: introPath) {
        let introMd = try String(contentsOfFile: introPath, encoding: .utf8)
        intro = parseMarkdown(introMd)
    }

    // Write index page
    let html = indexPage(posts: posts, templates: templates, contact: contact, config: config, intro: intro)
    let indexFile = (outputPath as NSString).appendingPathComponent("index.html")
    try html.write(toFile: indexFile, atomically: true, encoding: .utf8)
    print("  Generated: index.html")

    print("Done! \(posts.count) post(s) and \(pages.count) page(s) generated in \(outputPath)")
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
