import SwiftUI
import CloudKit

struct CloudSyncView: View {
    @ObservedObject var viewModel: SafeRelayViewModel
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var lastSyncDate: Date?
    @State private var syncProgress: Double = 0
    @State private var showSyncAnimation = false
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    // Статус синхронизации
                    HStack {
                        Image(systemName: isSyncing ? "arrow.triangle.2.circlepath.icloud.fill" : "checkmark.icloud.fill")
                            .font(.title2)
                            .foregroundColor(isSyncing ? .blue : .green)
                            .rotationEffect(.degrees(showSyncAnimation ? 360 : 0))
                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: showSyncAnimation)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isSyncing ? "Syncing..." : "Synced")
                                .font(.headline)
                            if let date = lastSyncDate {
                                Text("Last sync: \(date.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundColor(Theme.secondaryText)
                            }
                        }
                        
                        Spacer()
                        
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                    .padding()
                    .background(Theme.card)
                    .cornerRadius(Theme.cornerRadius)
                    
                    // Прогресс синхронизации
                    if isSyncing {
                        ProgressView(value: syncProgress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                            .padding(.horizontal)
                    }
                    
                    // Кнопка синхронизации
                    Button(action: syncWithCloud) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            Text("Sync Now")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(Theme.cornerRadius)
                    }
                    .disabled(isSyncing)
                    .opacity(isSyncing ? 0.6 : 1)
                }
                .padding(.vertical, 8)
            }
            
            if let error = syncError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.callout)
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(Theme.cornerRadius)
                }
            }
            
            Section(header: Text("Sync Settings")) {
                Toggle("Auto Sync", isOn: .constant(true))
                Toggle("Sync on Cellular", isOn: .constant(false))
                Toggle("Sync Files", isOn: .constant(true))
                Toggle("Sync Messages", isOn: .constant(true))
            }
        }
        .navigationTitle("Cloud Sync")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func syncWithCloud() {
        guard !isSyncing else { return }
        
        isSyncing = true
        showSyncAnimation = true
        syncError = nil
        syncProgress = 0
        
        // Имитация процесса синхронизации
        Task {
            do {
                // Проверяем доступность iCloud
                let container = CKContainer.default()
                try await container.accountStatus()
                
                // Имитируем прогресс синхронизации
                for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                    try await Task.sleep(nanoseconds: 200_000_000) // 0.2 секунды
                    await MainActor.run {
                        syncProgress = progress
                    }
                }
                
                // Завершаем синхронизацию
                await MainActor.run {
                    isSyncing = false
                    showSyncAnimation = false
                    lastSyncDate = Date()
                    syncProgress = 1.0
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    showSyncAnimation = false
                    syncError = "Failed to sync: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        CloudSyncView(viewModel: SafeRelayViewModel())
    }
} 