import SwiftUI

struct CustomNavBar: View {
    var title: String
    var onProfile: (() -> Void)? = nil
    var onSettings: (() -> Void)? = nil
    var onSearch: (() -> Void)? = nil
    var onShield: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Theme.elementSpacing) {
            // Аватар
            Button(action: { onProfile?() }) {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(Theme.accent)
                    .neumorphic()
            }
            .buttonStyle(.plain)

            // Название
            Text(title)
                .font(Theme.titleFont)
                .foregroundColor(Theme.text)
                .padding(.leading, 4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            // Поиск
            Button(action: { onSearch?() }) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(Theme.secondaryText)
                    .padding(8)
                    .background(Theme.card)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Shield (статус безопасности)
            Button(action: { onShield?() }) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Theme.card)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Настройки
            Button(action: { onSettings?() }) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(Theme.secondaryText)
                    .padding(8)
                    .background(Theme.card)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.elementSpacing)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Theme.background)
        .neumorphic()
        .shadow(radius: 2)
    }
} 