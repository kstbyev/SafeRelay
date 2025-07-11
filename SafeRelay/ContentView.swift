//
//  ContentView.swift
//  SafeRelay
//
//  Created by Madi Sharipov on 21.04.2025.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import QuickLook

// Define the wrapper struct
struct ShareableURL: Identifiable {
    let id = UUID() // Provide an ID for Identifiable conformance
    let url: URL
}

// Add a wrapper for reconstructed file URLs
struct ReconstructedFileURL: Identifiable {
    let id = UUID()
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
    @State private var selectedTab: Int = 0
    @State private var showSplash = true
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @State private var reconstructedFileURL: ReconstructedFileURL?
    
    let tabItems: [(icon: String, label: String)] = [
        ("bubble.left.and.bubble.right.fill", "Chats"),
        ("doc.on.doc", "Files"),
        ("gearshape", "Settings")
    ]

    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            } else {
                mainContent
            }
        }
        .preferredColorScheme(appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.7)) {
                    showSplash = false
                }
            }
        }
        .sheet(item: $shareablePackage) { item in
            if FileManager.default.fileExists(atPath: item.url.path) {
                ActivityView(activityItems: [item.url])
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.largeTitle)
                    Text("Error Sharing File")
                        .font(.headline)
                    Text("Could not find the file part to share. It might have been deleted.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Dismiss") { shareablePackage = nil }
                        .padding(.top)
                }
                .padding()
            }
        }
        .sheet(item: $reconstructedFileURL) { item in
            let url = item.url
            VStack(spacing: 20) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("Файл успешно восстановлен!")
                    .font(.headline)
                Button(action: {
                    UIApplication.shared.open(url)
                    reconstructedFileURL = nil
                }) {
                    Label("Open File", systemImage: "arrow.up.right.square")
                        .font(.title2)
                        .padding()
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(12)
                }
                Button("Закрыть", role: .cancel) {
                    reconstructedFileURL = nil
                }
            }
            .padding()
        }
        .onOpenURL { url in
            if url.pathExtension.lowercased() == "saferelaypkg" {
                handleIncomingURL(url)
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            let alertTitle: String
            switch viewModel.alertType {
            case .sensitiveData:
                alertTitle = "Sensitive Data Detected"
            case .phishing:
                alertTitle = "Phishing Warning"
            case .fileAlreadyProcessed, nil:
                alertTitle = "File Handling"
            }
            return Alert(
                title: Text(alertTitle),
                message: Text(viewModel.alertMessage ?? ""),
                primaryButton: viewModel.alertType == .sensitiveData ? .default(Text("Tokenize and Send")) {
                    let textToSend = messageText
                    Task {
                        await viewModel.tokenizeAndSendMessage(textToSend)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            messageText = ""
                            isComposing = false
                        }
                    }
                } : .default(Text("OK")),
                secondaryButton: viewModel.alertType == .sensitiveData ? .destructive(Text("Send Anyway")) {
                    Task {
                        await viewModel.confirmAndSendPendingMessage()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            messageText = ""
                            isComposing = false
                        }
                    }
                } : .cancel(Text("Cancel"))
            )
        }
    }
    
    var mainContent: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case 0:
                    ChatTabView(
                        viewModel: viewModel,
                        messageText: $messageText,
                        showingFilePicker: $showingFilePicker,
                        showingSecuritySettings: $showingSecuritySettings,
                        isComposing: $isComposing,
                        shareablePackage: $shareablePackage,
                        fileContentPreview: $fileContentPreview,
                        reconstructedFileURL: $reconstructedFileURL,
                        onProfile: { selectedTab = 3 },
                        onSettings: { selectedTab = 2 }
                    )
                    .frame(maxHeight: .infinity)
                case 1:
                    FilesTabView(viewModel: viewModel, shareablePackage: $shareablePackage, fileContentPreview: $fileContentPreview)
                case 2:
                    NavigationView {
                        List {
                            Section(header: Label("Appearance", systemImage: "paintbrush").font(.headline)) {
                                HStack {
                                    Text("Theme")
                                    Spacer()
                                    Menu {
                                        Button("System", action: { appColorScheme = "system" })
                                        Button("Light", action: { appColorScheme = "light" })
                                        Button("Dark", action: { appColorScheme = "dark" })
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: appColorScheme == "dark" ? "moon.fill" : appColorScheme == "light" ? "sun.max.fill" : "circle.lefthalf.filled")
                                                .foregroundColor(.accentColor)
                                            Text(appColorScheme == "dark" ? "Dark" : appColorScheme == "light" ? "Light" : "System")
                                                .foregroundColor(Theme.secondaryText)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 10)
                                        .background(Theme.card)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            Section(header: Label("Language", systemImage: "globe").font(.headline)) {
                                HStack {
                                    Text("App Language")
                                    Spacer()
                                    Text("English")
                                        .foregroundColor(Theme.secondaryText)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 10)
                                        .background(Theme.card)
                                        .cornerRadius(10)
                                }
                            }
                            Section(header: Label("Security", systemImage: "shield").font(.headline)) {
                                NavigationLink(destination: SecurityAnalyticsView(viewModel: viewModel)) {
                                    Label("Security Analytics", systemImage: "chart.bar.fill")
                                }
                                NavigationLink(destination: CloudSyncView(viewModel: viewModel)) {
                                    Label("Cloud Sync", systemImage: "icloud")
                                }
                            }
                            Section(header: Label("About", systemImage: "info.circle").font(.headline)) {
                                HStack {
                                    Text("Version")
                                    Spacer()
                                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                        .foregroundColor(Theme.secondaryText)
                                }
                                Link(destination: URL(string: "https://safepolicy.example.com")!) {
                                    Label("Privacy Policy", systemImage: "doc.text")
                                        .foregroundColor(Theme.accent)
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                        .background(Theme.background)
                        .navigationBarHidden(true)
                        .navigationTitle("Settings")
                    }
                default:
                    EmptyView()
                }
            }
            CustomTabBar(selectedTab: $selectedTab, tabItems: tabItems, appColorScheme: $appColorScheme)
        }
    }
    
    private func handleSendMessage() {
        let currentText = messageText
        if currentText.isEmpty { return }
        
        Task {
            let sentDirectly = await viewModel.sendMessage(currentText)
            if sentDirectly {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    messageText = ""
                    isComposing = false
                }
            }
        }
    }
    
    private func handleAlertAction() -> some View {
        Group {
            switch viewModel.alertType {
            case .sensitiveData:
                Button("Tokenize and Send") {
                    let textToSend = messageText
                    Task {
                        await viewModel.tokenizeAndSendMessage(textToSend)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            messageText = ""
                            isComposing = false
                        }
                    }
                }
                Button("Send Anyway", role: .destructive) {
                    Task {
                        await viewModel.confirmAndSendPendingMessage()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            messageText = ""
                            isComposing = false
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
                
            case .phishing:
                Button("Send Anyway", role: .destructive) {
                    Task {
                        await viewModel.sendMessage(messageText)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            messageText = ""
                            isComposing = false
                        }
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
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                // Обычный импорт файла
                Task {
                    await viewModel.sendFile(url)
                }
            }
        case .failure(let error):
            viewModel.alertMessage = "Error selecting file: \(error.localizedDescription)"
            viewModel.showAlert = true
        }
    }
    
    private func handleMessageTextChange(_ newValue: String) {
        if !newValue.isEmpty {
            let result = DataProtectionService.shared.tokenizeSensitiveData(newValue)
            tokenizedText = result.tokenizedText
            tokens = result.tokens
        } else {
            tokenizedText = ""
            tokens = [:]
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("=== [SafeRelay] onOpenURL called ===")
        print("URL: \(url)")
        print("URL path: \(url.path)")
        print("URL exists: \(FileManager.default.fileExists(atPath: url.path))")
        print("App sandbox: \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.deletingLastPathComponent().path ?? "nil")")
        
        guard url.isFileURL, url.pathExtension == "safeRelayPkg" else {
            print("--- ContentView: Incoming URL is not a valid .safeRelayPkg file.")
            return
        }
        
        let filename = url.lastPathComponent
        let parts = filename.split(separator: "_")
        print("Filename: \(filename), parts: \(parts)")
        guard parts.count >= 3, parts[0] == "secondary" else {
            print("--- ContentView: Could not extract transferID from filename: \(filename)")
            return
        }
        
        let transferID = String(parts[1])
        print("Extracted transferID: \(transferID)")
        
        // Copy file to sandbox if needed
        var sandboxedURL = url
        var needsCleanup = false
        
        if !url.startAccessingSecurityScopedResource() {
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: tmpURL.path) {
                    try FileManager.default.removeItem(at: tmpURL)
                }
                try FileManager.default.copyItem(at: url, to: tmpURL)
                print("Copied file to sandbox: \(tmpURL.path)")
                sandboxedURL = tmpURL
                needsCleanup = true
            } catch {
                print("Failed to copy file to sandbox: \(error.localizedDescription)")
                viewModel.alertMessage = "Failed to copy file to sandbox: \(error.localizedDescription)"
                viewModel.alertType = nil
                viewModel.showAlert = true
                return
            }
        }
        
        // Find the message and handle reconstruction
        guard let targetMessageIndex = viewModel.messages.firstIndex(where: { $0.transferID == transferID }) else {
            print("--- ContentView: No message found for transferID: \(transferID)")
            let allFiles = try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil)
            let primaryPart = allFiles?.first(where: { $0.lastPathComponent.contains(transferID) && $0.lastPathComponent.hasPrefix("primary_") })
            
            if let primaryURL = primaryPart, FileManager.default.fileExists(atPath: primaryURL.path) {
                Task {
                    do {
                        let secondaryPackageData = try Data(contentsOf: sandboxedURL)
                        let decryptedFileURL = try await FileTransmissionService.shared.reconstructAndDecryptFile(
                            primaryPartURL: primaryURL,
                            secondaryPackageData: secondaryPackageData
                        )
                        
                        await MainActor.run {
                            let textExtensions = ["txt", "log", "md", "json", "xml", "html", "css", "js", "swift", "py", "java", "c", "cpp", "h", "hpp"]
                            let ext = decryptedFileURL.pathExtension.lowercased()
                            if textExtensions.contains(ext) {
                                fileContentPreview = try? String(contentsOf: decryptedFileURL, encoding: .utf8)
                            } else {
                                viewModel.alertMessage = "File successfully reconstructed! Would you like to open it?"
                                viewModel.alertType = .fileAlreadyProcessed
                                viewModel.showAlert = true
                            }
                        }
                    } catch {
                        await MainActor.run {
                            print("--- ContentView ERROR: File reconstruction failed: \(error.localizedDescription)")
                            viewModel.alertMessage = "Error processing file: \(error.localizedDescription)"
                            viewModel.alertType = nil
                            viewModel.showAlert = true
                        }
                    }
                    
                    // Clean up after reconstruction is complete
                    url.stopAccessingSecurityScopedResource()
                    if needsCleanup {
                        try? FileManager.default.removeItem(at: sandboxedURL)
                    }
                }
            } else {
                viewModel.alertMessage = "Основная часть файла (primary part) не найдена. Пожалуйста, выберите файл primary_... для восстановления."
                viewModel.alertType = nil
                viewModel.showAlert = true
                self.reconstructedFileURL = ReconstructedFileURL(url: sandboxedURL)
                return
            }
            return
        }
        
        let targetMessage = viewModel.messages[targetMessageIndex]
        
        // Check if file is already reconstructed
        if let decryptedURL = targetMessage.decryptedFileURL, FileManager.default.fileExists(atPath: decryptedURL.path) {
            print("--- ContentView: File for transferID: \(transferID) has already been reconstructed and file exists. Showing open UI.")
            let textExtensions = ["txt", "log", "md", "json", "xml", "html", "css", "js", "swift", "py", "java", "c", "cpp", "h", "hpp"]
            let ext = decryptedURL.pathExtension.lowercased()
            if textExtensions.contains(ext) {
                fileContentPreview = try? String(contentsOf: decryptedURL, encoding: .utf8)
            } else {
                viewModel.alertMessage = "File successfully reconstructed! Would you like to open it?"
                viewModel.alertType = .fileAlreadyProcessed
                viewModel.showAlert = true
            }
            
            // Clean up since we're not proceeding with reconstruction
            url.stopAccessingSecurityScopedResource()
            if needsCleanup {
                try? FileManager.default.removeItem(at: sandboxedURL)
            }
            self.reconstructedFileURL = ReconstructedFileURL(url: decryptedURL)
            return
        }
        
        // Get primary URL and start reconstruction
        guard let primaryURLString = targetMessage.primaryPartURLString,
              let primaryURL = URL(string: primaryURLString) else {
            print("--- ContentView: Primary part URL missing or invalid for transferID: \(transferID)")
            viewModel.alertMessage = "Primary file part information is missing or invalid."
            viewModel.alertType = nil
            viewModel.showAlert = true
            
            // Clean up since we're not proceeding with reconstruction
            url.stopAccessingSecurityScopedResource()
            if needsCleanup {
                try? FileManager.default.removeItem(at: sandboxedURL)
            }
            return
        }
        
        print("--- ContentView: Found matching message and primary URL. Starting reconstruction for \(transferID).")
        viewModel.isLoading = true
        viewModel.processingTransferIDs.insert(transferID)
        
        Task {
            defer {
                Task { @MainActor in
                    viewModel.processingTransferIDs.remove(transferID)
                    viewModel.isLoading = false
                    print("--- ContentView: Removed transferID \(transferID) from processing set.")
                }
            }
            
            do {
                let secondaryPackageData = try Data(contentsOf: sandboxedURL)
                let decryptedFileURL = try await FileTransmissionService.shared.reconstructAndDecryptFile(
                    primaryPartURL: primaryURL,
                    secondaryPackageData: secondaryPackageData
                )
                
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                await MainActor.run {
                    print("--- ContentView: File reconstruction SUCCESS! Decrypted file at: \(decryptedFileURL.path)")
                    viewModel.updateMessageAfterReconstruction(transferID: transferID, decryptedFileURL: decryptedFileURL)
                    let openedFile = OpenedFile(url: decryptedFileURL, fileName: decryptedFileURL.lastPathComponent)
                    OpenedFilesHistory.shared.add(openedFile)
                    fileContentPreview = nil
                    
                    let textExtensions = ["txt", "log", "md", "json", "xml", "html", "css", "js", "swift", "py", "java", "c", "cpp", "h", "hpp"]
                    let ext = decryptedFileURL.pathExtension.lowercased()
                    if FileManager.default.fileExists(atPath: decryptedFileURL.path) {
                        if textExtensions.contains(ext) {
                            fileContentPreview = try? String(contentsOf: decryptedFileURL, encoding: .utf8)
                        } else {
                            viewModel.alertMessage = "File successfully reconstructed! Would you like to open it?"
                            viewModel.alertType = .fileAlreadyProcessed
                            viewModel.showAlert = true
                        }
                    }
                    print("--- ContentView: Message updated with decrypted file URL (after delay)")
                }
                self.reconstructedFileURL = ReconstructedFileURL(url: decryptedFileURL)
            } catch {
                await MainActor.run {
                    print("--- ContentView ERROR: File reconstruction failed: \(error.localizedDescription)")
                    viewModel.alertMessage = "Error processing file: \(error.localizedDescription)"
                    viewModel.alertType = nil
                    viewModel.showAlert = true
                }
            }
            
            // Clean up after reconstruction is complete
            url.stopAccessingSecurityScopedResource()
            if needsCleanup {
                try? FileManager.default.removeItem(at: sandboxedURL)
            }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let tabItems: [(icon: String, label: String)]
    @Binding var appColorScheme: String

    var body: some View {
        HStack {
            ForEach(0..<tabItems.count, id: \ .self) { idx in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = idx
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: tabItems[idx].icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(selectedTab == idx ? Theme.accent : Theme.secondaryText)
                            .scaleEffect(selectedTab == idx ? 1.18 : 1.0)
                            .shadow(color: selectedTab == idx ? Theme.accent.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Theme.card)
                                    .shadow(color: selectedTab == idx ? Theme.accent.opacity(0.15) : Theme.shadowDark.opacity(0.08), radius: 8, x: 0, y: 2)
                            )
                        Text(tabItems[idx].label)
                            .font(.caption2)
                            .foregroundColor(selectedTab == idx ? Theme.accent : Theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            // Кнопка смены темы
            Menu {
                Button("Системная", action: { appColorScheme = "system" })
                Button("Светлая", action: { appColorScheme = "light" })
                Button("Тёмная", action: { appColorScheme = "dark" })
            } label: {
                Image(systemName: appColorScheme == "dark" ? "moon.fill" : appColorScheme == "light" ? "sun.max.fill" : "circle.lefthalf.filled")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.accentColor)
                    .padding(10)
            }
            .frame(maxWidth: 44)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.background)
        .neumorphic()
        .shadow(radius: 2)
    }
}

// Вынесенный основной чат-экран для TabView
struct ChatTabView: View {
    @ObservedObject var viewModel: SafeRelayViewModel
    @Binding var messageText: String
    @Binding var showingFilePicker: Bool
    @Binding var showingSecuritySettings: Bool
    @Binding var isComposing: Bool
    @Binding var shareablePackage: ShareableURL?
    @Binding var fileContentPreview: String?
    @Binding var reconstructedFileURL: ReconstructedFileURL?
    @State private var tokenizedText = ""
    @State private var tokens: [String: String] = [:]
    @State private var isAtBottom: Bool = true
    @State private var showClearAlert = false
    var onProfile: () -> Void
    var onSettings: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CustomNavBar(title: "SafeRelay+",
                             onProfile: onProfile,
                             onSettings: onSettings,
                             onSearch: {},
                             onShield: { showingSecuritySettings = true })
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingSecuritySettings)
                SecurityStatusBar(viewModel: viewModel)
                    .transition(.move(edge: .top))
                ScrollViewReader { proxy in
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: Theme.elementSpacing) {
                                ForEach(viewModel.messages) { message in
                                    MessageView(
                                        message: message,
                                        viewModel: viewModel,
                                        shareablePackage: $shareablePackage,
                                        fileContentPreview: $fileContentPreview
                                    )
                                    .id(message.id)
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.messages.count)
                                }
                            }
                            .padding()
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("chatScroll")).maxY)
                                }
                            )
                        }
                        .coordinateSpace(name: "chatScroll")
                        .onChange(of: viewModel.messages.count) { oldCount, newCount in
                            if let lastMessage = viewModel.messages.last {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        if !isAtBottom {
                            Button(action: {
                                if let lastMessage = viewModel.messages.last {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Theme.accent)
                                    .shadow(radius: 4)
                                    .padding()
                            }
                            .transition(.scale.combined(with: .opacity))
                            .padding(.trailing, 16)
                            .padding(.bottom, 32)
                        }
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    if isComposing {
                        HStack {
                            Text("Security Level:")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryText)
                            Picker("Security Level", selection: $viewModel.securityLevel) {
                                ForEach(SecurityLevel.allCases) { level in
                                    Text(level.description).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                    HStack {
                        TextField("Type a message...", text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isComposing = true
                                }
                            }
                        Button(action: { handleSendMessage() }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(messageText.isEmpty ? Theme.secondaryText : Theme.accent)
                        }
                        .disabled(messageText.isEmpty || viewModel.isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    if isComposing {
                        HStack(spacing: Theme.elementSpacing) {
                            if viewModel.securityLevel != .standard {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showingFilePicker = true
                                    }
                                }) {
                                    Label("File", systemImage: "paperclip")
                                        .customButtonStyle()
                                }
                            }
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.toggleEncryption()
                                }
                            }) {
                                Label(
                                    viewModel.isEncryptionEnabled ? "Encryption On" : "Encryption Off",
                                    systemImage: viewModel.isEncryptionEnabled ? "lock.fill" : "lock.open"
                                )
                                .customButtonStyle()
                            }
                            .disabled(viewModel.securityLevel == .maximum)
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom))
                    }
                }
                .background(Color(.systemGray6))
            }
            .background(Theme.background)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showClearAlert = true
                    } label: {
                        Label("Clear Chats", systemImage: "trash")
                    }
                }
            }
            .alert(isPresented: $showClearAlert) {
                Alert(
                    title: Text("Очистить все чаты?"),
                    message: Text("Это действие удалит все сообщения безвозвратно."),
                    primaryButton: .destructive(Text("Очистить")) {
                        viewModel.messages.removeAll()
                        // Если есть сохранение в БД, тоже очистить
                        // viewModel.clearAllMessages() если реализовано
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showingSecuritySettings) {
                SecuritySettingsView(viewModel: viewModel)
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .onChange(of: messageText) { oldValue, newValue in
                handleMessageTextChange(newValue)
            }
            .onOpenURL { url in
                if url.pathExtension.lowercased() == "saferelaypkg" {
                    handleIncomingURL(url)
                }
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let threshold: CGFloat = 80 // px
                if let lastMessage = viewModel.messages.last {
                    // Если скролл близко к низу, считаем что пользователь внизу
                    isAtBottom = value < threshold
                }
            }
        }
    }

    private func handleSendMessage() {
        let currentText = messageText
        if currentText.isEmpty { return }
        Task {
            let sentDirectly = await viewModel.sendMessage(currentText)
            if sentDirectly {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    messageText = ""
                    isComposing = false
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                // Обычный импорт файла
                Task {
                    await viewModel.sendFile(url)
                }
            }
        case .failure(let error):
            viewModel.alertMessage = "Error selecting file: \(error.localizedDescription)"
            viewModel.showAlert = true
        }
    }

    private func handleMessageTextChange(_ newValue: String) {
        if !newValue.isEmpty {
            let result = DataProtectionService.shared.tokenizeSensitiveData(newValue)
            tokenizedText = result.tokenizedText
            tokens = result.tokens
        } else {
            tokenizedText = ""
            tokens = [:]
        }
    }

    private func handleIncomingURL(_ url: URL) {
        print("=== [SafeRelay] onOpenURL called ===")
        print("URL: \(url)")
        print("URL path: \(url.path)")
        print("URL exists: \(FileManager.default.fileExists(atPath: url.path))")
        print("App sandbox: \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.deletingLastPathComponent().path ?? "nil")")
        
        guard url.isFileURL, url.pathExtension == "safeRelayPkg" else {
            print("--- ContentView: Incoming URL is not a valid .safeRelayPkg file.")
            return
        }
        
        let filename = url.lastPathComponent
        let parts = filename.split(separator: "_")
        print("Filename: \(filename), parts: \(parts)")
        guard parts.count >= 3, parts[0] == "secondary" else {
            print("--- ContentView: Could not extract transferID from filename: \(filename)")
            return
        }
        
        let transferID = String(parts[1])
        print("Extracted transferID: \(transferID)")
        
        // Copy file to sandbox if needed
        var sandboxedURL = url
        var needsCleanup = false
        
        if !url.startAccessingSecurityScopedResource() {
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: tmpURL.path) {
                    try FileManager.default.removeItem(at: tmpURL)
                }
                try FileManager.default.copyItem(at: url, to: tmpURL)
                print("Copied file to sandbox: \(tmpURL.path)")
                sandboxedURL = tmpURL
                needsCleanup = true
            } catch {
                print("Failed to copy file to sandbox: \(error.localizedDescription)")
                viewModel.alertMessage = "Failed to copy file to sandbox: \(error.localizedDescription)"
                viewModel.alertType = nil
                viewModel.showAlert = true
                return
            }
        }
        
        // Find the message and handle reconstruction
        guard let targetMessageIndex = viewModel.messages.firstIndex(where: { $0.transferID == transferID }) else {
            print("--- ContentView: No message found for transferID: \(transferID)")
            let allFiles = try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil)
            let primaryPart = allFiles?.first(where: { $0.lastPathComponent.contains(transferID) && $0.lastPathComponent.hasPrefix("primary_") })
            
            if let primaryURL = primaryPart, FileManager.default.fileExists(atPath: primaryURL.path) {
                Task {
                    do {
                        let secondaryPackageData = try Data(contentsOf: sandboxedURL)
                        let decryptedFileURL = try await FileTransmissionService.shared.reconstructAndDecryptFile(
                            primaryPartURL: primaryURL,
                            secondaryPackageData: secondaryPackageData
                        )
                        
                        await MainActor.run {
                            let textExtensions = ["txt", "log", "md", "json", "xml", "html", "css", "js", "swift", "py", "java", "c", "cpp", "h", "hpp"]
                            let ext = decryptedFileURL.pathExtension.lowercased()
                            if textExtensions.contains(ext) {
                                fileContentPreview = try? String(contentsOf: decryptedFileURL, encoding: .utf8)
                            } else {
                                viewModel.alertMessage = "File successfully reconstructed! Would you like to open it?"
                                viewModel.alertType = .fileAlreadyProcessed
                                viewModel.showAlert = true
                            }
                        }
                    } catch {
                        await MainActor.run {
                            print("--- ContentView ERROR: File reconstruction failed: \(error.localizedDescription)")
                            viewModel.alertMessage = "Error processing file: \(error.localizedDescription)"
                            viewModel.alertType = nil
                            viewModel.showAlert = true
                        }
                    }
                    
                    // Clean up after reconstruction is complete
                    url.stopAccessingSecurityScopedResource()
                    if needsCleanup {
                        try? FileManager.default.removeItem(at: sandboxedURL)
                    }
                }
            } else {
                viewModel.alertMessage = "Основная часть файла (primary part) не найдена. Пожалуйста, выберите файл primary_... для восстановления."
                viewModel.alertType = nil
                viewModel.showAlert = true
                self.reconstructedFileURL = ReconstructedFileURL(url: sandboxedURL)
                return
            }
            return
        }
        
        let targetMessage = viewModel.messages[targetMessageIndex]
        
        // Check if file is already reconstructed
        if let decryptedURL = targetMessage.decryptedFileURL, FileManager.default.fileExists(atPath: decryptedURL.path) {
            print("--- ContentView: File for transferID: \(transferID) has already been reconstructed and file exists. Showing open UI.")
            let textExtensions = ["txt", "log", "md", "json", "xml", "html", "css", "js", "swift", "py", "java", "c", "cpp", "h", "hpp"]
            let ext = decryptedURL.pathExtension.lowercased()
            if textExtensions.contains(ext) {
                fileContentPreview = try? String(contentsOf: decryptedURL, encoding: .utf8)
            } else {
                viewModel.alertMessage = "File successfully reconstructed! Would you like to open it?"
                viewModel.alertType = .fileAlreadyProcessed
                viewModel.showAlert = true
            }
            
            // Clean up since we're not proceeding with reconstruction
            url.stopAccessingSecurityScopedResource()
            if needsCleanup {
                try? FileManager.default.removeItem(at: sandboxedURL)
            }
            self.reconstructedFileURL = ReconstructedFileURL(url: decryptedURL)
            return
        }
        
        // Get primary URL and start reconstruction
        guard let primaryURLString = targetMessage.primaryPartURLString,
              let primaryURL = URL(string: primaryURLString) else {
            print("--- ContentView: Primary part URL missing or invalid for transferID: \(transferID)")
            viewModel.alertMessage = "Primary file part information is missing or invalid."
            viewModel.alertType = nil
            viewModel.showAlert = true
            
            // Clean up since we're not proceeding with reconstruction
            url.stopAccessingSecurityScopedResource()
            if needsCleanup {
                try? FileManager.default.removeItem(at: sandboxedURL)
            }
            return
        }
        
        print("--- ContentView: Found matching message and primary URL. Starting reconstruction for \(transferID).")
        viewModel.isLoading = true
        viewModel.processingTransferIDs.insert(transferID)
        
        Task {
            defer {
                Task { @MainActor in
                    viewModel.processingTransferIDs.remove(transferID)
                    viewModel.isLoading = false
                    print("--- ContentView: Removed transferID \(transferID) from processing set.")
                }
            }
            
            do {
                let secondaryPackageData = try Data(contentsOf: sandboxedURL)
                let decryptedFileURL = try await FileTransmissionService.shared.reconstructAndDecryptFile(
                    primaryPartURL: primaryURL,
                    secondaryPackageData: secondaryPackageData
                )
                
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                await MainActor.run {
                    print("--- ContentView: File reconstruction SUCCESS! Decrypted file at: \(decryptedFileURL.path)")
                    viewModel.updateMessageAfterReconstruction(transferID: transferID, decryptedFileURL: decryptedFileURL)
                    let openedFile = OpenedFile(url: decryptedFileURL, fileName: decryptedFileURL.lastPathComponent)
                    OpenedFilesHistory.shared.add(openedFile)
                    fileContentPreview = nil
                    
                    let textExtensions = ["txt", "log", "md", "json", "xml", "html", "css", "js", "swift", "py", "java", "c", "cpp", "h", "hpp"]
                    let ext = decryptedFileURL.pathExtension.lowercased()
                    if FileManager.default.fileExists(atPath: decryptedFileURL.path) {
                        if textExtensions.contains(ext) {
                            fileContentPreview = try? String(contentsOf: decryptedFileURL, encoding: .utf8)
                        } else {
                            viewModel.alertMessage = "File successfully reconstructed! Would you like to open it?"
                            viewModel.alertType = .fileAlreadyProcessed
                            viewModel.showAlert = true
                        }
                    }
                    print("--- ContentView: Message updated with decrypted file URL (after delay)")
                }
                self.reconstructedFileURL = ReconstructedFileURL(url: decryptedFileURL)
            } catch {
                await MainActor.run {
                    print("--- ContentView ERROR: File reconstruction failed: \(error.localizedDescription)")
                    viewModel.alertMessage = "Error processing file: \(error.localizedDescription)"
                    viewModel.alertType = nil
                    viewModel.showAlert = true
                }
            }
            
            // Clean up after reconstruction is complete
            url.stopAccessingSecurityScopedResource()
            if needsCleanup {
                try? FileManager.default.removeItem(at: sandboxedURL)
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
            .cornerRadius(Theme.cornerRadius)
            
            Spacer()
            
            if viewModel.isEncryptionEnabled {
                Label("Encrypted", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(Theme.cornerRadius)
            } else {
                Label("Unencrypted", systemImage: "lock.open.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(Theme.cornerRadius)
            }
        }
        .padding(.horizontal)
        .background(Theme.background)
        .shadow(radius: 1)
    }
}

struct MessageBubble: View {
    let message: SecureMessage
    @ObservedObject var viewModel: SafeRelayViewModel
    @State private var showingOriginal = false
    @State private var showingDetails = false
    @State private var hoveredToken: String?
    @Binding var shareablePackage: ShareableURL?
    @Binding var fileContentPreview: String?
    @State private var isReconstructed = false
    @State private var decryptedURL: URL?
    @State private var showingFilePreview = false
    
    // Get the latest message from viewModel
    private var currentMessage: SecureMessage {
        viewModel.messages.first(where: { $0.id == message.id }) ?? message
    }
    
    // Helper to check if file is text-based
    private func isTextFile(_ url: URL) -> Bool {
        let textExtensions = ["txt", "log", "md", "json", "xml", "html", "css", "js", "swift", "py", "java", "c", "cpp", "h", "hpp"]
        let fileExtension = url.pathExtension.lowercased()
        
        // If no extension, try to read as text
        if fileExtension.isEmpty {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                return !content.isEmpty
            } catch {
                print("--- DEBUG: Failed to read as text: \(error.localizedDescription)")
                return false
            }
        }
        
        return textExtensions.contains(fileExtension)
    }
    
    // Helper to check if file is an image
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    // Helper to check if file is a PDF
    private func isPDFFile(_ url: URL) -> Bool {
        // Check extension
        if url.pathExtension.lowercased() == "pdf" {
            return true
        }
        
        // If no extension, try to read first few bytes to check PDF signature
        do {
            let data = try Data(contentsOf: url)
            if data.count >= 5 {
                let signature = data.prefix(5)
                let isPDF = signature == "%PDF-".data(using: .ascii)
                print("--- DEBUG: PDF signature check: \(isPDF ? "Found" : "Not found")")
                return isPDF
            }
        } catch {
            print("--- DEBUG ERROR: Failed to read file for PDF detection: \(error.localizedDescription)")
        }
        
        return false
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
                Text(currentMessage.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                // Check if it's a file message with split parts
                if currentMessage.primaryPartURLString != nil {
                    if currentMessage.decryptedFileURL != nil {
                        // File has been reconstructed - show Open button or preview
                        Button {
                            print("--- DEBUG: Open File button tapped ---")
                            if let url = currentMessage.decryptedFileURL {
                                print("File URL: \(url.path)")
                                print("File extension: \(url.pathExtension)")
                                print("File exists: \(FileManager.default.fileExists(atPath: url.path))")
                                print("File size: \(try? FileManager.default.attributesOfItem(atPath: url.path)[.size] ?? 0) bytes")
                                
                                if isPDFFile(url) {
                                    print("--- DEBUG: Detected PDF file ---")
                                    // For PDFs, show in QLPreviewController
                                    print("--- DEBUG: Showing PDF in preview controller ---")
                                    
                                    // Create a copy with .pdf extension
                                    let pdfURL = url.deletingPathExtension().appendingPathExtension("pdf")
                                    do {
                                        if FileManager.default.fileExists(atPath: pdfURL.path) {
                                            try FileManager.default.removeItem(at: pdfURL)
                                        }
                                        try FileManager.default.copyItem(at: url, to: pdfURL)
                                        print("--- DEBUG: Created PDF file with correct extension at: \(pdfURL.path)")
                                        
                                        let previewController = PDFPreviewController(url: pdfURL)
                                        let hostingController = UIHostingController(rootView: previewController)
                                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                                        print("--- DEBUG: Successfully showed PDF preview ---")
                                    } catch {
                                        print("--- DEBUG ERROR: Failed to create PDF file with extension ---")
                                        print("Error: \(error.localizedDescription)")
                                        // Fallback to original URL
                                        let previewController = PDFPreviewController(url: url)
                                        let hostingController = UIHostingController(rootView: previewController)
                                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                                    }
                                } else if isTextFile(url) {
                                    print("--- DEBUG: Detected text file ---")
                                    // For text files, show preview in message
                                    do {
                                        let content = try String(contentsOf: url, encoding: .utf8)
                                        print("--- DEBUG: Successfully read text content ---")
                                        print("Content length: \(content.count) characters")
                                        fileContentPreview = content
                                        showingFilePreview = true
                                        print("--- DEBUG: Set file preview to show ---")
                                    } catch {
                                        print("--- DEBUG ERROR: Failed to read text file ---")
                                        print("Error: \(error.localizedDescription)")
                                        if UIApplication.shared.canOpenURL(url) {
                                            UIApplication.shared.open(url)
                                            print("--- DEBUG: Successfully opened file externally ---")
                                        } else {
                                            print("--- DEBUG ERROR: Cannot open file externally ---")
                                        }
                                    }
                                } else if isImageFile(url) {
                                    print("--- DEBUG: Detected image file ---")
                                    // For images, show preview in message
                                    fileContentPreview = "Image file: \(url.lastPathComponent)"
                                    showingFilePreview = true
                                    print("--- DEBUG: Set image preview to show ---")
                                } else {
                                    print("--- DEBUG: Detected other file type ---")
                                    // For other files, open in external viewer
                                    print("--- DEBUG: Opening file externally ---")
                                    if UIApplication.shared.canOpenURL(url) {
                                        UIApplication.shared.open(url)
                                        print("--- DEBUG: Successfully opened file externally ---")
                                    } else {
                                        print("--- DEBUG ERROR: Cannot open file externally ---")
                                    }
                                }
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
                    } else if let secondaryURLString = currentMessage.secondaryPackageURLString,
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
            
            // File Preview Area
            if showingFilePreview, let preview = fileContentPreview {
                VStack(alignment: .leading) {
                    HStack {
                        Text("File Preview:")
                            .font(.caption.bold())
                        Spacer()
                        Button {
                            fileContentPreview = nil
                            showingFilePreview = false
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
            
        }
        .sheet(isPresented: $showingDetails) {
            MessageDetailsView(message: message)
        }
        .onChange(of: currentMessage.decryptedFileURL) { oldValue, newValue in
            print("--- DEBUG: Message decryptedFileURL changed ---")
            print("Old value: \(oldValue?.path ?? "nil")")
            print("New value: \(newValue?.path ?? "nil")")
            print("Message ID: \(currentMessage.id)")
            print("Message transferID: \(currentMessage.transferID)")
            isReconstructed = newValue != nil
            decryptedURL = newValue
            print("isReconstructed set to: \(isReconstructed)")
            print("decryptedURL set to: \(decryptedURL?.path ?? "nil")")
        }
        .onAppear {
            print("--- DEBUG: MessageBubble appeared ---")
            print("Message ID: \(currentMessage.id)")
            print("Message transferID: \(currentMessage.transferID)")
            print("Initial decryptedFileURL: \(currentMessage.decryptedFileURL?.path ?? "nil")")
            isReconstructed = currentMessage.decryptedFileURL != nil
            decryptedURL = currentMessage.decryptedFileURL
            print("Initial isReconstructed: \(isReconstructed)")
            print("Initial decryptedURL: \(decryptedURL?.path ?? "nil")")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MessageUpdated"))) { notification in
            if let transferID = notification.userInfo?["transferID"] as? String,
               transferID == currentMessage.transferID {
                print("--- DEBUG: Received MessageUpdated notification ---")
                print("Transfer ID: \(transferID)")
                print("Message transferID: \(currentMessage.transferID)")
                
                // Force UI update
                DispatchQueue.main.async {
                    viewModel.objectWillChange.send()
                }
            }
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

struct PDFPreviewController: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        
        init(url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
    }
}

// SplashScreenView с анимацией SafeRelay+ и подписью
struct SplashScreenView: View {
    @State private var showTitle = false
    @State private var showPlus = false
    @State private var showSignature = false
    @State private var plusOffset: CGFloat = -120
    @State private var plusBounce = false
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 0) {
                    if showTitle {
                        Text("SafeRelay")
                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                            .foregroundColor(.accentColor)
                            .shadow(color: .accentColor.opacity(0.13), radius: 8, x: 0, y: 3)
                            .transition(.scale.combined(with: .opacity))
                    }
                    if showPlus {
                        Text("+")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(Color.purple)
                            .offset(y: plusOffset)
                            .scaleEffect(plusBounce ? 1.12 : 1.0)
                            .opacity(showPlus ? 1 : 0)
                            .shadow(color: Color.purple.opacity(0.18), radius: 8, x: 0, y: 2)
                            .padding(.leading, 6)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.interpolatingSpring(stiffness: 180, damping: 13), value: plusOffset)
                            .animation(.easeOut(duration: 0.18), value: plusBounce)
                    }
                }
                Spacer()
                if showSignature {
                    Text("by kstbyev MS")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                showTitle = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                showPlus = true
                withAnimation(.interpolatingSpring(stiffness: 180, damping: 13)) {
                    plusOffset = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        plusBounce = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation(.easeIn(duration: 0.18)) {
                            plusBounce = false
                        }
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showSignature = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

