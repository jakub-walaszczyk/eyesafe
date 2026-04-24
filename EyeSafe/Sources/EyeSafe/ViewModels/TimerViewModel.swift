import Foundation
import Combine
import AppKit

final class TimerViewModel: ObservableObject {
    @Published var state: TimerState = .idle

    var workInterval: TimeInterval = 20 * 60
    var breakDuration: TimeInterval = 20
    var soundEnabled: Bool = true

    private var timer: AnyCancellable?
    private var sleepWakeObservers: [NSObjectProtocol] = []
    private var sleepDate: Date?

    var formattedTime: String {
        let total = Int(state.remaining)
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "\(seconds)s"
    }

    var statusText: String {
        switch state {
        case .idle:
            return "Ready"
        case .working:
            return "Working — \(formattedTime) left"
        case .breakTime:
            return "Look away — \(formattedTime) left"
        case .paused(let prev):
            switch prev {
            case .working: return "Paused (working)"
            case .breakTime: return "Paused (break)"
            }
        }
    }

    var menuBarTitle: String {
        switch state {
        case .idle:
            return ""
        case .working, .breakTime:
            return formattedTime
        case .paused:
            return "⏸"
        }
    }

    var progress: Double {
        switch state {
        case .idle:
            return 0
        case .working(let remaining):
            return 1.0 - remaining / workInterval
        case .breakTime(let remaining):
            return 1.0 - remaining / breakDuration
        case .paused(let prev):
            switch prev {
            case .working(let remaining):
                return 1.0 - remaining / workInterval
            case .breakTime(let remaining):
                return 1.0 - remaining / breakDuration
            }
        }
    }

    var menuBarIcon: String {
        if state.isBreakTime {
            return "eye.trianglebadge.exclamationmark"
        }
        return "eye"
    }

    init() {
        observeSleepWake()
    }

    deinit {
        sleepWakeObservers.forEach {
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
    }

    func start() {
        state = .working(remaining: workInterval)
        startTimer()
        NotificationManager.shared.requestPermission()
    }

    func pause() {
        switch state {
        case .working(let remaining):
            state = .paused(previous: .working(remaining: remaining))
        case .breakTime(let remaining):
            state = .paused(previous: .breakTime(remaining: remaining))
        default:
            break
        }
        stopTimer()
    }

    func resume() {
        guard case .paused(let prev) = state else { return }
        switch prev {
        case .working(let remaining):
            state = .working(remaining: remaining)
        case .breakTime(let remaining):
            state = .breakTime(remaining: remaining)
        }
        startTimer()
    }

    func reset() {
        state = .idle
        stopTimer()
    }

    func skip() {
        guard state.isBreakTime else { return }
        state = .working(remaining: workInterval)
        NotificationManager.shared.sendBreakOverNotification(soundEnabled: soundEnabled)
    }

    private func tick() {
        switch state {
        case .working(let remaining):
            let next = remaining - 1
            if next <= 0 {
                state = .breakTime(remaining: breakDuration)
                NotificationManager.shared.sendBreakNotification(soundEnabled: soundEnabled, breakDuration: breakDuration)
            } else {
                state = .working(remaining: next)
            }

        case .breakTime(let remaining):
            let next = remaining - 1
            if next <= 0 {
                state = .working(remaining: workInterval)
                NotificationManager.shared.sendBreakOverNotification(soundEnabled: soundEnabled)
            } else {
                state = .breakTime(remaining: next)
            }

        default:
            break
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func observeSleepWake() {
        let sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sleepDate = Date()
            self?.stopTimer()
        }

        let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let sleepDate = self.sleepDate else { return }
            let elapsed = Date().timeIntervalSince(sleepDate)
            self.sleepDate = nil
            self.adjustAfterSleep(elapsed: elapsed)
        }

        sleepWakeObservers = [sleepObserver, wakeObserver]
    }

    private func adjustAfterSleep(elapsed: TimeInterval) {
        switch state {
        case .working(let remaining):
            let adjusted = remaining - elapsed
            if adjusted <= 0 {
                state = .breakTime(remaining: breakDuration)
                NotificationManager.shared.sendBreakNotification(soundEnabled: soundEnabled, breakDuration: breakDuration)
            } else {
                state = .working(remaining: adjusted)
            }
            startTimer()

        case .breakTime(let remaining):
            let adjusted = remaining - elapsed
            if adjusted <= 0 {
                state = .working(remaining: workInterval)
                NotificationManager.shared.sendBreakOverNotification(soundEnabled: soundEnabled)
            } else {
                state = .breakTime(remaining: adjusted)
            }
            startTimer()

        case .paused:
            break

        case .idle:
            break
        }
    }
}
