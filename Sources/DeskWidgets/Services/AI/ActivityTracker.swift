import Foundation
import CoreGraphics

/// 活动追踪器 (单例)。基于系统空闲时间估算「屏幕使用时长 / 连续工作时长 / 发呆时长」。
/// - 空闲判定:距上次键鼠事件的秒数。
/// - 屏幕使用:每个采样周期若非空闲则累加,跨天清零,持久化到 ai-activity.json。
final class ActivityTracker: ObservableObject {
    static let shared = ActivityTracker()

    /// 今日累计活跃秒数
    @Published private(set) var todayActiveSeconds: TimeInterval = 0
    /// 当前连续活跃秒数(一旦长时间空闲即清零)
    @Published private(set) var continuousActiveSeconds: TimeInterval = 0
    /// 当前空闲秒数(距上次输入)
    @Published private(set) var idleSeconds: TimeInterval = 0

    private var timer: Timer?
    private var lastTick: Date?
    private var currentDay: String = ""

    private let tickInterval: TimeInterval = 30
    /// 空闲低于此值视为「在使用」
    private let activeIdleThreshold: TimeInterval = 90

    private let fileURL: URL
    private var dailyActive: [String: Double] = [:]

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeskWidgets", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("ai-activity.json")

        currentDay = Self.dayKey(Date())
        load()
        todayActiveSeconds = dailyActive[currentDay] ?? 0
    }

    func start() {
        guard timer == nil else { return }
        lastTick = Date()
        tick()
        let t = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Date()
        let idle = Self.systemIdleSeconds()
        idleSeconds = idle

        let day = Self.dayKey(now)
        if day != currentDay {
            currentDay = day
            todayActiveSeconds = dailyActive[day] ?? 0
            continuousActiveSeconds = 0
        }

        if let last = lastTick {
            let delta = now.timeIntervalSince(last)
            let plausible = delta > 0 && delta < tickInterval * 4
            if plausible && idle < activeIdleThreshold {
                todayActiveSeconds += delta
                continuousActiveSeconds += delta
            } else {
                continuousActiveSeconds = 0
            }
        }
        lastTick = now

        dailyActive[currentDay] = todayActiveSeconds
        save()
    }

    /// 系统空闲秒数:取各类输入事件「距今最短」的那个。
    static func systemIdleSeconds() -> TimeInterval {
        let types: [CGEventType] = [
            .mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown,
            .scrollWheel, .otherMouseDown, .leftMouseDragged,
            .rightMouseDragged, .flagsChanged
        ]
        let values = types.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }
        return values.min() ?? 0
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data) else { return }
        dailyActive = decoded
    }

    private func save() {
        // 只保留最近 14 天,避免文件无限增长
        if dailyActive.count > 14 {
            let keep = dailyActive.keys.sorted().suffix(14)
            dailyActive = dailyActive.filter { keep.contains($0.key) }
        }
        guard let data = try? JSONEncoder().encode(dailyActive) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
