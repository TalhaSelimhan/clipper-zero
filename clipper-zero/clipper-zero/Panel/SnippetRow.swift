import SwiftUI

struct SnippetRow: View {
    let snippet: SnippetItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("SNP")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.teal)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.body)

                Text(snippet.value)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(snippet.createdAt.relativeDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
