import Foundation
import SwiftData

enum SearchResult: Identifiable {
    case clip(ClipItem)
    case snippet(SnippetItem)
    case secureSnippet(SecureSnippetItem)

    var id: String {
        switch self {
        case .clip(let item): return "clip-\(item.id)"
        case .snippet(let item): return "snippet-\(item.id)"
        case .secureSnippet(let item): return "secureSnippet-\(item.id)"
        }
    }

    func delete(from context: ModelContext) {
        switch self {
        case .clip(let clip): context.delete(clip)
        case .snippet(let snippet): context.delete(snippet)
        case .secureSnippet(let snippet): context.delete(snippet)
        }
    }
}
