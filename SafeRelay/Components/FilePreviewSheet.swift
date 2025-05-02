import SwiftUI

struct FilePreviewSheet: View {
    enum PreviewType {
        case none, text, image, pdf, error
    }
    var previewType: PreviewType
    var fileContentPreview: String?
    var previewImage: UIImage?
    var previewPDFURL: URL?
    var previewError: String?
    var previewFileName: String
    var previewFileIcon: String
    @Binding var showPreview: Bool
    var fileURL: URL? = nil

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showPreview = false 
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            Spacer(minLength: 0)
            Group {
                switch previewType {
                case .text:
                    if let text = fileContentPreview {
                        ScrollView {
                            Text(text)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                case .image:
                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                            .transition(.scale.combined(with: .opacity))
                    }
                case .pdf:
                    if let url = previewPDFURL {
                        PDFPreviewController(url: url)
                            .transition(.move(edge: .bottom))
                    }
                case .error:
                    VStack(spacing: 16) {
                        Image(systemName: previewFileIcon)
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(previewFileName)
                            .font(.headline)
                        Text(previewError ?? "Не удалось открыть файл или формат не поддерживается.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        if let url = fileURL {
                            Text("Путь: \(url.path)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .transition(.scale.combined(with: .opacity))
                default:
                    Text("Не удалось открыть файл или формат не поддерживается.")
                        .padding()
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: previewType)
            
            Spacer(minLength: 0)
            if let url = fileURL, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    Text("Информация о файле:")
                        .font(.caption.bold())
                    Text("Имя: \(url.lastPathComponent)")
                        .font(.caption2)
                    if let size = attrs[.size] as? NSNumber {
                        Text("Размер: \(ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file))")
                            .font(.caption2)
                    }
                    if let date = attrs[.creationDate] as? Date {
                        Text("Создан: \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom))
            }
            // Авторская анимация
            Spacer(minLength: 0)
            AuthorSignatureView()
                .padding(.bottom, 18)
        }
        .background(Color(.systemBackground))
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showPreview)
    }
}

// Красивый fade-in для подписи автора
struct AuthorSignatureView: View {
    @State private var show = false
    var body: some View {
        VStack {
            if show {
                Text("Created by Madi Sharipov")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.accentColor)
                    .opacity(0.8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.7)) {
                show = true
            }
        }
    }
} 
