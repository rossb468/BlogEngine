import Foundation

// MARK: - Templates

public struct Templates {
    public let page: String
    public let post: String
    public let index: String
    public let css: String
    public init(directory: String) throws {
        func load(_ name: String) throws -> String {
            let path = (directory as NSString).appendingPathComponent(name)
            return try String(contentsOfFile: path, encoding: .utf8)
        }
        page = try load("page.html")
        post = try load("post.html")
        index = try load("index.html")
        css = try load("style.css")
    }
}

// MARK: - Rendering

public func render(_ template: String, _ values: [String: String], inputPath: String? = nil) -> String {
    var result = template

    // Resolve {{*.md}} placeholders by loading and parsing markdown files from inputPath
    if let inputPath = inputPath {
        let pattern = try! NSRegularExpression(pattern: "\\{\\{([^}]+\\.md)\\}\\}")
        let matches = pattern.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: result) else { continue }
            let filename = String(result[range])
            let filePath = (inputPath as NSString).appendingPathComponent(filename)
            var html = ""
            if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                html = parseMarkdown(content)
            }
            result = result.replacingOccurrences(of: "{{\(filename)}}", with: html)
        }
    }

    // Replace remaining placeholders from the values dictionary
    for (key, value) in values {
        result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
    }
    return result
}

public func postPage(post: Post, templates: Templates) -> String {
    return render(templates.page, ["content": post.htmlContent])
}

public func indexPage(posts: [Post], templates: Templates) -> String {
    var postEntries = ""
    for post in posts {
        postEntries += render(templates.post, [
            "body": post.htmlContent,
            "slug": post.slug
        ])
    }
    let content = render(templates.index, ["post_list": postEntries])
    return render(templates.page, ["content": content])
}

public func staticPage(page: Page, templates: Templates) -> String {
    return render(templates.page, ["content": page.htmlContent])
}
