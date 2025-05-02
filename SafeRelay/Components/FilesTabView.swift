import SwiftUI

struct FilesTabView: View {
    @ObservedObject var viewModel: SafeRelayViewModel
    @Binding var shareablePackage: ShareableURL?
    @Binding var fileContentPreview: String?
    @State private var previewImage: UIImage? = nil
    @State private var previewPDFURL: URL? = nil
    @State private var showPreview: Bool = false
    @State private var previewType: FilePreviewSheet.PreviewType = .none
    @State private var previewError: String? = nil
    @State private var previewFileName: String = ""
    @State private var previewFileIcon: String = "doc"
    @State private var openedFiles: [OpenedFile] = []

    var body: some View {
        NavigationView {
            List {
                if !openedFiles.isEmpty {
                    Section(header: Text("Открытые через SafeRelay")) {
                        ForEach(openedFiles.sorted(by: { $0.dateOpened > $1.dateOpened })) { file in
                            Button(action: {
                                previewFile(url: file.url, fileName: file.filename)
                            }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 28))
                                        .foregroundColor(.accentColor)
                                    VStack(alignment: .leading) {
                                        Text(file.filename)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(file.dateOpened, style: .date)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
                Section(header: Text("Файлы в сообщениях")) {
                    ForEach(viewModel.messages.filter { $0.decryptedFileURL != nil }.sorted(by: { $0.timestamp > $1.timestamp })) { message in
                        FileRow(
                            message: message,
                            viewModel: viewModel,
                            shareablePackage: $shareablePackage,
                            fileContentPreview: $fileContentPreview,
                            onPreview: { url in
                                previewFile(url: message.decryptedFileURL!, fileName: message.originalFilename)
                            },
                            showShare: false
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Files")
            .background(Theme.background)
            .sheet(isPresented: $showPreview) {
                FilePreviewSheet(
                    previewType: previewType,
                    fileContentPreview: fileContentPreview,
                    previewImage: previewImage,
                    previewPDFURL: previewPDFURL,
                    previewError: previewError,
                    previewFileName: previewFileName,
                    previewFileIcon: previewFileIcon,
                    showPreview: $showPreview,
                    fileURL: previewPDFURL ?? (previewImage != nil ? previewPDFURL : nil) ?? nil
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPreview)
            }
            .onAppear {
                openedFiles = OpenedFilesHistory.shared.load()
            }
        }
    }

    private func previewFile(url: URL, fileName: String?) {
        previewFileName = fileName ?? url.lastPathComponent
        previewFileIcon = fileIcon(for: url)
        guard FileManager.default.fileExists(atPath: url.path) else {
            previewError = "Файл не найден."
            previewType = .error
            showPreview = true
            return
        }
        let ext = url.pathExtension.lowercased()
        if ["txt", "md", "json", "log", "csv", "xml", "html"].contains(ext) {
            if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                if text.isEmpty {
                    previewError = "Файл пустой."
                    previewType = .error
                    showPreview = true
                } else {
                    fileContentPreview = String(text.prefix(2000))
                    previewType = .text
                    showPreview = true
                }
            } else {
                previewError = "Не удалось прочитать содержимое файла."
                previewType = .error
                showPreview = true
            }
        } else if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"].contains(ext) {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                previewImage = image
                previewType = .image
                showPreview = true
            } else {
                previewError = "Не удалось открыть изображение."
                previewType = .error
                showPreview = true
            }
        } else if ext == "pdf" {
            previewPDFURL = url
            previewType = .pdf
            showPreview = true
        } else {
            previewError = "Формат не поддерживается."
            previewType = .error
            showPreview = true
        }
    }

    private func fileIcon(for url: URL) -> String {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".pdf") { return "doc.richtext" }
        if name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") || name.hasSuffix(".png") { return "photo" }
        if name.hasSuffix(".txt") { return "doc.text" }
        if name.hasSuffix(".zip") { return "archivebox" }
        if name.hasSuffix(".csv") { return "tablecells" }
        if name.hasSuffix(".xml") || name.hasSuffix(".html") { return "chevron.left.slash.chevron.right" }
        return "doc"
    }
} 
