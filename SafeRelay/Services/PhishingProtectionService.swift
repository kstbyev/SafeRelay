import Foundation

class PhishingProtectionService {
    static let shared = PhishingProtectionService()
    
    private let urlSession: URLSession
    private var knownPhishingDomains: Set<String> = []
    private var lastUpdateTimestamp: Date?
    private let updateInterval: TimeInterval = 3600 // 1 hour
    
    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        self.urlSession = URLSession(configuration: config)
        
        Task {
            await updatePhishingDatabase()
        }
    }
    
    func scanURL(_ urlString: String) async throws -> PhishingDetectionResult {
        // Update database if needed
        if shouldUpdateDatabase {
            await updatePhishingDatabase()
        }
        
        guard let url = URL(string: urlString) else {
            throw PhishingError.invalidURL
        }
        
        // Check against known phishing domains
        if let host = url.host?.lowercased(),
           knownPhishingDomains.contains(host) {
            return .phishingDetected
        }
        
        // Check for suspicious URL patterns
        if isSuspiciousURL(url) {
            return .suspicious
        }
        
        // Perform real-time checks
        return try await performRealTimeChecks(url)
    }
    
    private var shouldUpdateDatabase: Bool {
        guard let lastUpdate = lastUpdateTimestamp else { return true }
        return Date().timeIntervalSince(lastUpdate) >= updateInterval
    }
    
    private func updatePhishingDatabase() async {
        // In a real implementation, this would fetch from a phishing database API
        // For demo purposes, we'll use a small hardcoded set
        knownPhishingDomains = [
            "known-phishing-site.com",
            "fake-bank-login.com",
            "suspicious-crypto.net"
        ]
        lastUpdateTimestamp = Date()
    }
    
    private func isSuspiciousURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        
        // Check for common phishing indicators
        let suspiciousPatterns = [
            "login",
            "signin",
            "account",
            "verify",
            "security",
            "update"
        ]
        
        let suspiciousTopLevelDomains = [
            ".tk", ".ml", ".ga", ".cf", ".gq"
        ]
        
        // Check for lookalike domains of popular services
        let lookalikeDomains = [
            "paypa1",
            "g00gle",
            "faceb00k",
            "appleid-verify"
        ]
        
        // Check for suspicious URL patterns
        if suspiciousPatterns.contains(where: { host.contains($0) }) &&
           url.pathComponents.contains(where: { suspiciousPatterns.contains($0.lowercased()) }) {
            return true
        }
        
        // Check for suspicious top-level domains
        if suspiciousTopLevelDomains.contains(where: { host.hasSuffix($0) }) {
            return true
        }
        
        // Check for lookalike domains
        if lookalikeDomains.contains(where: { host.contains($0) }) {
            return true
        }
        
        // Check for excessive subdomains
        let subdomainCount = host.components(separatedBy: ".").count
        if subdomainCount > 4 {
            return true
        }
        
        return false
    }
    
    private func performRealTimeChecks(_ url: URL) async throws -> PhishingDetectionResult {
        // In a real implementation, this would:
        // 1. Check SSL certificate validity
        // 2. Perform DNS reputation checks
        // 3. Check domain age
        // 4. Check for redirects
        // 5. Analyze page content for phishing indicators
        
        // For demo purposes, we'll just return a basic result
        return .safe
    }
}

enum PhishingDetectionResult {
    case safe
    case suspicious
    case phishingDetected
}

enum PhishingError: Error {
    case invalidURL
    case networkError
    case databaseUpdateFailed
} 