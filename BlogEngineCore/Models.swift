import Foundation

// MARK: - Data Models

public struct Post {
    public let title: String
    public let date: String
    public let slug: String
    public let htmlContent: String

    public init(title: String, date: String, slug: String, htmlContent: String) {
        self.title = title
        self.date = date
        self.slug = slug
        self.htmlContent = htmlContent
    }
}

public struct Page {
    public let title: String
    public let slug: String
    public let htmlContent: String

    public init(title: String, slug: String, htmlContent: String) {
        self.title = title
        self.slug = slug
        self.htmlContent = htmlContent
    }
}
