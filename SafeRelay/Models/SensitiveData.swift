import Foundation

// Conform to CustomStringConvertible
enum SensitiveData: CustomStringConvertible {
    case creditCard(String)
    case email(String)
    case phone(String)
    case name(String)
    case sensitivePhrase(String)
    
    var tokenPrefix: String {
        switch self {
        case .creditCard: return "CARD"
        case .email: return "EMAIL"
        case .phone: return "PHONE"
        case .name: return "NAME"
        case .sensitivePhrase: return "PHRASE"
        }
    }
    
    var value: String {
        switch self {
        case .creditCard(let v), .email(let v), .phone(let v), .name(let v), .sensitivePhrase(let v):
            return v
        }
    }
    
    // Add description property for CustomStringConvertible
    var description: String {
        return "\(tokenPrefix): \(value)"
    }
    
    // Add range(in:) helper method
    func range(in text: String) -> Range<String.Index>? {
        // Use options for robust matching if needed, e.g., case insensitive
        return text.range(of: self.value, options: .literal)
    }
} 

