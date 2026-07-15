import Foundation

/// 定时/事件调度引擎。每 30 秒一跳:
/// - 检测是否跨过了某个定时点(对休眠鲁棒,唤醒后按时间区间补判)。
/// - 触发一次评估回调,供协调器检查事件触发(久坐/高负荷)。
final class ReminderScheduler {
    var onScheduledFire: (() -> Void)?
    var onEvaluate: (() -> Void)?

    private var timer: Timer?
    private var lastCheck = Date()
    private let interval: TimeInterval = 30

    func start() {
        guard timer == nil else { return }
        lastCheck = Date()
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Date()
        if crossedScheduledTime(from: lastCheck, to: now) {
            onScheduledFire?()
        }
        lastCheck = now
        onEvaluate?()
    }

    /// 判断 (from, to] 区间内是否跨过任一定时点。
    private func crossedScheduledTime(from: Date, to: Date) -> Bool {
        guard to > from else { return false }
        let times = AISettingsStore.shared.settings.scheduleTimes
        let calendar = Calendar.current
        // 覆盖 from 与 to 所在日期(通常同一天;唤醒后可能跨天)
        let days = [from, to]
        for day in days {
            for hhmm in times {
                guard let target = date(for: hhmm, on: day, calendar: calendar) else { continue }
                if target > from && target <= to {
                    return true
                }
            }
        }
        return false
    }

    private func date(for hhmm: String, on day: Date, calendar: Calendar) -> Date? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return calendar.date(bySettingHour: h, minute: m, second: 0, of: day)
    }
}
