import SwiftUI
import Charts

struct SecurityAnalyticsView: View {
    @ObservedObject var viewModel: SafeRelayViewModel
    @State private var animateChart = false
    @State private var showCards = false
    @State private var animatedCounts: [String: Int] = [
        "messages": 0,
        "files": 0,
        "tokens": 0
    ]
    
    var body: some View {
        List {
            Section(header: Text("Security Analytics")) {
                VStack(spacing: 16) {
                    AnalyticsCard(
                        title: "Protected Messages",
                        count: animatedCounts["messages"] ?? 0,
                        icon: "lock.shield.fill",
                        color: .blue,
                        delay: 0.2
                    )
                    .opacity(showCards ? 1 : 0)
                    .offset(y: showCards ? 0 : 20)
                    
                    AnalyticsCard(
                        title: "Encrypted Files",
                        count: animatedCounts["files"] ?? 0,
                        icon: "doc.badge.lock.fill",
                        color: .green,
                        delay: 0.4
                    )
                    .opacity(showCards ? 1 : 0)
                    .offset(y: showCards ? 0 : 20)
                    
                    AnalyticsCard(
                        title: "Tokens Found",
                        count: animatedCounts["tokens"] ?? 0,
                        icon: "key.fill",
                        color: .purple,
                        delay: 0.6
                    )
                    .opacity(showCards ? 1 : 0)
                    .offset(y: showCards ? 0 : 20)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Security Trends")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity Overview")
                        .font(.headline)
                        .foregroundColor(Theme.secondaryText)
                        .opacity(showCards ? 1 : 0)
                        .offset(y: showCards ? 0 : 10)
                    
                    Chart {
                        BarMark(
                            x: .value("Category", "Protected Messages"),
                            y: .value("Count", animateChart ? viewModel.protectedMessagesCount : 0)
                        )
                        .foregroundStyle(.blue.gradient)
                        
                        BarMark(
                            x: .value("Category", "Encrypted Files"),
                            y: .value("Count", animateChart ? viewModel.encryptedFilesCount : 0)
                        )
                        .foregroundStyle(.green.gradient)
                        
                        BarMark(
                            x: .value("Category", "Tokens Found"),
                            y: .value("Count", animateChart ? viewModel.tokensFoundCount : 0)
                        )
                        .foregroundStyle(.purple.gradient)
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .opacity(showCards ? 1 : 0)
                    .scaleEffect(showCards ? 1 : 0.9)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Security Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showCards = true
            }
            
            // Анимируем счетчики
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateChart = true
            }
            
            // Анимируем числа в карточках
            animateCounts()
        }
    }
    
    private func animateCounts() {
        let duration: Double = 1.0
        let steps = 60
        
        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (duration * progress)) {
                withAnimation(.easeOut(duration: 0.1)) {
                    animatedCounts["messages"] = Int(Double(viewModel.protectedMessagesCount) * progress)
                    animatedCounts["files"] = Int(Double(viewModel.encryptedFilesCount) * progress)
                    animatedCounts["tokens"] = Int(Double(viewModel.tokensFoundCount) * progress)
                }
            }
        }
    }
}

struct AnalyticsCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let delay: Double
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryText)
                
                Text("\(count)")
                    .font(.title2.bold())
                    .foregroundColor(Theme.text)
                    .contentTransition(.numericText())
            }
            
            Spacer()
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.shadowDark.opacity(isHovered ? 0.15 : 0.1),
                radius: isHovered ? 8 : 5,
                x: 0,
                y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    NavigationView {
        SecurityAnalyticsView(viewModel: SafeRelayViewModel())
    }
}
