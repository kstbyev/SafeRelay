import Foundation

struct OpenedFile: Codable, Identifiable {
    let id: UUID
    let urlString: String
    let fileName: String
    let timestamp: Date
    let isEncrypted: Bool
    
    init(url: URL, fileName: String, isEncrypted: Bool = false) {
        self.id = UUID()
        self.urlString = url.absoluteString
        self.fileName = fileName
        self.timestamp = Date()
        self.isEncrypted = isEncrypted
    }
    
    var url: URL? {
        URL(string: urlString)
    }
} 