import Foundation

class DatabaseManager {
    static let shared = DatabaseManager()
    private let messagesKey = "savedMessages"
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    // Saves a single message by appending it to the saved array
    func saveMessage(_ message: SecureMessage) {
        var currentMessages = fetchMessagesInternal() // Fetch existing
        currentMessages.append(message) // Append new one
        
        // Encode the updated array and save
        do {
            let encodedData = try JSONEncoder().encode(currentMessages)
            defaults.set(encodedData, forKey: messagesKey)
            print("--- DB DEBUG: Saved \(currentMessages.count) messages to UserDefaults.")
        } catch {
            print("--- DB ERROR: Failed to encode messages for saving: \(error.localizedDescription)")
        }
    }
    
    // Fetches all saved messages
    func fetchMessages() -> [SecureMessage] {
         return fetchMessagesInternal()
    }
    
    // Internal fetch to avoid code duplication
    private func fetchMessagesInternal() -> [SecureMessage] {
        guard let savedData = defaults.data(forKey: messagesKey) else {
            print("--- DB DEBUG: No message data found in UserDefaults.")
            return [] // No saved messages found
        }
        
        // Decode the data back into an array of messages
        do {
            let decodedMessages = try JSONDecoder().decode([SecureMessage].self, from: savedData)
            print("--- DB DEBUG: Fetched \(decodedMessages.count) messages from UserDefaults.")
            return decodedMessages
        } catch {
            print("--- DB ERROR: Failed to decode saved messages: \(error.localizedDescription)")
            return [] // Return empty if decoding fails
        }
    }
    
    // Optional: Function to clear all messages (e.g., for testing or privacy)
    func clearAllMessages() {
        defaults.removeObject(forKey: messagesKey)
        print("--- DB DEBUG: Cleared all messages from UserDefaults.")
    }
} 