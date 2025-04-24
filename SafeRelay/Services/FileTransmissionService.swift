import Foundation
import CryptoKit
import UniformTypeIdentifiers // Needed for file operations

class FileTransmissionService {
    static let shared = FileTransmissionService()
    
    private init() {}
    
    // Structure to hold the secondary part and the key
    struct SecondaryPackage: Codable {
        let secondaryPartData: Data
        let encryptionKeyData: Data
    }
    
    // Function to split, encrypt, and save file parts - now returns transferID
    func splitAndEncryptFile(from url: URL) async throws -> (primaryPartURL: URL, secondaryPackageURL: URL, transferID: String) {
        print("--- FileService: Starting split & encrypt for \(url.lastPathComponent) ---")
        
        // 1. Read file data
        guard url.startAccessingSecurityScopedResource() else {
            throw FileError.accessDenied(url.lastPathComponent)
        }
        let fileData = try Data(contentsOf: url)
        url.stopAccessingSecurityScopedResource()
        print("--- FileService: Read \(fileData.count) bytes ---")
        
        // 2. Generate unique encryption key AND transfer ID
        let encryptionKey = SymmetricKey(size: .bits256)
        let transferID = UUID().uuidString // Unique ID for this transfer
        print("--- FileService: Generated encryption key and transfer ID: \(transferID) ---")
        
        // 3. Encrypt the entire file data
        let sealedBox = try AES.GCM.seal(fileData, using: encryptionKey)
        guard let encryptedData = sealedBox.combined else {
            throw FileError.encryptionFailed("Could not get combined data from sealed box.")
        }
        print("--- FileService: Encrypted data size: \(encryptedData.count) bytes ---")
        
        // 4. Split encrypted data (e.g., 90/10 split)
        let totalSize = encryptedData.count
        let primaryPartSize = Int(Double(totalSize) * 0.9)
        // Ensure secondary part gets at least some data, even for small files
        let actualPrimarySize = max(0, min(primaryPartSize, totalSize - 1)) // Leave at least 1 byte for secondary
        
        let primaryPartData = encryptedData.prefix(actualPrimarySize)
        let secondaryPartData = encryptedData.suffix(totalSize - actualPrimarySize)
        print("--- FileService: Split into Primary (\(primaryPartData.count) bytes) and Secondary (\(secondaryPartData.count) bytes) ---")
        
        // 5. Create the secondary package
        let keyData = encryptionKey.withUnsafeBytes { Data($0) }
        let secondaryPackage = SecondaryPackage(secondaryPartData: secondaryPartData, encryptionKeyData: keyData)
        let encodedSecondaryPackage = try JSONEncoder().encode(secondaryPackage)
        print("--- FileService: Created secondary package (\(encodedSecondaryPackage.count) bytes) ---")
        
        // 6. Save parts to temporary directory using transferID in filenames
        let tempDir = FileManager.default.temporaryDirectory
        let originalFilename = url.deletingPathExtension().lastPathComponent
        
        // Create unique URLs incorporating the transferID
        let primaryPartFilename = "primary_\(transferID)_\(originalFilename).safeRelayPart"
        let secondaryPackageFilename = "secondary_\(transferID)_\(originalFilename).safeRelayPkg"
        let primaryPartURL = tempDir.appendingPathComponent(primaryPartFilename)
        let secondaryPackageURL = tempDir.appendingPathComponent(secondaryPackageFilename)
        
        // Write data to files
        try primaryPartData.write(to: primaryPartURL)
        try encodedSecondaryPackage.write(to: secondaryPackageURL)
        print("--- FileService: Saved parts to temporary URLs:")
        print("    Primary: \(primaryPartURL.path)")
        print("    Secondary Pkg: \(secondaryPackageURL.path)")
        
        return (primaryPartURL, secondaryPackageURL, transferID) // Return transferID
    }
    
    // New function to reconstruct and decrypt
    func reconstructAndDecryptFile(primaryPartURL: URL, secondaryPackageData: Data) async throws -> URL {
        print("--- FileService: Starting reconstruction ---")
        
        // 1. Decode the secondary package
        let secondaryPackage = try JSONDecoder().decode(SecondaryPackage.self, from: secondaryPackageData)
        let secondaryPartData = secondaryPackage.secondaryPartData
        let keyData = secondaryPackage.encryptionKeyData
        let encryptionKey = SymmetricKey(data: keyData)
        print("--- FileService: Decoded secondary package, Key size: \(keyData.count * 8) bits ---")

        // 2. Read the primary part data
        guard primaryPartURL.startAccessingSecurityScopedResource() else {
             throw FileError.accessDenied(primaryPartURL.lastPathComponent)
        }
        let primaryPartData = try Data(contentsOf: primaryPartURL)
        primaryPartURL.stopAccessingSecurityScopedResource()
         print("--- FileService: Read primary part (\(primaryPartData.count) bytes) ---")

        // 3. Combine encrypted parts
        let combinedEncryptedData = primaryPartData + secondaryPartData
        print("--- FileService: Combined encrypted data size: \(combinedEncryptedData.count) bytes ---")

        // 4. Decrypt the data
        let sealedBox = try AES.GCM.SealedBox(combined: combinedEncryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
        print("--- FileService: Decryption successful. Decrypted data size: \(decryptedData.count) bytes ---")

        // 5. Save decrypted data to a downloadable location
        let downloadsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        // Attempt to reconstruct original filename (need to pass it somehow, or use transferID)
        // For now, use a generic name
        let originalFilename = primaryPartURL.lastPathComponent
                                    .replacingOccurrences(of: "primary_", with: "")
                                    .replacingOccurrences(of: ".safeRelayPart", with: "")
        let decryptedFilename = "decrypted_\(originalFilename)"
        let decryptedFileURL = downloadsDirectory.appendingPathComponent(decryptedFilename)
        
        try decryptedData.write(to: decryptedFileURL)
        print("--- FileService: Saved decrypted file to: \(decryptedFileURL.path) ---")

        return decryptedFileURL
    }
    
    // Placeholder for transmitting the primary part (e.g., attaching to message)
    func transmitPrimaryPart(url: URL) async throws {
        // In a real app, this might involve uploading to a server or embedding in a message payload
        print("--- FileService: Transmitting primary part from \(url.lastPathComponent) (Simulated) ---")
        // For simulation, we might just confirm it exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileError.fileNotFound(url.lastPathComponent)
        }
    }
    
    // Placeholder for handling the secondary package (user needs to share this)
    func handleSecondaryPackage(url: URL) -> Data? {
         print("--- FileService: Handling secondary package at \(url.lastPathComponent) (Ready for sharing) ---")
         // This function might just return the Data for sharing via UIActivityViewController
         return try? Data(contentsOf: url)
    }
    
    // Error enum for file operations
    enum FileError: Error, LocalizedError {
        case accessDenied(String)
        case encryptionFailed(String)
        case fileNotFound(String)
        
        var errorDescription: String? {
            switch self {
            case .accessDenied(let name): return "Access denied for file: \(name)"
            case .encryptionFailed(let reason): return "Encryption failed: \(reason)"
            case .fileNotFound(let name): return "Temporary file part not found: \(name)"
            }
        }
    }
}

enum FileTransmissionError: Error {
    case encryptionFailed
    case transmissionFailed
    case invalidFileData
}