import Foundation
import SwiftData

@MainActor
enum SelectionTrackingService {
    static func markUsed(_ result: SearchResult, in context: ModelContext) {
        switch result {
        case .clip(let clip):
            markUsed(clip, in: context)
        case .snippet(let snippet):
            promoteSnippet(id: snippet.id, in: context)
        case .secureSnippet(let snippet):
            promoteSnippet(id: snippet.id, in: context)
        }
    }

    static func markUsed(_ clip: ClipItem, in context: ModelContext) {
        clip.createdAt = .now
        try? context.save()
    }

    private static func promoteSnippet(id targetID: UUID, in context: ModelContext) {
        let regularDescriptor = FetchDescriptor<SnippetItem>(sortBy: [SortDescriptor(\.sortOrder)])
        let secureDescriptor = FetchDescriptor<SecureSnippetItem>(sortBy: [SortDescriptor(\.sortOrder)])

        guard let regularSnippets = try? context.fetch(regularDescriptor),
              let secureSnippets = try? context.fetch(secureDescriptor) else { return }

        var merged = (regularSnippets.map(AnySnippet.regular) + secureSnippets.map(AnySnippet.secure))
            .sorted(by: snippetSort)

        guard let targetIndex = merged.firstIndex(where: { $0.id == targetID }) else { return }

        let target = merged.remove(at: targetIndex)
        merged.insert(target, at: 0)

        var didChange = false
        for (index, snippet) in merged.enumerated() where snippet.sortOrder != index {
            snippet.assignSortOrder(index)
            didChange = true
        }

        if didChange {
            try? context.save()
        }
    }

    private static func snippetSort(lhs: AnySnippet, rhs: AnySnippet) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private enum AnySnippet {
    case regular(SnippetItem)
    case secure(SecureSnippetItem)

    var id: UUID {
        switch self {
        case .regular(let snippet):
            return snippet.id
        case .secure(let snippet):
            return snippet.id
        }
    }

    var createdAt: Date {
        switch self {
        case .regular(let snippet):
            return snippet.createdAt
        case .secure(let snippet):
            return snippet.createdAt
        }
    }

    var sortOrder: Int {
        switch self {
        case .regular(let snippet):
            return snippet.sortOrder
        case .secure(let snippet):
            return snippet.sortOrder
        }
    }

    func assignSortOrder(_ value: Int) {
        switch self {
        case .regular(let snippet):
            snippet.sortOrder = value
        case .secure(let snippet):
            snippet.sortOrder = value
        }
    }
}
