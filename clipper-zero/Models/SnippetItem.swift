import Foundation
import SwiftData

@Model
final class SnippetItem {
    var id: UUID = UUID()
    var name: String = ""
    var value: String = ""
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    init(id: UUID = UUID(), name: String, value: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.value = value
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}

extension Sequence where Element == SnippetItem {
    var maxSortOrder: Int { map(\.sortOrder).max() ?? -1 }
}
