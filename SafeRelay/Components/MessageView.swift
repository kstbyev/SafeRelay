import SwiftUI

struct MessageView: View {
    let message: SecureMessage
    @ObservedObject var viewModel: SafeRelayViewModel
    @Binding var shareablePackage: ShareableURL?
    @Binding var fileContentPreview: String?
    
    @State private var showingOriginal = false
    @State private var showingDetails = false
    @State private var showingFilePreview = false
    @State private var isReconstructed = false
    @State private var decryptedURL: URL?
    
    private var currentMessage: SecureMessage {
        viewModel.messages.first(where: { $0.id == message.id }) ?? message
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            // Message Content
            HStack(alignment: .top) {
                if message.isEncrypted {
                    Image(systemName: "lock.fill")
                        .foregroundColor(Theme.accent)
                        .font(.caption)
                        .padding(.top, 5)
                }
                
                VStack(alignment: .leading) {
                    if let tokenized = message.tokenizedContent {
                        if showingOriginal {
                            Text(viewModel.getOriginalContent(for: message))
                                .messageBubbleStyle(isEncrypted: true)
                                .textSelection(.enabled)
                        } else {
                            Text(createAttributedString(from: tokenized))
                                .messageBubbleStyle(isEncrypted: true)
                                .textSelection(.enabled)
                        }
                    } else {
                        Text(message.content)
                            .messageBubbleStyle(isEncrypted: false)
                            .textSelection(.enabled)
                    }
                }
                
                Spacer()
                
                if message.tokenizedContent != nil {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showingOriginal.toggle()
                        }
                    }) {
                        Image(systemName: showingOriginal ? "eye.slash" : "eye")
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 5)
                }
            }
            
            // Message Footer
            HStack {
                Text(currentMessage.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(Theme.secondaryText)
                
                if currentMessage.primaryPartURLString != nil {
                    if currentMessage.decryptedFileURL != nil {
                        Button {
                            handleFileOpen()
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "doc.fill")
                                Text("Open File")
                            }
                            .font(.caption)
                            .foregroundColor(Theme.accent)
                            .padding(4)
                            .background(Theme.accent.opacity(0.1))
                            .cornerRadius(Theme.cornerRadius)
                        }
                        .buttonStyle(.plain)
                    } else if let secondaryURLString = currentMessage.secondaryPackageURLString,
                              !secondaryURLString.isEmpty,
                              let secondaryURL = URL(string: secondaryURLString) {
                        Button {
                            print("[DEBUG] Share Part 2 tapped: \(secondaryURL)")
                            self.shareablePackage = ShareableURL(url: secondaryURL)
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "doc.on.doc.fill")
                                Text("Share Part 2")
                            }
                            .font(.caption)
                            .foregroundColor(Theme.accent)
                            .padding(4)
                            .background(Theme.accent.opacity(0.1))
                            .cornerRadius(Theme.cornerRadius)
                        }
                        .buttonStyle(.plain)
                    } else {
                        EmptyView()
                    }
                }
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingDetails = true
                    }
                }) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(Theme.secondaryText)
                }
            }
            .padding(.horizontal, Theme.elementSpacing)
            
            // File Preview
            if showingFilePreview, let preview = fileContentPreview {
                VStack(alignment: .leading) {
                    HStack {
                        Text("File Preview:")
                            .font(.caption.bold())
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                fileContentPreview = nil
                                showingFilePreview = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.secondaryText)
                        }
                    }
                    ScrollView {
                        Text(preview)
                            .font(.caption)
                            .frame(maxHeight: 150)
                    }
                    .padding(Theme.smallSpacing)
                    .background(Theme.card)
                    .cornerRadius(Theme.cornerRadius)
                }
                .padding(.horizontal, Theme.elementSpacing)
                .padding(.bottom, Theme.smallSpacing)
            }
        }
        .sheet(isPresented: $showingDetails) {
            MessageDetailsView(message: message)
        }
        .onChange(of: currentMessage.decryptedFileURL) { oldValue, newValue in
            isReconstructed = newValue != nil
            decryptedURL = newValue
        }
        .onAppear {
            isReconstructed = currentMessage.decryptedFileURL != nil
            decryptedURL = currentMessage.decryptedFileURL
        }
    }
    
    private func handleFileOpen() {
        guard let url = currentMessage.decryptedFileURL else {
            print("--- DEBUG: No decrypted file URL available ---")
            return
        }
        
        print("--- DEBUG: Opening file at URL: \(url.path) ---")
        if isPDFFile(url) {
            handlePDFFile(url)
        } else if isTextFile(url) {
            handleTextFile(url)
        } else if isImageFile(url) {
            handleImageFile(url)
        } else {
            handleOtherFile(url)
        }
    }
    
    private func handlePDFFile(_ url: URL) {
        print("--- DEBUG: Handling PDF file at URL: \(url.path) ---")
        let pdfURL = url.deletingPathExtension().appendingPathExtension("pdf")
        do {
            if FileManager.default.fileExists(atPath: pdfURL.path) {
                try FileManager.default.removeItem(at: pdfURL)
            }
            try FileManager.default.copyItem(at: url, to: pdfURL)
            print("--- DEBUG: Successfully copied PDF file to: \(pdfURL.path) ---")
            
            let previewController = PDFPreviewController(url: pdfURL)
            let hostingController = UIHostingController(rootView: previewController)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(hostingController, animated: true)
                print("--- DEBUG: Successfully presented PDF preview ---")
            } else {
                print("--- DEBUG ERROR: Could not find root view controller ---")
            }
        } catch {
            print("--- DEBUG ERROR: Failed to handle PDF file: \(error.localizedDescription) ---")
            let previewController = PDFPreviewController(url: url)
            let hostingController = UIHostingController(rootView: previewController)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(hostingController, animated: true)
                print("--- DEBUG: Successfully presented PDF preview with original URL ---")
            } else {
                print("--- DEBUG ERROR: Could not find root view controller ---")
            }
        }
    }
    
    private func handleTextFile(_ url: URL) {
        print("--- DEBUG: Handling text file at URL: \(url.path) ---")
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            print("--- DEBUG: Successfully read text content, length: \(content.count) characters ---")
            fileContentPreview = content
            showingFilePreview = true
            print("--- DEBUG: Set file preview to show ---")
        } catch {
            print("--- DEBUG ERROR: Failed to read text file: \(error.localizedDescription) ---")
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                print("--- DEBUG: Successfully opened file externally ---")
            } else {
                print("--- DEBUG ERROR: Cannot open file externally ---")
            }
        }
    }
    
    private func handleImageFile(_ url: URL) {
        print("--- DEBUG: Handling image file at URL: \(url.path) ---")
        fileContentPreview = "Image file: \(url.lastPathComponent)"
        showingFilePreview = true
        print("--- DEBUG: Set image preview to show ---")
    }
    
    private func handleOtherFile(_ url: URL) {
        print("--- DEBUG: Handling other file at URL: \(url.path) ---")
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            print("--- DEBUG: Successfully opened file externally ---")
        } else {
            print("--- DEBUG ERROR: Cannot open file externally ---")
        }
    }
    
    private func isPDFFile(_ url: URL) -> Bool {
        if url.pathExtension.lowercased() == "pdf" {
            return true
        }
        
        do {
            let data = try Data(contentsOf: url)
            if data.count >= 5 {
                let signature = data.prefix(5)
                return signature == "%PDF-".data(using: .ascii)
            }
        } catch {}
        
        return false
    }
    
    private func isTextFile(_ url: URL) -> Bool {
        let textExtensions = ["txt", "log", "md", "json", "xml", "html", "css", "js", "swift", "py", "java", "c", "cpp", "h", "hpp"]
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension.isEmpty {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                return !content.isEmpty
            } catch {}
        }
        
        return textExtensions.contains(fileExtension)
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func createAttributedString(from tokenizedText: String) -> AttributedString {
        var attributedString = AttributedString()
        let words = tokenizedText.split(separator: " ")
        
        for (index, word) in words.enumerated() {
            let wordStr = String(word)
            var currentWordAttr = AttributedString(wordStr)
            
            if wordStr.contains("_") {
                let formattedToken = formatToken(wordStr)
                var tokenAttr = AttributedString(formattedToken)
                let tokenColor = getTokenColor(wordStr)
                tokenAttr.foregroundColor = tokenColor
                tokenAttr.backgroundColor = tokenColor.opacity(0.15)
                currentWordAttr = tokenAttr
            }
            
            attributedString.append(currentWordAttr)
            
            if index < words.count - 1 {
                attributedString.append(AttributedString(" "))
            }
        }
        return attributedString
    }
    
    private func getTokenColor(_ token: String) -> Color {
        if token.starts(with: "EMAIL_") { return .blue }
        if token.starts(with: "PHONE_") { return .green }
        if token.starts(with: "NAME_") { return .purple }
        if token.starts(with: "CARD_") { return .red }
        if token.starts(with: "PHRASE_") { return .yellow }
        return .gray
    }
    
    private func formatToken(_ token: String) -> String {
        let components = token.split(separator: "_", maxSplits: 1)
        guard components.count == 2 else { return token }
        let prefix = String(components[0])
        return "\(prefix)_****"
    }
} 