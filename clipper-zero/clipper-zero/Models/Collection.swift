import SwiftData
import Foundation

@Model
final class ClipCollection {
    var id: UUID
    var name: String
    var icon: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ClipItem.collections)
    var items: [ClipItem]?

    init(name: String, icon: String = "folder") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.createdAt = Date()
        self.items = []
    }
}
