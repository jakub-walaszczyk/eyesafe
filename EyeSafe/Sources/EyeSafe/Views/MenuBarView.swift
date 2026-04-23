import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: TimerViewModel
    @AppStorage("workMinutes") private var workMinutes: Double = 20
    @AppStorage("breakSeconds") private var breakSeconds: Double = 20
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar: Bool = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            headerSection
            progressSection
            controlsSection
            Divider()
            bottomSection
        }
        .padding(16)
        .frame(width: 260)
        .onChange(of: workMinutes) { _ in syncSettings() }
        .onChange(of: breakSeconds) { _ in syncSettings() }
        .onChange(of: soundEnabled) { _ in syncSettings() }
        .onAppear { syncSettings() }
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Image(systemName: viewModel.menuBarIcon)
                .font(.system(size: 28))
                .foregroundStyle(viewModel.state.isBreakTime ? .orange : .primary)

            Text(viewModel.statusText)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }

    private var progressSection: some View {
        Group {
            if !viewModel.state.isIdle {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            viewModel.state.isBreakTime ? Color.orange : Color.accentColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: viewModel.progress)

                    Text(viewModel.formattedTime)
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.medium)
                }
                .frame(width: 100, height: 100)
            }
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 12) {
            switch viewModel.state {
            case .idle:
                Button("Start") { viewModel.start() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Start timer")

            case .working, .breakTime:
                Button("Pause") { viewModel.pause() }
                    .accessibilityLabel("Pause timer")

                Button("Reset") { viewModel.reset() }
                    .accessibilityLabel("Reset timer")

                if viewModel.state.isBreakTime {
                    Button("Skip") { viewModel.skip() }
                        .accessibilityLabel("Skip break")
                }

            case .paused:
                Button("Resume") { viewModel.resume() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Resume timer")

                Button("Reset") { viewModel.reset() }
                    .accessibilityLabel("Reset timer")
            }
        }
    }

    private var bottomSection: some View {
        VStack(spacing: 8) {
            if showSettings {
                SettingsView(
                    workMinutes: $workMinutes,
                    breakSeconds: $breakSeconds,
                    soundEnabled: $soundEnabled,
                    showTimerInMenuBar: $showTimerInMenuBar
                )
            }

            HStack {
                Button {
                    withAnimation { showSettings.toggle() }
                } label: {
                    Label(
                        showSettings ? "Hide Settings" : "Settings",
                        systemImage: "gear"
                    )
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showSettings ? "Hide settings" : "Show settings")

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Quit SightSaver")
            }
        }
    }

    private func syncSettings() {
        viewModel.workInterval = workMinutes * 60
        viewModel.breakDuration = breakSeconds
        viewModel.soundEnabled = soundEnabled
    }
}
