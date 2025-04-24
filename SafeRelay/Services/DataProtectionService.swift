import Foundation
import NaturalLanguage
import CryptoKit

class DataProtectionService {
    static let shared = DataProtectionService()
    
    private let creditCardPattern = #"\b(?:\d[ -]*?){13,19}\b"#
    private let emailPattern = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}"#
    private let phonePattern = #"\b(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{1,5}\)?[-.\s]?)?\d{1,5}[-.\s]?\d{1,5}[-.\s]?\d{1,9}\b"#
    private let namePattern = #"\b[А-ЯЁA-Z][а-яёa-z]+(?:\s+[А-ЯЁA-Z][а-яёa-z]+){1,2}\b"#
    
    private let sensitivityAnalyzer: NLTagger = {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        return tagger
    }()
    
    private var encryptionKey: SymmetricKey?
    
    // List of potentially suspicious keywords for phishing detection
    private let phishingKeywords: Set<String> = [
        "пароль", "логин", "войти", "аккаунт", "учетная запись", "верификация",
        "подтвердить", "банк", "кредит", "карта", "выигрыш", "приз",
        "наследство", "срочно", "немедленно", "бесплатно", "подарок",
        "обновить", "безопасность", "конфиденциально", "личные данные",
        "password", "login", "verify", "account", "bank", "credit", "card",
        "prize", "winner", "urgent", "immediate", "free", "gift", "update",
        "security", "confidential", "personal data", "click here"
    ]
    
    // Simple regex for detecting potential URLs, now with embedded case-insensitive flag
    private let urlPattern = #"(?i)(?:https?://|www\.)[\w\.-]+\.[a-z]{2,}(?:[\w/\.\?=&%-]*)?"#
    
    init() {
        // Generate a persistent encryption key for tokens
        if let keyData = KeychainService.shared.retrieveKey(identifier: "tokenization_key") {
            self.encryptionKey = SymmetricKey(data: keyData)
        } else {
            let newKey = SymmetricKey(size: .bits256)
            self.encryptionKey = newKey
            try? KeychainService.shared.storeKey(newKey.withUnsafeBytes { Data($0) }, identifier: "tokenization_key")
        }
    }
    
    func detectSensitiveData(_ text: String) -> [SensitiveData] {
        var detectedData: [SensitiveData] = []
        var processedRanges: [Range<String.Index>] = []

        print("--- DEBUG: Starting Sensitive Data Detection for: [\(text)] ---")

        func isRangeProcessed(_ range: Range<String.Index>) -> Bool {
            let overlaps = processedRanges.contains { $0.overlaps(range) }
            if overlaps {
                print("--- DEBUG: Range \(range) overlaps with processed ranges.")
            }
            return overlaps
        }

        func addDetectedData(_ data: SensitiveData, range: Range<String.Index>) {
            if !isRangeProcessed(range) {
                print("--- DEBUG: ADDING \(data.tokenPrefix) at range \(range): [\(data.value)]")
                detectedData.append(data)
                processedRanges.append(range)
            } else {
                print("--- DEBUG: SKIPPING \(data.tokenPrefix) at range \(range) (already processed): [\(data.value)]")
            }
        }

        // 1. Credit Cards
        print("--- DEBUG: Checking for Credit Cards ---")
        let cardMatches = text.matches(of: try! Regex(creditCardPattern))
        for match in cardMatches {
            print("--- DEBUG: Potential Card Match at \(match.range): [\(text[match.range])]")
            let potentialCard = String(text[match.range])
            let digitsOnly = potentialCard.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if isValidCreditCard(digitsOnly) {
                print("--- DEBUG: Valid Card found: [\(potentialCard)]")
                addDetectedData(SensitiveData.creditCard(potentialCard), range: match.range)
            } else {
                print("--- DEBUG: Potential Card FAILED Luhn check: [\(potentialCard)]")
            }
        }

        // 2. Emails
        print("--- DEBUG: Checking for Emails ---")
        let emailMatches = text.matches(of: try! Regex(emailPattern))
        for match in emailMatches {
             print("--- DEBUG: Potential Email Match at \(match.range): [\(text[match.range])]")
            let email = String(text[match.range])
            if isValidEmail(email) {
                 print("--- DEBUG: Valid Email found: [\(email)]")
                addDetectedData(SensitiveData.email(email), range: match.range)
            } else {
                 print("--- DEBUG: Potential Email FAILED validation: [\(email)]")
            }
        }

        // 3. Phone Numbers
        print("--- DEBUG: Checking for Phone Numbers ---")
        let phoneMatches = text.matches(of: try! Regex(phonePattern))
        for match in phoneMatches {
            print("--- DEBUG: Potential Phone Match at \(match.range): [\(text[match.range])]")
            let phone = String(text[match.range])
            let phoneDigitsOnly = phone.filter { $0.isNumber }

            // Check if this potential phone number ALSO matches the credit card pattern structure
            // This helps filter out card numbers that failed the Luhn check
            let alsoMatchesCardPattern = phone.wholeMatch(of: try! Regex(creditCardPattern)) != nil

            if !alsoMatchesCardPattern && phoneDigitsOnly.count >= 7 {
                 print("--- DEBUG: Valid Phone found (Passed card structure check & count check): [\(phone)]")
                addDetectedData(SensitiveData.phone(phone), range: match.range)
            } else {
                if alsoMatchesCardPattern {
                     print("--- DEBUG: Potential Phone REJECTED (Matched card pattern structure): [\(phone)]")
                } else {
                     print("--- DEBUG: Potential Phone FAILED count check: [\(phone)]")
                }
            }
        }

        // 5. Names (Regex first)
        print("--- DEBUG: Checking for Names (Regex) ---")
        let nameRegexMatches = text.matches(of: try! Regex(namePattern))
        for match in nameRegexMatches {
            print("--- DEBUG: Potential Name Match (Regex) at \(match.range): [\(text[match.range])]")
            addDetectedData(SensitiveData.name(String(text[match.range])), range: match.range)
        }

        // 6. Natural language sensitivity analysis (as fallback/complement)
        print("--- DEBUG: Checking for Sensitive Phrases (NLTagger) ---")
        sensitivityAnalyzer.string = text
        sensitivityAnalyzer.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange in
            if let tag = tag, (tag == .personalName || tag == .organizationName || tag == .placeName) {
                print("--- DEBUG: Potential Phrase Match (NLTagger - \(tag.rawValue)) at \(tokenRange): [\(text[tokenRange])]")
                addDetectedData(SensitiveData.sensitivePhrase(String(text[tokenRange])), range: tokenRange)
            }
            return true
        }

        // Sort by position
        detectedData.sort { ($0.range(in: text)?.lowerBound ?? text.startIndex) < ($1.range(in: text)?.lowerBound ?? text.startIndex) }
        
        print("--- DEBUG: Final Detected Data (Sorted): \(detectedData)")
        return detectedData
    }
    
    func tokenizeSensitiveData(_ text: String) -> (tokenizedText: String, tokens: [String: String]) {
        var tokenizedText = text
        var tokens: [String: String] = [:]
        
        let detectedData = detectSensitiveData(text)
        print("--- DEBUG: Detected sensitive data: \(detectedData)")
        
        for data in detectedData {
            let token = generateSecureToken(for: data)
            let originalValue = data.value
            // Use range-based replacement for more safety with overlapping potential matches
            if let range = tokenizedText.range(of: originalValue, options: .literal) {
               tokenizedText.replaceSubrange(range, with: token)
                tokens[token] = originalValue
                print("--- DEBUG: Tokenized \(data.tokenPrefix): [\(originalValue)] -> [\(token)]")
            } else {
                 print("--- DEBUG: Failed to find range for replacement: [\(originalValue)]")
            }
        }
        
        return (tokenizedText, tokens)
    }
    
    private func generateSecureToken(for data: SensitiveData) -> String {
        guard let key = encryptionKey else {
            return "\(data.tokenPrefix)_\(UUID().uuidString.prefix(8))" // Fallback method
        }
        
        let prefix = data.tokenPrefix
        let uniqueId = UUID().uuidString.prefix(8)
        let tokenData = Data((prefix + String(uniqueId)).utf8)
        
        // Encrypt the token data
        let sealedBox = try? AES.GCM.seal(tokenData, using: key)
        let encryptedToken = sealedBox?.combined?.base64EncodedString() ?? String(uniqueId)
        
        return "\(prefix)_\(encryptedToken.prefix(16))"
    }
    
    // Validation helpers
    private func isValidCreditCard(_ number: String) -> Bool {
        // 1. Remove non-digit characters
        let digitsOnly = number.filter { $0.isNumber }
        
        // 2. Check length (must be done on digitsOnly)
        guard digitsOnly.count >= 13 && digitsOnly.count <= 19 else {
            print("--- DEBUG Luhn Check: Failed length check (\(digitsOnly.count)) for [\(number)]")
            return false
        }
        
        // 3. Apply Luhn algorithm
        var sum = 0
        let reversedDigits = digitsOnly.reversed().map { Int(String($0))! }
        
        for (index, digit) in reversedDigits.enumerated() {
            if index % 2 == 1 { // Double every second digit from the right
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        
        let isValid = sum % 10 == 0
        print("--- DEBUG Luhn Check: Digits='\(digitsOnly)', Sum=\(sum), IsValid=\(isValid) for [\(number)]")
        return isValid
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailPattern)
        return emailPredicate.evaluate(with: email)
    }
    
    // New function for phishing detection
    func detectPhishing(_ text: String) -> [String] {
        var findings: [String] = []
        let lowercasedText = text.lowercased()
        
        // 1. Check for keywords
        for keyword in phishingKeywords {
            if lowercasedText.contains(keyword) {
                findings.append("Keyword: '\(keyword)'")
            }
        }
        
        // 2. Check for URLs (basic)
        let urlMatches = text.matches(of: try! Regex(urlPattern))
        if !urlMatches.isEmpty {
            // In a real app, you'd scan these URLs against a blocklist/API
            findings.append("Contains URL(s)") 
        }
        
        // Remove duplicates
        return Array(Set(findings))
    }
}