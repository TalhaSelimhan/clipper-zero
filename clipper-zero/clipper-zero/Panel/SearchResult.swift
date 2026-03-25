import Foundation

enum SearchResult: Identifiable {
    case clip(ClipItem)
    case snippet(SnippetItem)

    var id: String {
        switch self {
        case .clip(let item): return "clip-\(item.id)"
        case .snippet(let item): return "snippet-\(item.id)"
        }
    }
}
