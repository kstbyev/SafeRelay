import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("securityLevel") private var securityLevel = SecurityLevel.standard
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("soundAlerts") private var soundAlerts = true
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Security Level", selection: $securityLevel) {
                        Text("Standard").tag(SecurityLevel.standard)
                        Text("Enhanced").tag(SecurityLevel.enhanced)
                        Text("Maximum").tag(SecurityLevel.maximum)
                    }
                } header: {
                    Text("Security")
                }
                
                Section {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    Toggle("Sound Alerts", isOn: $soundAlerts)
                } header: {
                    Text("Notifications")
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
} 