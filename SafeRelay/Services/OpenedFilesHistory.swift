import Foundation
import LocalAuthentication

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
        // Don't add duplicate 
        if !files.contains(where: { $0.urlString == file.urlString }) {
            files.append(file)
            save(files)
        }
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

func authenticateUser(completion: @escaping (Bool) -> Void) {
    let context = LAContext()
    var error: NSError?
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Access SafeRelay+") { success, _ in
            completion(success)
        }
    } else {
        completion(false)
    }
}

func fetchConfigFromServer() {
    let url = URL(string: "https://secure.safepolicy.example.com/config")!
    var request = URLRequest(url: url)
    request.timeoutInterval = 10
    // SSL pinning
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        
    }
    task.resume()
} 


