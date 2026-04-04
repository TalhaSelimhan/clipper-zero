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
        .if(clip.isSecure) { view in
            view.accessibilityLabel("Secure \(clip.contentType.badge) item")
        }
    }

    // MARK: - Type Badge

    private var typeBadge: some View {
        HStack(spacing: 4) {
            if clip.isSecure {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white)
            }
            Text(clip.contentType.badge)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(clip.contentType.badgeColor)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Content Preview

    private var contentPreview: some View {
        Group {
            if clip.isSecure {
                switch clip.contentType {
                case .image:
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: 24)
                case .file:
                    Text(clip.plainText ?? "Secure file")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                default:
                    Text(clip.plainText ?? "Secure content")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } else {
                switch clip.contentType {
                case .image:
                    if let nsImage = NSImage(data: clip.previewData ?? clip.content) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 24)
                    }
                default:
                    Text(clip.plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No preview")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.body)
                }
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

            if clip.isSecure, let label = clip.secureLabel {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let appName = clip.sourceAppName {
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
            if clip.isSecure {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Secure content")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
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
                case .file:
                    FilePreviewView(clip: clip)
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
}

// MARK: - Conditional View Modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
