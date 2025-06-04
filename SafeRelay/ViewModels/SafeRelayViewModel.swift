import Foundation
import SwiftUI
import CryptoKit
import NaturalLanguage
import Combine
// import SafeRelay.Models.SecurityLevel // Удаляю, если не работает

@MainActor
class SafeRelayViewModel: ObservableObject {
    @Published var messages: [SecureMessage] = []
    @Published var alertMessage: String?
    @Published var showAlert = false
    @Published var isLoading = false
    @Published var alertType: AlertType?
    @Published var tokenizedText: String = ""
    @Published var processingTransferIDs: Set<String> = []
    
    // Security Settings
    @Published var securityLevel: SecurityLevel = .standard {
        didSet {
            // Update default settings based on new level
            updateSettingsForSecurityLevel()
        }
    }
    @Published var isEncryptionEnabled: Bool = false
    @Published var autoTokenize: Bool = false
    @Published var splitFiles: Bool = false
    @Published var encryptFiles: Bool = false
    @Published var showMessagePreview: Bool = true
    @Published var saveToDevice: Bool = true
    
    // MARK: - Security Analytics
    @Published var protectedMessagesCount: Int = 0
    @Published var encryptedFilesCount: Int = 0
    @Published var tokensFoundCount: Int = 0
    
    private let dataProtectionService = DataProtectionService.shared
    private let phishingProtectionService = PhishingProtectionService.shared
    private let fileTransmissionService = FileTransmissionService.shared
    
    // Make tokens accessible to views
    var sensitiveDataTokens: [String: String] = [:]
    
    // Uncomment DatabaseManager usage
    private var dbManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var pendingSensitiveMessage: String? = nil
    
    init() {
        loadSettings()
        loadMessages() // Now this should work
        updateSettingsForSecurityLevel()
        updateSecurityAnalytics()
    }
    
    private func loadSettings() {
        // Load user preferences from UserDefaults
        let defaults = UserDefaults.standard
        securityLevel = SecurityLevel(rawValue: defaults.integer(forKey: "securityLevel")) ?? .standard
        isEncryptionEnabled = defaults.bool(forKey: "isEncryptionEnabled")
        autoTokenize = defaults.bool(forKey: "autoTokenize")
        splitFiles = defaults.bool(forKey: "splitFiles")
        encryptFiles = defaults.bool(forKey: "encryptFiles")
        showMessagePreview = defaults.bool(forKey: "showMessagePreview")
        saveToDevice = defaults.bool(forKey: "saveToDevice")
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(securityLevel.rawValue, forKey: "securityLevel")
        defaults.set(isEncryptionEnabled, forKey: "isEncryptionEnabled")
        defaults.set(autoTokenize, forKey: "autoTokenize")
        defaults.set(splitFiles, forKey: "splitFiles")
        defaults.set(encryptFiles, forKey: "encryptFiles")
        defaults.set(showMessagePreview, forKey: "showMessagePreview")
        defaults.set(saveToDevice, forKey: "saveToDevice")
    }
    
    // Function to update settings when security level changes
    private func updateSettingsForSecurityLevel() {
        switch securityLevel {
        case .standard:
            // Standard defaults (can be adjusted)
            isEncryptionEnabled = false
            autoTokenize = false
            encryptFiles = false
            splitFiles = false
            showMessagePreview = true
            saveToDevice = true
        case .enhanced:
            // Enhanced defaults (more secure)
            isEncryptionEnabled = true
            autoTokenize = true
            encryptFiles = true // Encrypt files if global encryption is on
            splitFiles = true  // Split files by default
            showMessagePreview = true
            saveToDevice = true
        case .maximum:
            // Maximum defaults (most secure, enforced)
            isEncryptionEnabled = true // Enforced
            autoTokenize = true
            encryptFiles = true // Enforced
            splitFiles = true // Enforced
            showMessagePreview = false // Privacy focused
            saveToDevice = false // Privacy focused
        }
        // Note: UI elements like toggles might need to be disabled for Maximum
        saveSettings()
    }
    
    // Returns true if the message was sent directly, false if an alert was shown
    func sendMessage(_ content: String, force: Bool = false) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        if securityLevel == .maximum {
            isEncryptionEnabled = true
        }

