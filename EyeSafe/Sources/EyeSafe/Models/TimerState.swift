import Foundation

enum TimerState: Equatable {
    case idle
    case working(remaining: TimeInterval)
    case breakTime(remaining: TimeInterval)
    case paused(previous: PausedState)

    enum PausedState: Equatable {
        case working(remaining: TimeInterval)
        case breakTime(remaining: TimeInterval)
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    var isWorking: Bool {
        if case .working = self { return true }
        return false
    }

    var isBreakTime: Bool {
        if case .breakTime = self { return true }
        return false
    }

    var remaining: TimeInterval {
        switch self {
        case .idle: return 0
        case .working(let r): return r
        case .breakTime(let r): return r
        case .paused(let prev):
            switch prev {
            case .working(let r): return r
            case .breakTime(let r): return r
            }
        }
    }
}
