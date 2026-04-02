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

public func render(_ template: String, _ values: [String: String]) -> String {
    var result = template
    for (key, value) in values {
        result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
    }
    return result
}

public func postPage(post: Post, templates: Templates, contact: String, config: SiteConfig) -> String {
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

public func indexPage(posts: [Post], templates: Templates, contact: String, config: SiteConfig, intro: String = "") -> String {
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

public func staticPage(page: Page, templates: Templates, contact: String, config: SiteConfig) -> String {
    var values = config.values
    values["title"] = page.title
    values["contact"] = contact
    values["content"] = page.htmlContent
    return render(templates.page, values)
}
