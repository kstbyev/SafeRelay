import SwiftUI

struct FileRow: View {
    let message: SecureMessage
    @ObservedObject var viewModel: SafeRelayViewModel
    @Binding var shareablePackage: ShareableURL?
    @Binding var fileContentPreview: String?
    var onPreview: ((URL) -> Void)? = nil
    var showShare: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: fileIcon(for: message))
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(iconColor(for: message))
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(message.originalFilename?.isEmpty == false ? message.originalFilename! : "Без имени")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(message.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack(spacing: 12) {
                    if message.isEncrypted {
                        Label("Encrypted", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .labelStyle(.iconOnly)
                            .fixedSize()
                    }
                    if message.isSplit {
                        Label("Split", systemImage: "square.split.2x1")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .labelStyle(.iconOnly)
                            .fixedSize()
                    }
                }
                .padding(.top, 2)
            }
            Spacer()
            HStack(spacing: 10) {
                if let url = message.decryptedFileURL {
                    Button(action: {
                        if let onPreview = onPreview {
                            onPreview(url)
                        }
                    }) {
                        Image(systemName: "eye")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                    Button(action: {
                        fileContentPreview = nil
                        shareablePackage = nil
                        UIApplication.shared.open(url)
                    }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.trailing, 2)
        }
        .frame(minHeight: 72)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .padding(.vertical, 2)
    }

    func fileIcon(for message: SecureMessage) -> String {
        let name = message.originalFilename?.lowercased() ?? ""
        if name.hasSuffix(".pdf") { return "doc.richtext" }
        if name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") || name.hasSuffix(".png") { return "photo" }
        if name.hasSuffix(".txt") { return "doc.text" }
        if name.hasSuffix(".zip") { return "archivebox" }
        return "doc"
    }
    func iconColor(for message: SecureMessage) -> Color {
        let name = message.originalFilename?.lowercased() ?? ""
        if name.hasSuffix(".pdf") { return .red }
        if name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") || name.hasSuffix(".png") { return .purple }
        if name.hasSuffix(".txt") { return .blue }
        if name.hasSuffix(".zip") { return .orange }
        return .gray
    }
} 