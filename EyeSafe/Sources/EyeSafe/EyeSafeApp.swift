import SwiftUI

@main
struct EyeSafeApp: App {
    @StateObject private var viewModel = TimerViewModel()
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar = false

    init() {
        NotificationManager.shared.requestPermission()
        NotificationManager.shared.checkPermissionStatus()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.menuBarIcon)
                if showTimerInMenuBar && !viewModel.state.isIdle {
                    Text(viewModel.menuBarTitle)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
