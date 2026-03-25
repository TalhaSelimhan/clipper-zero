import SwiftData
import Foundation

enum ClipContentType: String, Codable, CaseIterable {
    case text
    case richText
    case image
    case file
    case color
    case link
}

@Model
final class ClipItem {
    var id: UUID
    @Attribute(.externalStorage) var content: Data
    var contentType: ClipContentType
    var plainText: String?
    var sourceAppBundle: String?
    var sourceAppName: String?
    var createdAt: Date
    var isPinned: Bool
    @Attribute(.externalStorage) var previewData: Data?

    @Relationship(deleteRule: .nullify) var collections: [ClipCollection]?

    init(
        content: Data,
        contentType: ClipContentType,
        plainText: String? = nil,
        sourceAppBundle: String? = nil,
        sourceAppName: String? = nil,
        isPinned: Bool = false,
        previewData: Data? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.contentType = contentType
        self.plainText = plainText
        self.sourceAppBundle = sourceAppBundle
        self.sourceAppName = sourceAppName
        self.createdAt = Date()
        self.isPinned = isPinned
        self.previewData = previewData
    }
}
