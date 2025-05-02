import Foundation
import CryptoKit

struct SecureMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isEncrypted: Bool
    let tokenizedContent: String?
    let primaryPartURLString: String?
    let secondaryPackageURLString: String?
    let transferID: String?
    var decryptedFileURL: URL?
    var originalFilename: String?
    
    init(
        content: String,
        isEncrypted: Bool,
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
        self.isEncrypted = isEncrypted
        self.tokenizedContent = tokenizedContent
        self.primaryPartURLString = primaryPartURLString
        self.secondaryPackageURLString = secondaryPackageURLString
        self.transferID = transferID
        self.decryptedFileURL = decryptedFileURL
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
}

extension SecureMessage {
    var isSplit: Bool {
        primaryPartURLString != nil && secondaryPackageURLString != nil
    }
} 