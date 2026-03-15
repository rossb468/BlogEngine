import Foundation

// MARK: - Data Model

struct Post {
    let title: String
    let date: String
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

// MARK: - HTML Templates

let siteTitle = "My Blog"

let cssStyles = """
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
           max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; color: #333; }
    header { border-bottom: 2px solid #eee; padding-bottom: 10px; margin-bottom: 20px; }
    header h1 { margin-bottom: 5px; }
    nav { font-size: 0.9em; }
    nav a { color: #0066cc; text-decoration: none; margin-right: 15px; }
    nav a:hover { text-decoration: underline; }
    a { color: #0066cc; }
    pre { background: #f5f5f5; padding: 15px; border-radius: 5px; overflow-x: auto; }
    code { background: #f5f5f5; padding: 2px 5px; border-radius: 3px; font-size: 0.9em; }
    pre code { background: none; padding: 0; }
    .post-list { list-style: none; padding: 0; }
    .post-list li { padding: 10px 0; border-bottom: 1px solid #eee; }
    .post-date { color: #888; font-size: 0.85em; margin-right: 10px; }
    footer { margin-top: 40px; padding-top: 10px; border-top: 1px solid #eee;
             font-size: 0.8em; color: #888; }
"""

func pageTemplate(title: String, content: String) -> String {
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(title) - \(siteTitle)</title>
        <style>\(cssStyles)</style>
    </head>
    <body>
        <header>
            <h1>\(siteTitle)</h1>
            <nav><a href="index.html">Home</a></nav>
        </header>
        <main>
            \(content)
        </main>
        <footer>Generated by BlogEngine</footer>
    </body>
    </html>
    """
}

func postPage(post: Post) -> String {
    var content = "<article>"
    if !post.date.isEmpty {
        content += "<p class=\"post-date\">\(post.date)</p>"
    }
    content += "<h1>\(post.title)</h1>"
    content += post.htmlContent
    content += "</article>"
    return pageTemplate(title: post.title, content: content)
}

func indexPage(posts: [Post]) -> String {
    var content = "<h2>Posts</h2>\n<ul class=\"post-list\">"
    for post in posts {
        let datePart = post.date.isEmpty ? "" : "<span class=\"post-date\">\(post.date)</span>"
        content += "\n<li>\(datePart)<a href=\"\(post.slug).html\">\(post.title)</a></li>"
    }
    content += "\n</ul>"
    return pageTemplate(title: "Home", content: content)
}
