//
//  ContentView.swift
//  SafeRelay
//
//  Created by Madi Sharipov on 21.04.2025.
//

import SwiftUI
import CoreData

// Define the wrapper struct
struct ShareableURL: Identifiable {
    let id = UUID() // Provide an ID for Identifiable conformance
    let url: URL
}

struct ContentView: View {
    @StateObject private var viewModel = SafeRelayViewModel()
    @State private var messageText = ""
    @State private var showingFilePicker = false
    @State private var showingSecuritySettings = false
    @State private var isComposing = false
    @State private var tokenizedText = ""
    @State private var tokens = [:]
    @State private var shareablePackage: ShareableURL?
    @State private var fileContentPreview: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Security Status Bar
                SecurityStatusBar(viewModel: viewModel)
                
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message, 
                                    viewModel: viewModel,
                                    shareablePackage: $shareablePackage,
                                    fileContentPreview: $fileContentPreview
                                )
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { oldCount, newCount in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Composition Area
                VStack(spacing: 8) {
                    if isComposing {
                        HStack {
                            Text("Security Level:")
                                .font(.caption)
                            Picker("Security Level", selection: $viewModel.securityLevel) {
                                ForEach(SecurityLevel.allCases) { level in
                                    Text(level.description).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)
                    }
                    
                    HStack {
                        TextField("Type a message...", text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: messageText) { oldValue, newValue in
                                print("--- DEBUG: TextField changed ---")
                                print("Old value: [\(oldValue)]")
                                print("New value: [\(newValue)]")
                            }
                            .onTapGesture {
                                isComposing = true
                            }
                        
                        Button(action: {
                            print("--- DEBUG: Send button pressed ---")
                            let currentText = messageText // Capture current text
                            print("Message to send: [\(currentText)]")
                            if currentText.isEmpty {
                                print("--- DEBUG: Send button pressed with empty text, doing nothing ---")
                                return
                            }
                            Task {
                                print("--- DEBUG: Calling viewModel.sendMessage ---")
                                let sentDirectly = await viewModel.sendMessage(currentText)
                                print("--- DEBUG: viewModel.sendMessage returned: \(sentDirectly) ---")
                                // Clear text only if message was sent directly (no alert shown)
                                if sentDirectly {
                                    print("--- DEBUG: Clearing messageText as message was sent directly ---")
                                    messageText = ""
                                    isComposing = false
                                }
                            }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(messageText.isEmpty ? .gray : .blue)
                        }
                        .disabled(messageText.isEmpty || viewModel.isLoading)
                    }
                    .padding(.horizontal)
                    
                    if isComposing {
                        HStack(spacing: 12) {
                            if viewModel.securityLevel != .standard {
                                Button(action: { showingFilePicker = true }) {
                                    Label("File", systemImage: "paperclip")
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Button(action: {
                                viewModel.toggleEncryption()
                            }) {
                                Label(
                                    viewModel.isEncryptionEnabled ? "Encryption On" : "Encryption Off",
                                    systemImage: viewModel.isEncryptionEnabled ? "lock.fill" : "lock.open"
                                )
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.securityLevel == .maximum)
                            
                            Spacer()
                            
                            if viewModel.isLoading {
                                ProgressView()
                            }
                        }
                        .id(viewModel.securityLevel)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .shadow(radius: 2)
            }
            .navigationTitle("SafeRelay+")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSecuritySettings = true }) {
                        Image(systemName: "shield.lefthalf.filled")
                    }
                }
            }
            .sheet(isPresented: $showingSecuritySettings) {
                SecuritySettingsView(viewModel: viewModel)
            }
            .sheet(item: $shareablePackage) { item in
                if FileManager.default.fileExists(atPath: item.url.path) {
                    ActivityView(activityItems: [item.url])
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.largeTitle)
                        Text("Error Sharing File") .font(.headline)
                        Text("Could not find the file part to share. It might have been deleted.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Dismiss") { shareablePackage = nil } 
                            .padding(.top)
                    }
                    .onAppear {
                        print("--- ERROR: File for share sheet NOT FOUND at path: \(item.url.path). Showing error view.")
                    }
                }
            }
            .alert(viewModel.alertMessage ?? "", isPresented: $viewModel.showAlert) {
                switch viewModel.alertType {
                case .sensitiveData:
                    Button("Tokenize and Send") {
                        print("--- DEBUG: Tokenize Button Pressed ---")
                        print("Current messageText: [\(messageText)]")
                        let textToSend = messageText
                        Task {
                            print("--- DEBUG: Before tokenizeAndSendMessage ---")
                            print("Text to send: [\(textToSend)]")
                            await viewModel.tokenizeAndSendMessage(textToSend)
                            print("--- DEBUG: After tokenizeAndSendMessage ---")
                            messageText = ""
                            isComposing = false
                        }
                    }
                    Button("Send Anyway", role: .destructive) {
                        Task {
                            await viewModel.sendMessage(messageText)
                            messageText = ""
                            isComposing = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                    
                case .phishing:
                    Button("Send Anyway", role: .destructive) {
                        Task {
                            await viewModel.sendMessage(messageText)
                            messageText = ""
                            isComposing = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                    
                case .fileAlreadyProcessed:
                    Button("Open File") {
                        if let decryptedURL = viewModel.messages.first(where: { $0.transferID == viewModel.processingTransferIDs.first })?.decryptedFileURL {
                            UIApplication.shared.open(decryptedURL)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                    
                case .none:
                    Button("OK", role: .cancel) {}
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await viewModel.sendFile(url)
                        }
                    }
                case .failure(let error):
                    viewModel.alertMessage = "Error selecting file: \(error.localizedDescription)"
                    viewModel.showAlert = true
                }
            }
            .onChange(of: messageText) { oldValue, newValue in
                if !newValue.isEmpty {
                    let result = DataProtectionService.shared.tokenizeSensitiveData(newValue)
                    tokenizedText = result.tokenizedText
                    tokens = result.tokens
                } else {
                    tokenizedText = ""
                    tokens = [:]
                }
            }
            .onOpenURL { incomingURL in
                print("--- ContentView: Received URL via onOpenURL: \(incomingURL)")
                handleIncomingURL(incomingURL)
            }
        }
    }
    
    // Helper function to process the incoming URL
    private func handleIncomingURL(_ url: URL) {
        // Check if it's a file URL and has the expected extension
        guard url.isFileURL, url.pathExtension == "safeRelayPkg" else {
            print("--- ContentView: Incoming URL is not a valid .safeRelayPkg file.")
            // Optionally show an error to the user
            return
        }
        
        // Extract transferID from filename (assuming format secondary_TRANSFERID_original.safeRelayPkg)
        let filename = url.lastPathComponent
        let parts = filename.split(separator: "_")
        guard parts.count >= 3, parts[0] == "secondary" else {
            print("--- ContentView: Could not extract transferID from filename: \(filename)")
            return
        }
        let transferID = String(parts[1])
        print("--- ContentView: Extracted transferID: \(transferID)")

        // --- Check if already processing this ID ---
        if viewModel.processingTransferIDs.contains(transferID) {
            print("--- ContentView: Already processing transferID: \(transferID). Skipping duplicate request. ---")
            return
        }
        // ---------------------------------------------

        // Find the corresponding message in ViewModel
        guard let targetMessageIndex = viewModel.messages.firstIndex(where: { $0.transferID == transferID }) else {
             print("--- ContentView: No message found for transferID: \(transferID)")
             // Show error: "Original message not found for this file part."
             viewModel.alertMessage = "Original message not found for this file part."
             viewModel.alertType = nil
             viewModel.showAlert = true
             return
        }
        let targetMessage = viewModel.messages[targetMessageIndex]
        
        // --- Check if already reconstructed ---
        if let decryptedURL = targetMessage.decryptedFileURL {
            print("--- ContentView: File for transferID: \(transferID) has already been reconstructed. Skipping. ---")
            // Show alert and offer to open the existing file
            viewModel.alertMessage = "This file has already been processed. Would you like to open it?"
            viewModel.alertType = .fileAlreadyProcessed
            viewModel.showAlert = true
            return
        }
        // -------------------------------------
        
        // Ensure primary part URL exists
        guard let primaryURLString = targetMessage.primaryPartURLString, 
              let primaryURL = URL(string: primaryURLString) else {
            print("--- ContentView: Primary part URL missing or invalid for transferID: \(transferID)")
            viewModel.alertMessage = "Primary file part information is missing or invalid."
            viewModel.alertType = nil
            viewModel.showAlert = true
            return
        }
        
        print("--- ContentView: Found matching message and primary URL. Starting reconstruction for \(transferID).")
        viewModel.isLoading = true // Show loading indicator
        viewModel.processingTransferIDs.insert(transferID) // Mark as processing BEFORE starting Task
        
        Task {
            defer {
                // Ensure ID is removed from processing set when Task completes (success or error)
                Task { @MainActor in
                    viewModel.processingTransferIDs.remove(transferID)
                    viewModel.isLoading = false
                    print("--- ContentView: Removed transferID \(transferID) from processing set. ---")
                }
            }
            
            do {
                // Read the secondary package data
                guard url.startAccessingSecurityScopedResource() else {
                    print("--- ContentView ERROR: Cannot access security scoped resource for URL: \(url.path)")
                    throw FileTransmissionService.FileError.accessDenied(url.lastPathComponent)
                }
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                let secondaryPackageData: Data
                do {
                    secondaryPackageData = try Data(contentsOf: url)
                } catch {
                    print("--- ContentView ERROR: Failed to read secondary package data: \(error.localizedDescription)")
                    throw FileTransmissionService.FileError.readError(error.localizedDescription)
                }
                
                // Call the reconstruction service
                let decryptedFileURL = try await FileTransmissionService.shared.reconstructAndDecryptFile(
                    primaryPartURL: primaryURL,
                    secondaryPackageData: secondaryPackageData
                )
                
                // Success!
                // Perform delay *before* switching to main actor for UI updates
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                await MainActor.run {
                    print("--- ContentView: File reconstruction SUCCESS! Decrypted file at: \(decryptedFileURL.path)")
                    
                    // Update message with decrypted file URL
                    viewModel.updateMessageAfterReconstruction(transferID: transferID, decryptedFileURL: decryptedFileURL)
                    
                    // Show a standard alert that the user dismisses
                    viewModel.alertMessage = "File successfully reconstructed!"
                    viewModel.alertType = nil
                    viewModel.showAlert = true
                    
                    print("--- ContentView: Message updated with decrypted file URL (after delay) ---")
                }
            } catch {
                await MainActor.run {
                    print("--- ContentView ERROR: File reconstruction failed: \(error.localizedDescription)")
                    viewModel.alertMessage = "Error processing file: \(error.localizedDescription)"
                    viewModel.alertType = nil
                    viewModel.showAlert = true
                }
            }
        }
    }
}

struct SecurityStatusBar: View {
    @ObservedObject var viewModel: SafeRelayViewModel
    
    var body: some View {
        HStack {
            Label(
                "Security Level: \(viewModel.securityLevel.description)",
                systemImage: viewModel.securityLevel.iconName
            )
            .font(.caption)
            .padding(6)
            .background(viewModel.securityLevel.color.opacity(0.2))
            .cornerRadius(4)
            
            Spacer()
            
            if viewModel.isEncryptionEnabled {
                Label("Encrypted", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            } else {
                Label("Unencrypted", systemImage: "lock.open.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
}

struct MessageBubble: View {
    let message: SecureMessage
    let viewModel: SafeRelayViewModel
    @State private var showingOriginal = false
    @State private var showingDetails = false
    @State private var hoveredToken: String?
    @Binding var shareablePackage: ShareableURL?
    @Binding var fileContentPreview: String?
    
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
    
    // Helper to create AttributedString for tokenized text
    private func createAttributedString(from tokenizedText: String) -> AttributedString {
        var attributedString = AttributedString()
        let words = tokenizedText.split(separator: " ")

        for (index, word) in words.enumerated() {
            let wordStr = String(word)
            var currentWordAttr = AttributedString(wordStr)

            if wordStr.contains("_") { // Basic token check
                let formattedToken = formatToken(wordStr)
                var tokenAttr = AttributedString(formattedToken)
                let tokenColor = getTokenColor(wordStr)
                tokenAttr.foregroundColor = tokenColor
                tokenAttr.backgroundColor = tokenColor.opacity(0.15)
                // Apply inline block styling might help but can be complex, start simple
                // tokenAttr.inlinePresentationIntent = .block
                currentWordAttr = tokenAttr
            }

            attributedString.append(currentWordAttr)

            // Add space if not the last word
            if index < words.count - 1 {
                attributedString.append(AttributedString(" "))
            }
        }
        return attributedString
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                if message.isEncrypted {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(.top, 5)
                }
                
                VStack(alignment: .leading) {
                    if let tokenized = message.tokenizedContent {
                        if showingOriginal {
                            Text(viewModel.getOriginalContent(for: message))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .textSelection(.enabled)
                        } else {
                            // Use Text with the generated AttributedString
                            Text(createAttributedString(from: tokenized))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .textSelection(.enabled) // Enable selection on the AttributedString
                        }
                    } else {
                        Text(message.content)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .textSelection(.enabled)
                    }
                }
                
                Spacer()
                
                if message.tokenizedContent != nil {
                    Button(action: { showingOriginal.toggle() }) {
                        Image(systemName: showingOriginal ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 5)
                }
            }
            
            HStack {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                // Check if it's a file message with split parts
                if message.primaryPartURLString != nil {
                    if let decryptedURL = message.decryptedFileURL {
                        // File has been reconstructed - show Open button or preview
                        Button {
                            print("--- DEBUG: Attempting to preview/open decrypted file: \(decryptedURL.path)")
                            // Try to read as text first
                            do {
                                // Check if it looks like a text file (simple check)
                                if decryptedURL.pathExtension.lowercased() == "txt" || decryptedURL.pathExtension.lowercased() == "log" || decryptedURL.pathExtension.isEmpty { // Add other text extensions if needed
                                    let content = try String(contentsOf: decryptedURL, encoding: .utf8)
                                    fileContentPreview = content
                                    print("--- DEBUG: Loaded text content for preview.")
                                } else {
                                    // Not a recognized text file, open externally
                                    print("--- DEBUG: Not a text file, opening externally.")
                                    UIApplication.shared.open(decryptedURL)
                                }
                            } catch {
                                // Error reading or not text, open externally
                                print("--- DEBUG: Error reading file as text or not text file, opening externally: \(error.localizedDescription)")
                                UIApplication.shared.open(decryptedURL)
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "doc.fill")
                                Text("Open File")
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    } else if let secondaryURLString = message.secondaryPackageURLString,
                              let secondaryURL = URL(string: secondaryURLString) {
                        // File not yet reconstructed - show Share Part 2 button
                        Button {
                            print("--- DEBUG: Share Part 2 button tapped. URL: \(secondaryURL.absoluteString)")
                            self.shareablePackage = ShareableURL(url: secondaryURL)
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "doc.on.doc.fill")
                                Text("Share Part 2")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                Button(action: { showingDetails = true }) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 8)
            
            // --- ADDED: Text File Preview Area ---
            if let preview = fileContentPreview {
                VStack(alignment: .leading) {
                    HStack {
                        Text("File Preview:")
                            .font(.caption.bold())
                        Spacer()
                        Button {
                            fileContentPreview = nil // Close preview
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    ScrollView {
                        Text(preview)
                            .font(.caption)
                            .frame(maxHeight: 150) // Limit height
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            // -------------------------------------
            
        }
        .sheet(isPresented: $showingDetails) {
            MessageDetailsView(message: message)
        }
    }
}

struct MessageDetailsView: View {
    let message: SecureMessage
    
    var body: some View {
        NavigationView {
            List {
                Section("Message Info") {
                    DetailRow(title: "Sent", value: message.timestamp.formatted())
                    DetailRow(title: "Encrypted", value: message.isEncrypted ? "Yes" : "No")
                    DetailRow(title: "Contains File", value: (message.primaryPartURLString != nil) ? "Yes" : "No")
                }
                
                if message.primaryPartURLString != nil {
                    Section("File Info") {
                        DetailRow(title: "Status", value: "Ready for transmission")
                        if let primaryURL = message.primaryPartURLString {
                            DetailRow(title: "Primary Part", value: URL(string: primaryURL)?.lastPathComponent ?? "N/A")
                        }
                        if let secondaryURL = message.secondaryPackageURLString {
                            DetailRow(title: "Secondary Pkg", value: URL(string: secondaryURL)?.lastPathComponent ?? "N/A")
                        }
                    }
                }
            }
            .navigationTitle("Message Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
}

struct SecuritySettingsView: View {
    @ObservedObject var viewModel: SafeRelayViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section("Security Level") {
                    Picker("Default Security Level", selection: $viewModel.securityLevel) {
                        ForEach(SecurityLevel.allCases) { level in
                            Text(level.description).tag(level)
                        }
                    }
                }
                
                Section("Encryption") {
                    Toggle("Enable End-to-End Encryption", isOn: $viewModel.isEncryptionEnabled)
                        .disabled(viewModel.securityLevel == .maximum)
                    Toggle("Auto-tokenize Sensitive Data", isOn: $viewModel.autoTokenize)
                        .disabled(viewModel.securityLevel == .maximum)
                }
                
                Section("File Security") {
                    Toggle("Split Files for Transmission", isOn: $viewModel.splitFiles)
                        .disabled(viewModel.securityLevel == .maximum)
                    Toggle("Encrypt File Parts", isOn: $viewModel.encryptFiles)
                        .disabled(viewModel.securityLevel == .maximum)
                }
                
                Section("Privacy") {
                    Toggle("Show Message Preview (Notifications)", isOn: $viewModel.showMessagePreview)
                        .disabled(viewModel.securityLevel == .maximum)
                    Toggle("Save Message History to Device", isOn: $viewModel.saveToDevice)
                        .disabled(viewModel.securityLevel == .maximum)
                }
            }
            .navigationTitle("Security Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.saveSettings()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Ensure ViewModel settings reflect the current state when view appears
                // This is mostly handled by @StateObject and @Published
            }
        }
    }
}

enum SecurityLevel: Int, CaseIterable, Identifiable {
    case standard
    case enhanced
    case maximum
    
    var id: Int { rawValue }
    
    var description: String {
        switch self {
        case .standard: return "Standard"
        case .enhanced: return "Enhanced"
        case .maximum: return "Maximum"
        }
    }
    
    var iconName: String {
        switch self {
        case .standard: return "shield"
        case .enhanced: return "shield.lefthalf.filled"
        case .maximum: return "shield.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .standard: return .blue
        case .enhanced: return .orange
        case .maximum: return .red
        }
    }
}

// Add the ActivityView struct for UIActivityViewController integration
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}

