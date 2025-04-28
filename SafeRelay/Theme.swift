import SwiftUI

struct Theme {
    // MARK: - Adaptive Colors
    static var background: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 30/255, green: 32/255, blue: 38/255, alpha: 1) : UIColor(red: 240/255, green: 242/255, blue: 245/255, alpha: 1)
        })
    }
    static var card: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 40/255, green: 42/255, blue: 50/255, alpha: 1) : UIColor(red: 250/255, green: 252/255, blue: 255/255, alpha: 1)
        })
    }
    static var accent: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 80/255, green: 120/255, blue: 255/255, alpha: 1) : UIColor(red: 60/255, green: 120/255, blue: 255/255, alpha: 1)
        })
    }
    static var text: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
        })
    }
    static var secondaryText: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.8, alpha: 1) : UIColor(white: 0.3, alpha: 1)
        })
    }
    static var shadowLight: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.1, alpha: 0.7) : UIColor.white.withAlphaComponent(0.7)
        })
    }
    static var shadowDark: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.7) : UIColor(white: 0.7, alpha: 1)
        })
    }

    // MARK: - Neumorphic Shadows
    static let shadowRadius: CGFloat = 8
    static let shadowOffset: CGFloat = 6
    static let cornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 12
    static let elementSpacing: CGFloat = 16
    static let smallSpacing: CGFloat = 8
    static let largeSpacing: CGFloat = 24

    // MARK: - Fonts
    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let subtitleFont = Font.system(size: 18, weight: .medium, design: .rounded)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .rounded)
    static let captionFont = Font.system(size: 13, weight: .medium, design: .rounded)

    // MARK: - Neumorphic Modifier
    struct Neumorphic: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(Theme.card)
                .cornerRadius(Theme.cornerRadius)
                .shadow(color: Theme.shadowLight, radius: Theme.shadowRadius, x: -Theme.shadowOffset, y: -Theme.shadowOffset)
                .shadow(color: Theme.shadowDark, radius: Theme.shadowRadius, x: Theme.shadowOffset, y: Theme.shadowOffset)
        }
    }

    // MARK: - Button Style
    struct CustomButton: ViewModifier {
        let isPrimary: Bool
        func body(content: Content) -> some View {
            content
                .padding(.horizontal, Theme.elementSpacing)
                .padding(.vertical, Theme.smallSpacing)
                .background(isPrimary ? Theme.accent : Theme.card)
                .foregroundColor(isPrimary ? Color.white : Theme.text)
                .cornerRadius(Theme.cornerRadius)
                .shadow(color: isPrimary ? Theme.accent.opacity(0.2) : Theme.shadowDark.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Message Bubble Style
    struct MessageBubble: ViewModifier {
        let isEncrypted: Bool
        func body(content: Content) -> some View {
            content
                .padding(.horizontal, Theme.elementSpacing)
                .padding(.vertical, Theme.smallSpacing)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(isEncrypted ? Theme.accent.opacity(0.08) : Theme.card)
                )
                .shadow(color: Theme.shadowDark.opacity(0.08), radius: 2, x: 0, y: 1)
        }
    }
}

extension View {
    func neumorphic() -> some View {
        self.modifier(Theme.Neumorphic())
    }
    func customButtonStyle(isPrimary: Bool = false) -> some View {
        self.modifier(Theme.CustomButton(isPrimary: isPrimary))
    }
    func messageBubbleStyle(isEncrypted: Bool) -> some View {
        self.modifier(Theme.MessageBubble(isEncrypted: isEncrypted))
    }
} 