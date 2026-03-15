import Foundation

let args = CommandLine.arguments

guard args.count == 3 else {
    let name = (args.first! as NSString).lastPathComponent
    print("Usage: \(name) <input-directory> <output-directory>")
    print("  input-directory:  Path to folder containing .md files")
    print("  output-directory: Path to folder where HTML files will be written")
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2]
let fm = FileManager.default

do {
    // Validate input directory
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: inputPath, isDirectory: &isDir), isDir.boolValue else {
        print("Error: Input directory does not exist: \(inputPath)")
        exit(1)
    }

    // Create output directory
    try fm.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

    // Find markdown files
    let files = try fm.contentsOfDirectory(atPath: inputPath)
    let mdFiles = files.filter { $0.hasSuffix(".md") }.sorted()

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

    // Write individual post pages
    for post in posts {
        let html = postPage(post: post)
        let outFile = (outputPath as NSString).appendingPathComponent("\(post.slug).html")
        try html.write(toFile: outFile, atomically: true, encoding: .utf8)
        print("  Generated: \(post.slug).html")
    }

    // Write index page
    let html = indexPage(posts: posts)
    let indexFile = (outputPath as NSString).appendingPathComponent("index.html")
    try html.write(toFile: indexFile, atomically: true, encoding: .utf8)
    print("  Generated: index.html")

    print("Done! \(posts.count) post(s) generated in \(outputPath)")
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
