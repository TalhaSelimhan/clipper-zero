import Foundation
import SwiftData

enum SearchResult: Identifiable {
    case clip(ClipItem)
    case snippet(SnippetItem)

    var id: String {
        switch self {
        case .clip(let item): return "clip-\(item.id)"
        case .snippet(let item): return "snippet-\(item.id)"
        }
    }

    func delete(from context: ModelContext) {
        switch self {
        case .clip(let clip): context.delete(clip)
        case .snippet(let snippet): context.delete(snippet)
        }
    }
}
