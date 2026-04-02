import Foundation
import BlogEngineCore

let args = CommandLine.arguments

guard args.count == 4 else {
    let name = (args.first! as NSString).lastPathComponent
    print("Usage: \(name) <input-directory> <output-directory> <templates-directory>")
    print("  input-directory:     Path to folder containing .md files")
    print("  output-directory:    Path to folder where HTML files will be written")
    print("  templates-directory: Path to folder containing template files")
    exit(1)
}

let builder = SiteBuilder()
builder.onLog = { print($0) }

do {
    try builder.build(
        inputPath: args[1],
        outputPath: args[2],
        templatesPath: args[3]
    )
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
