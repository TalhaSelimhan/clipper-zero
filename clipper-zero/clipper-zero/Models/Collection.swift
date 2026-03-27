import SwiftData
import Foundation

// TODO: ClipCollection is defined but collection management (create, assign clips) is not yet implemented in the UI.
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
