import Foundation
import SwiftData

@Model
final class SnippetItem {
    var id: UUID
    var name: String
    var value: String
    var createdAt: Date
    var sortOrder: Int

    init(name: String, value: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.value = value
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}
