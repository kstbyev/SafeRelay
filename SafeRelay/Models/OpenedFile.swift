import Foundation

struct OpenedFile: Identifiable, Codable, Equatable {
    let id: UUID
    let filename: String
    let url: URL
    let dateOpened: Date
} 