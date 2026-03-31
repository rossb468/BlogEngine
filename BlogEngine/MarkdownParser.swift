import Foundation

// MARK: - Data Model

struct Post {
    let title: String
    let date: String
    let slug: String
    let htmlContent: String
}

struct Page {
    let title: String
    let slug: String
    let htmlContent: String
}

// MARK: - Markdown Parsing

func parseInline(_ text: String) -> String {
    var result = text
    // HTML-escape
    result = result.replacingOccurrences(of: "&", with: "&amp;")
    result = result.replacingOccurrences(of: "<", with: "&lt;")
    result = result.replacingOccurrences(of: ">", with: "&gt;")
    // Inline code
    result = result.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
    // Bold
    result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
    // Italic
    result = result.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
    // Images (must come before links)
    result = result.replacingOccurrences(of: "!\\[([^\\]]*?)\\]\\(([^)]+)\\)", with: "<img src=\"$2\" alt=\"$1\">", options: .regularExpression)
    // Links
    result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)
    return result
}

func parseMarkdown(_ text: String) -> String {
    let lines = text.components(separatedBy: "\n")
    var result: [String] = []
    var i = 0

    while i < lines.count {
        let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

        // Code block
        if trimmed.hasPrefix("```") {
            i += 1
            var codeLines: [String] = []
            while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                let escaped = lines[i]
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                codeLines.append(escaped)
                i += 1
            }
            result.append("<pre><code>" + codeLines.joined(separator: "\n") + "</code></pre>")
            i += 1 // skip closing ```
            continue
        }

        // Heading
        if trimmed.hasPrefix("#") {
            var level = 0
            for ch in trimmed {
                if ch == "#" { level += 1 } else { break }
            }
            level = min(level, 6)
            let headingText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            result.append("<h\(level)>\(parseInline(headingText))</h\(level)>")
            i += 1
            continue
        }

        // Unordered list
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            var items: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("- ") {
                    items.append(parseInline(String(t.dropFirst(2))))
                } else if t.hasPrefix("* ") {
                    items.append(parseInline(String(t.dropFirst(2))))
                } else {
                    break
                }
                i += 1
            }
            let lis = items.map { "<li>\($0)</li>" }.joined(separator: "\n")
            result.append("<ul>\n\(lis)\n</ul>")
            continue
        }

        // Ordered list
        if trimmed.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
            var items: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if let range = t.range(of: "^\\d+\\. ", options: .regularExpression) {
                    items.append(parseInline(String(t[range.upperBound...])))
                } else {
                    break
                }
                i += 1
            }
            let lis = items.map { "<li>\($0)</li>" }.joined(separator: "\n")
            result.append("<ol>\n\(lis)\n</ol>")
            continue
        }

        // Blank line
        if trimmed.isEmpty {
            i += 1
            continue
        }

        // Paragraph
        var paragraphLines: [String] = []
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("```") || t.hasPrefix("- ") || t.hasPrefix("* ") || t.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                break
            }
            paragraphLines.append(lines[i].trimmingCharacters(in: .whitespaces))
            i += 1
        }
        if !paragraphLines.isEmpty {
            result.append("<p>\(parseInline(paragraphLines.joined(separator: " ")))</p>")
        }
    }

    return result.joined(separator: "\n")
}

// MARK: - Post Parsing

func parsePost(filename: String, content: String) -> Post {
    let name = filename.replacingOccurrences(of: ".md", with: "")
    var date = ""
    var slug = name

    // Try to extract YYYY-MM-DD prefix
    if name.count > 10,
       name.range(of: "^\\d{4}-\\d{2}-\\d{2}-", options: .regularExpression) != nil {
        date = String(name.prefix(10))
        slug = String(name.dropFirst(11))
    }

    let title = extractTitle(from: content, fallbackSlug: slug)
    let htmlContent = parseMarkdown(content)
    return Post(title: title, date: date, slug: slug, htmlContent: htmlContent)
}

func extractTitle(from content: String, fallbackSlug: String) -> String {
    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
            return String(trimmed.dropFirst(2))
        }
    }
    return fallbackSlug.replacingOccurrences(of: "-", with: " ").capitalized
}

func parsePage(filename: String, content: String) -> Page {
    let slug = filename.replacingOccurrences(of: ".md", with: "")
    let title = extractTitle(from: content, fallbackSlug: slug)
    let htmlContent = parseMarkdown(content)
    return Page(title: title, slug: slug, htmlContent: htmlContent)
}

// MARK: - Contact Links

func buildContact(config: SiteConfig) -> String {
    var links: [String] = []
    if let github = config.values["github"], !github.isEmpty {
        links.append("<a href=\"https://github.com/\(github)\">GitHub</a>")
    }
    if let email = config.values["email"], !email.isEmpty {
        links.append("<a href=\"mailto:\(email)\">\(email)</a>")
    }
    return links.joined(separator: " ")
}

// MARK: - Config

struct SiteConfig {
    var values: [String: String]

    init(file: String) throws {
        let content = try String(contentsOfFile: file, encoding: .utf8)
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

    func get(_ key: String, default fallback: String = "") -> String {
        values[key] ?? fallback
    }
}

// MARK: - Templates

struct Templates {
    let page: String
    let post: String
    let index: String
    let css: String

    init(directory: String) throws {
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

func render(_ template: String, _ values: [String: String]) -> String {
    var result = template
    for (key, value) in values {
        result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
    }
    return result
}

func postPage(post: Post, templates: Templates, contact: String, config: SiteConfig) -> String {
    let content = render(templates.post, [
        "date": post.date,
        "body": post.htmlContent
    ])
    var values = config.values
    values["title"] = post.title
    values["contact"] = contact
    values["content"] = content
    return render(templates.page, values)
}

func indexPage(posts: [Post], templates: Templates, contact: String, config: SiteConfig, intro: String = "") -> String {
    var postEntries = ""
    for post in posts {
        let datePart = post.date.isEmpty ? "" : "<p class=\"post-date\">\(post.date)</p>"
        postEntries += "<article class=\"post-entry\">\n"
        postEntries += datePart + "\n"
        postEntries += post.htmlContent + "\n"
        postEntries += "<a href=\"\(post.slug).html\" class=\"read-more\">Read more &rarr;</a>\n"
        postEntries += "</article>\n"
    }
    let content = render(templates.index, ["post_list": postEntries, "intro": intro])
    var values = config.values
    values["title"] = "Home"
    values["contact"] = contact
    values["content"] = content
    return render(templates.page, values)
}

func staticPage(page: Page, templates: Templates, contact: String, config: SiteConfig) -> String {
    var values = config.values
    values["title"] = page.title
    values["contact"] = contact
    values["content"] = page.htmlContent
    return render(templates.page, values)
}

