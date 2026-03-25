import SwiftUI
import AppKit

struct ClipRow: View {
    let clip: ClipItem
    let isSelected: Bool
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                typeBadge
                contentPreview
                Spacer()
                metadataView
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if isExpanded {
                expandedPreview
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Type Badge

    private var typeBadge: some View {
        Text(clip.contentType.badge)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(clip.contentType.badgeColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Content Preview

    private var contentPreview: some View {
        Group {
            switch clip.contentType {
            case .image:
                if let nsImage = NSImage(data: clip.previewData ?? clip.content) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 24)
                }
            default:
                Text(clip.plainText ?? "No preview")
                    .lineLimit(isExpanded ? nil : 1)
                    .truncationMode(.tail)
                    .font(.body)
            }
        }
    }

    // MARK: - Metadata

    private var metadataView: some View {
        HStack(spacing: 6) {
            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let appName = clip.sourceAppName {
                Text(appName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(clip.createdAt.relativeDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Expanded Preview

    private var expandedPreview: some View {
        Group {
            switch clip.contentType {
            case .image:
                if let nsImage = NSImage(data: clip.content) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            case .link:
                if let urlString = clip.plainText {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(urlString)
                            .font(.body)
                            .foregroundStyle(.blue)
                            .underline()
                    }
                }
            case .color:
                if let colorDesc = clip.plainText {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray)
                            .frame(width: 32, height: 32)
                        Text(colorDesc)
                            .font(.body.monospaced())
                    }
                }
            default:
                Text(clip.plainText ?? "No content")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

// MARK: - Content Type Extensions

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
}

// MARK: - Date Extension

extension Date {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var relativeDescription: String {
        Self.relativeFormatter.localizedString(for: self, relativeTo: .now)
    }
}
