import SwiftUI

// MARK: - ClipContentType UI Extensions

extension ClipContentType {
    var badge: String {
        switch self {
        case .text: return "TXT"
        case .richText: return "RTF"
        case .image: return "IMG"
        case .file: return "FILE"
        case .color: return "CLR"
        case .link: return "URL"
        }
    }

    var badgeColor: Color {
        switch self {
        case .text: return .purple
        case .richText: return .purple
        case .image: return .green
        case .file: return .gray
        case .color: return .yellow
        case .link: return .blue
        }
    }

    var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .file: return "doc"
        case .color: return "paintpalette"
        case .link: return "link"
        }
    }
}
