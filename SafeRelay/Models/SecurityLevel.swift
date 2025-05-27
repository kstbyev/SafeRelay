import Foundation
import SwiftUI

enum SecurityLevel: Int, CaseIterable, Identifiable {
    case standard
    case enhanced
    case maximum
    
    var id: Int { rawValue }
    
    var description: String {
        switch self {
        case .standard: return "Standard"
        case .enhanced: return "Enhanced"
        case .maximum: return "Maximum"
        }
    }
    
    var iconName: String {
        switch self {
        case .standard: return "shield"
        case .enhanced: return "shield.lefthalf.filled"
        case .maximum: return "shield.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .standard: return .blue
        case .enhanced: return .orange
        case .maximum: return .red
        }
    }
} 