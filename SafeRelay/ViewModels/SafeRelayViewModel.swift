import Foundation
import SwiftUI
import CryptoKit
import NaturalLanguage
import Combine

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
    
    private let dataProtectionService = DataProtectionService.shared
    private let phishingProtectionService = PhishingProtectionService.shared
    private let fileTransmissionService = FileTransmissionService.shared
    
    // Make tokens accessible to views
    var sensitiveDataTokens: [String: String] = [:]
    
    // Uncomment DatabaseManager usage
    private var dbManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSettings()
        loadMessages() // Now this should work
        updateSettingsForSecurityLevel()
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
    func sendMessage(_ content: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        // --- Maximum Level Enforcement ---
        if securityLevel == .maximum {
            isEncryptionEnabled = true // Ensure encryption is always on
        }

        // --- Phishing Detection (Enhanced & Maximum) ---
        if securityLevel == .enhanced || securityLevel == .maximum {
            let phishingDetected = DataProtectionService.shared.detectPhishing(content)
            if !phishingDetected.isEmpty {
                alertMessage = "Potential phishing attempt detected: \(phishingDetected.joined(separator: ", ")). Send anyway?"
                alertType = .phishing
                showAlert = true
                print("--- DEBUG: Phishing detected: [\(phishingDetected)] ---")
                return false // Show alert, don't send yet
            }
        }

        // --- Sensitive Data Detection ---
        let detectedData = DataProtectionService.shared.detectSensitiveData(content)
        if !detectedData.isEmpty && !autoTokenize && securityLevel != .maximum {
            // Ask user if not auto-tokenizing and not Maximum level
            alertMessage = "Sensitive data detected. Tokenize before sending?"
            alertType = .sensitiveData
            showAlert = true
            print("--- DEBUG: Sensitive data detected, showing alert (Manual/Standard/Enhanced) ---")
            return false // Show alert, don't send yet
        } else if !detectedData.isEmpty && (autoTokenize || securityLevel == .maximum) {
            // Auto-tokenize or force tokenize on Maximum
            print("--- DEBUG: Sensitive data detected, auto/force tokenizing (Level: \(securityLevel)) ---")
            await tokenizeAndSendMessage(content)
            return true // Message sent after tokenization
        } else {
            // No sensitive data or already handled
            print("--- DEBUG: No sensitive data detected or handled, sending directly ---")
            createAndSaveMessage(content: content, tokenizedContent: nil, tokens: [:])
            return true // Message sent directly
        }
    }
    
    func tokenizeAndSendMessage(_ content: String) async {
        isLoading = true
        defer { isLoading = false }
        print("--- DEBUG: tokenizeAndSendMessage CALLED ---")
        print("Input content: [\(content)]")
        
        // --- Maximum Level Enforcement ---
        if securityLevel == .maximum {
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
        createAndSaveMessage(content: content, tokenizedContent: tokenizedText, tokens: result.tokens)
    }
    
    // --- Helper for Creating and Saving --- 
    private func createAndSaveMessage(content: String, tokenizedContent: String?, tokens: [String: String]) {
        // Enforce encryption on Maximum level
        let encrypted = (securityLevel == .maximum) ? true : isEncryptionEnabled
        
        // Use the custom init defined in SecureMessage, which handles id and timestamp internally
        let message = SecureMessage(
            content: content,
            isEncrypted: encrypted,
            tokenizedContent: tokenizedContent
            // id, timestamp, and fileParts are set by the custom init
        )
        
        // Store original values mapped by token
        if let tc = tokenizedContent {
            sensitiveDataTokens.merge(tokens) { (_, new) in new }
        }

        messages.append(message)
        print("Created message - content: [\(message.content)], tokenized: [\(message.tokenizedContent ?? "nil")], encrypted: \(message.isEncrypted)")

        // Uncomment saving to DB
        if saveToDevice || securityLevel != .maximum { 
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
        
        // Enforce settings for Maximum level
        let shouldSplit = (securityLevel == .maximum) ? true : splitFiles
        let shouldEncrypt = (securityLevel == .maximum) ? true : encryptFiles
        
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
                    messageContent += " (Split & Encrypted)"
                    // Simulate "sending" primary part (e.g., confirm existence)
                    try await FileTransmissionService.shared.transmitPrimaryPart(url: primaryPartURL)
                    // Prepare alert for user to handle secondary package
                    alertMessage = "File split and encrypted. Main part sent (simulated). Please share the secondary package separately."
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
            } else {
                 // Send as is (Placeholder - needs implementation)
                 messageContent += " (Plain - TBD)"
                 alertMessage = "Sending plain file not implemented yet."
                 showAlert = true
                 return
            }
            
            // Create the message entry, passing the transferID
            createAndSaveMessage(
                content: messageContent,
                tokenizedContent: nil,
                tokens: [:],
                primaryPartURLString: primaryURLString,
                secondaryPackageURLString: secondaryURLString,
                transferID: currentTransferID // Pass the ID
            )
            
            // Show confirmation / instruction alert
            alertType = nil // Just an informational alert
            showAlert = true // Alert message set within the if/else block

        } catch {
            print("--- ViewModel ERROR: Failed to process file: \(error.localizedDescription) ---")
            alertMessage = "Error processing file: \(error.localizedDescription)"
            alertType = nil
            showAlert = true
        }
    }
    
    // --- Helper for Creating and Saving (needs update for new properties) --- 
    private func createAndSaveMessage(content: String, tokenizedContent: String?, tokens: [String: String], primaryPartURLString: String? = nil, secondaryPackageURLString: String? = nil, transferID: String? = nil) {
        // Enforce encryption on Maximum level
        let encrypted = (securityLevel == .maximum) ? true : isEncryptionEnabled
        
        // Use the updated memberwise initializer for SecureMessage
        let message = SecureMessage(
            content: content,
            isEncrypted: encrypted,
            tokenizedContent: tokenizedContent,
            primaryPartURLString: primaryPartURLString,
            secondaryPackageURLString: secondaryPackageURLString,
            transferID: transferID // Pass the ID to the initializer
            // Uses default values for id and timestamp from init
        )
        
        // Store original values mapped by token
        if tokenizedContent != nil {
            sensitiveDataTokens.merge(tokens) { (_, new) in new }
        }

        messages.append(message)
        print("Created message - content: [\(message.content)], tokenized: [\(message.tokenizedContent ?? "nil")], encrypted: \(message.isEncrypted)")

        // Uncomment saving to DB
        if saveToDevice || securityLevel != .maximum { 
            dbManager.saveMessage(message)
            print("--- DEBUG: Message saved to DB (SaveToDevice: \(saveToDevice), Level: \(securityLevel)) ---")
        } else {
            print("--- DEBUG: Message NOT saved to DB (SaveToDevice: \(saveToDevice), Level: \(securityLevel)) ---")
        }
        print("--- DEBUG: Message appended to messages array ---")
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
        if securityLevel != .maximum {
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
            // Create a new message with updated properties
            var updatedMessage = messages[index]
            updatedMessage.decryptedFileURL = decryptedFileURL
            // Update the message in the array
            messages[index] = updatedMessage
            // Update in database if needed
            if saveToDevice {
                dbManager.saveMessage(updatedMessage)
            }
            print("--- ViewModel: Updated message with decrypted file URL for transferID: \(transferID)")
        }
    }
}

enum AlertType {
    case sensitiveData
    case phishing
}

