import Foundation

class OpenedFilesHistory {
    static let shared = OpenedFilesHistory()
    private let key = "openedFilesHistory"
    
    private init() {}
    
    func load() -> [OpenedFile] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let files = try? JSONDecoder().decode([OpenedFile].self, from: data) else { return [] }
        return files
    }
    
    func save(_ files: [OpenedFile]) {
        if let data = try? JSONEncoder().encode(files) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func add(_ file: OpenedFile) {
        var files = load()
        // Не добавлять дубликаты
        if !files.contains(where: { $0.url == file.url }) {
            files.append(file)
            save(files)
        }
    }
} 