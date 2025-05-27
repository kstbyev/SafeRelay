import Foundation
import CryptoKit

struct SecureMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isFromCurrentUser: Bool
    let isEncrypted: Bool
    var tokenizedContent: String?
    var tokens: [String: String]?
    let primaryPartURLString: String?
    let secondaryPackageURLString: String?
    let transferID: String?
    var decryptedFileURLString: String?
    var originalFilename: String?
    
    var decryptedFileURL: URL? {
        get { decryptedFileURLString.flatMap { URL(string: $0) } }
        set { decryptedFileURLString = newValue?.absoluteString }
    }
    
    init(
        content: String,
        isFromCurrentUser: Bool = true,
        isEncrypted: Bool = true,
        tokenizedContent: String? = nil,
        primaryPartURLString: String? = nil,
        secondaryPackageURLString: String? = nil,
        transferID: String? = nil,
        decryptedFileURL: URL? = nil,
        originalFilename: String? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFromCurrentUser = isFromCurrentUser
        self.isEncrypted = isEncrypted
        self.tokenizedContent = tokenizedContent
        self.primaryPartURLString = primaryPartURLString
        self.secondaryPackageURLString = secondaryPackageURLString
        self.transferID = transferID
        self.decryptedFileURLString = decryptedFileURL?.absoluteString
        self.originalFilename = originalFilename
    }
    
    func encrypt() -> SecureMessage {
        // Implementation for message encryption
        return self
    }
    
    func tokenize() -> SecureMessage {
        // Implementation for data tokenization
        return self
    }
    
    // Для тестирования
    static let sampleMessages = [
        SecureMessage(content: "Hello!", isFromCurrentUser: true),
        SecureMessage(content: "Hi there!", isFromCurrentUser: false),
        SecureMessage(content: "How are you?", isFromCurrentUser: true)
    ]
} 

extension SecureMessage {
    var isSplit: Bool {
        primaryPartURLString != nil && secondaryPackageURLString != nil
    }
} 