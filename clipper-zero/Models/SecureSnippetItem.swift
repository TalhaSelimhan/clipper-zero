import SwiftData
import Foundation

@Model
final class SecureSnippetItem {
    var id: UUID = UUID()
    var name: String = ""
    var encryptedValue: Data = Data()
    var createdAt: Date = Date()
    var expiresAt: Date?
    var sortOrder: Int = 0

    init(id: UUID = UUID(), name: String, encryptedValue: Data,
         expiresAt: Date? = nil, sortOrder: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.encryptedValue = encryptedValue
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.sortOrder = sortOrder
    }
}

extension Sequence where Element == SecureSnippetItem {
    var maxSortOrder: Int { map(\.sortOrder).max() ?? -1 }
}
