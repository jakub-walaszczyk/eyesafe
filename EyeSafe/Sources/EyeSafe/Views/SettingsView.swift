import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Binding var workMinutes: Double
    @Binding var breakSeconds: Double
    @Binding var soundEnabled: Bool
    @Binding var showTimerInMenuBar: Bool
    @State private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Work interval: \(Int(workMinutes)) min")
                    .font(.caption)
                Slider(value: $workMinutes, in: 1...60, step: 1)
                    .accessibilityLabel("Work interval")
                    .accessibilityValue("\(Int(workMinutes)) minutes")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Break duration: \(Int(breakSeconds)) sec")
                    .font(.caption)
                Slider(value: $breakSeconds, in: 5...120, step: 5)
                    .accessibilityLabel("Break duration")
                    .accessibilityValue("\(Int(breakSeconds)) seconds")
            }

            Toggle("Notification sound", isOn: $soundEnabled)
                .font(.caption)
                .accessibilityLabel("Enable notification sound")

            Toggle("Show timer in menu bar", isOn: $showTimerInMenuBar)
                .font(.caption)
                .accessibilityLabel("Show timer in menu bar")

            Toggle("Launch at login", isOn: $launchAtLogin)
                .font(.caption)
                .accessibilityLabel("Launch at login")
                .onChange(of: launchAtLogin) { _ in
                    do {
                        if launchAtLogin {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin.toggle()
                    }
                }
                .onAppear {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
        }
        .padding(.vertical, 4)
    }
}