        let detectedData = DataProtectionService.shared.detectSensitiveData(content)
        if !detectedData.isEmpty && securityLevel == .standard && !force {
            // Сохраняем сообщение для повторной отправки после подтверждения
            pendingSensitiveMessage = content
            alertMessage = "Sensitive data detected. Are you sure you want to send this message?"
            alertType = .sensitiveData
            showAlert = true
            print("--- DEBUG: Sensitive data detected, showing alert (Standard) ---")
            return false
        } else if !detectedData.isEmpty && (securityLevel == .enhanced || securityLevel == .maximum) {
            print("--- DEBUG: Sensitive data detected, auto/force tokenizing (Level: \(securityLevel)) ---")
            await tokenizeAndSendMessage(content)
            updateSecurityAnalytics()
            pendingSensitiveMessage = nil
            return true
        } else {
            print("--- DEBUG: No sensitive data detected or handled, sending directly ---")
            createAndSaveMessage(content: content, tokenizedContent: nil, tokens: [:], originalFilename: nil)
            updateSecurityAnalytics()
            pendingSensitiveMessage = nil
            return true
        }
    }
    
    func tokenizeAndSendMessage(_ content: String) async {
        isLoading = true
        defer { isLoading = false }
        print("--- DEBUG: tokenizeAndSendMessage CALLED ---")
        print("Input content: [\(content)]")
        
        // --- Maximum Level Enforcement ---
        if securityLevel == SecurityLevel.maximum {
            isEncryptionEnabled = true // Ensure encryption is always on
        }

        let result = DataProtectionService.shared.tokenizeSensitiveData(content)
        tokenizedText = result.tokenizedText
        // Store original values for potential reveal later
        // Clear previous tokens before adding new ones to avoid conflicts
        // sensitiveDataTokens.removeAll()
        sensitiveDataTokens.merge(result.tokens) { (_, new) in new }

        print("Output tokenizedText: [\(tokenizedText)]")
        print("Output tokens: \(sensitiveDataTokens)") // Print the stored tokens
        
        print("--- DEBUG: Creating message (tokenized) ---")
        createAndSaveMessage(content: content, tokenizedContent: tokenizedText, tokens: result.tokens, originalFilename: nil)
        updateSecurityAnalytics()
    }
    
    // --- Helper for Creating and Saving ---
    private func createAndSaveMessage(content: String, tokenizedContent: String?, tokens: [String: String], primaryPartURLString: String? = nil, secondaryPackageURLString: String? = nil, transferID: String? = nil, originalFilename: String? = nil) {
        // Enforce encryption on Maximum level
        let encrypted = (securityLevel == SecurityLevel.maximum) ? true : isEncryptionEnabled
        
        // Use the updated memberwise initializer for SecureMessage
        let message = SecureMessage(
            content: content,
            isEncrypted: encrypted,
            tokenizedContent: tokenizedContent,
            primaryPartURLString: primaryPartURLString,
            secondaryPackageURLString: secondaryPackageURLString,
            transferID: transferID, // Pass the ID to the initializer
            originalFilename: originalFilename // Pass the original filename (now optional)
            // Uses default values for id and timestamp from init
        )
        
        // Store original values mapped by token
        if tokenizedContent != nil {
            sensitiveDataTokens.merge(tokens) { (_, new) in new }
        }

        messages.append(message)
        print("Created message - content: [\(message.content)], tokenized: [\(message.tokenizedContent ?? "nil")], encrypted: \(message.isEncrypted)")

        // Uncomment saving to DB
        if saveToDevice || securityLevel != SecurityLevel.maximum {
            dbManager.saveMessage(message)
            print("--- DEBUG: Message saved to DB (SaveToDevice: \(saveToDevice), Level: \(securityLevel)) ---")
        } else {
            print("--- DEBUG: Message NOT saved to DB (SaveToDevice: \(saveToDevice), Level: \(securityLevel)) ---")
        }
        print("--- DEBUG: Message appended to messages array ---")
    }
    
    func sendFile(_ fileURL: URL) async {
        isLoading = true
        defer { isLoading = false }
        
        // Disable file sending at standard security level
        if securityLevel == .standard {
            alertMessage = "File sending is only available at Enhanced or Maximum security levels."
            showAlert = true
            return
        }
        
        // Enforce settings for Maximum level
        let shouldSplit = (securityLevel == SecurityLevel.maximum) ? true : splitFiles
        let shouldEncrypt = (securityLevel == SecurityLevel.maximum) ? true : encryptFiles
        
        print("--- ViewModel: Preparing to send file \(fileURL.lastPathComponent). Split=\(shouldSplit), Encrypt=\(shouldEncrypt)")
        
        do {
            var messageContent = "File: \(fileURL.lastPathComponent)"
            var primaryURLString: String? = nil
            var secondaryURLString: String? = nil
            var currentTransferID: String? = nil // Variable to hold the ID
            
            if shouldSplit {
                if shouldEncrypt {
                    // Split and Encrypt - Capture transferID
                    let (primaryPartURL, secondaryPackageURL, transferID) = try await FileTransmissionService.shared.splitAndEncryptFile(from: fileURL)
                    primaryURLString = primaryPartURL.absoluteString
                    secondaryURLString = secondaryPackageURL.absoluteString
                    currentTransferID = transferID // Store the ID
                    print("--- DEBUG: Set primaryURLString = \(primaryURLString ?? "nil")")
                    print("--- DEBUG: Set secondaryURLString = \(secondaryURLString ?? "nil")")
                    print("--- DEBUG: Set currentTransferID = \(currentTransferID ?? "nil")")
                    messageContent += " (Split & Encrypted)"
                    // Simulate "sending" primary part (e.g., confirm existence)
                    try await FileTransmissionService.shared.transmitPrimaryPart(url: primaryPartURL)
                    // (NO ALERT HERE)
                } else {
                    // Split only (Encryption logic might need refinement here if needed)
                    // For simplicity, we assume splitting implies encryption for now
                    alertMessage = "Configuration error: Splitting without encryption is not fully supported yet."
                    showAlert = true
                    return
                }
            } else if shouldEncrypt {
                 // Encrypt only (Placeholder - needs implementation in FileTransmissionService)
                 messageContent += " (Encrypted - TBD)"
                 alertMessage = "Encrypting single file not implemented yet."
                 showAlert = true
                 return
            }
            
            // Create the message entry directly without going through sendMessage
            let message = SecureMessage(
                content: messageContent,
                isEncrypted: shouldEncrypt,
                tokenizedContent: nil,
                primaryPartURLString: primaryURLString,
                secondaryPackageURLString: secondaryURLString,
                transferID: currentTransferID,
                originalFilename: fileURL.lastPathComponent
            )
            
            // Add message directly to the array and save to DB
            messages.append(message)
            if saveToDevice || securityLevel != SecurityLevel.maximum {
                dbManager.saveMessage(message)
            }
            // (NO ALERT HERE)
        } catch {
            print("--- ViewModel ERROR: Failed to process file: \(error.localizedDescription) ---")
            alertMessage = "Error processing file: \(error.localizedDescription)"
            alertType = nil
            showAlert = true
        }
        updateSecurityAnalytics()
    }
    
    private func extractURL(from text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        return matches?.first?.url?.absoluteString
    }
    
    func getOriginalContent(for message: SecureMessage) -> String {
        guard let tokenized = message.tokenizedContent else { return message.content }

        var revealedText = tokenized
        for (token, original) in sensitiveDataTokens {
            revealedText = revealedText.replacingOccurrences(of: token, with: original)
        }
        return revealedText
    }
    
    func toggleEncryption() {
        if securityLevel != SecurityLevel.maximum {
            isEncryptionEnabled.toggle()
            print("Encryption toggled: \(isEncryptionEnabled)")
        } else {
            print("Encryption cannot be disabled at Maximum security level.")
            // Optionally ensure it's set to true again, though updateSettings should handle it
            isEncryptionEnabled = true
        }
    }
    
    func loadMessages() {
        // Uncomment loading from DB
        if saveToDevice {
            messages = dbManager.fetchMessages()
            print("Loaded \(messages.count) messages from DB.")
        } else {
             print("Loading messages skipped as saveToDevice is false.")
             messages = [] // Start with empty messages if not loading from DB
        }
    }
    
    // Add this new method
    func updateMessageAfterReconstruction(transferID: String, decryptedFileURL: URL) {
        if let index = messages.firstIndex(where: { $0.transferID == transferID }) {
            let oldMessage = messages[index]
            let updatedMessage = SecureMessage(
                content: oldMessage.content,
                isFromCurrentUser: oldMessage.isFromCurrentUser,
                isEncrypted: oldMessage.isEncrypted,
                tokenizedContent: oldMessage.tokenizedContent,
                primaryPartURLString: oldMessage.primaryPartURLString,
                secondaryPackageURLString: oldMessage.secondaryPackageURLString,
                transferID: oldMessage.transferID,
                decryptedFileURL: decryptedFileURL,
                originalFilename: oldMessage.originalFilename
            )
            messages[index] = updatedMessage
            objectWillChange.send()
            print("--- DEBUG: updatedMessage.decryptedFileURL = \(updatedMessage.decryptedFileURL?.path ?? "nil") ---")
            // Update in database if needed
            if saveToDevice {
                dbManager.saveMessage(updatedMessage)
            }
            print("--- ViewModel: Updated message with decrypted file URL for transferID: \(transferID)")
        }
    }
    
    private func updateSecurityAnalytics() {
        protectedMessagesCount = messages.filter { $0.isEncrypted }.count
        encryptedFilesCount = messages.filter { $0.primaryPartURLString != nil && $0.isEncrypted }.count
        tokensFoundCount = messages.filter { $0.tokenizedContent != nil }.count
    }
    
    func confirmAndSendPendingMessage() async {
        if let pending = pendingSensitiveMessage {
            await sendMessage(pending, force: true)
        }
    }
}

enum AlertType {
    case sensitiveData
    case phishing
    case fileAlreadyProcessed
}

