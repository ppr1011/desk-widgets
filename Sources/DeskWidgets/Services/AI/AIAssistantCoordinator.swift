import Foundation
import Combine
import AppKit

/// AI 助手总协调器 (单例)。
/// 串起:调度器 → 上下文采集 → 模型调用 → 气泡呈现,并管理静默时段/频次/冷却。
@MainActor
final class AIAssistantCoordinator {
    static let shared = AIAssistantCoordinator()

    /// 展开对话面板的通知(由气泡「展开对话」按钮发出,AI 组件视图监听)。
    static let openChatNotification = Notification.Name("AIAgentOpenChat")

    private var store: WidgetStore?
    private let scheduler = ReminderScheduler()
    private var cancellable: AnyCancellable?

    private var isGenerating = false
    private var lastFire = Date.distantPast
    private var lastSittingFire = Date.distantPast
    private var lastLoadFire = Date.distantPast

    private var todayCount = 0
    private var countDayKey = ""

    private var metricsSubscribed = false

    private init() {}

    func configure(store: WidgetStore) {
        guard self.store == nil else { return }
        self.store = store

        ActivityTracker.shared.start()
        updateMetricsSubscription(for: store.instances)

        cancellable = store.$instances
            .receive(on: RunLoop.main)
            .sink { [weak self] instances in
                self?.updateMetricsSubscription(for: instances)
            }

        scheduler.onScheduledFire = { [weak self] in self?.trigger(scene: .scheduled) }
        scheduler.onEvaluate = { [weak self] in self?.evaluateEvents() }
        scheduler.start()
    }

    /// 用户手动「关心我一下」。绕过静默/频次限制。
    func triggerManual(for instanceID: UUID) {
        trigger(scene: .manual, instanceID: instanceID, bypassLimits: true)
    }

    // MARK: - 事件触发评估

    private func evaluateEvents() {
        let settings = AISettingsStore.shared.settings
        guard settings.eventTriggersEnabled, hasAgent else { return }
        guard !inQuietHours(settings) else { return }

        let now = Date()
        let sittingMinutes = ActivityTracker.shared.continuousActiveSeconds / 60
        if sittingMinutes >= Double(settings.sittingMinutesThreshold),
           now.timeIntervalSince(lastSittingFire) > 60 * 60 {
            lastSittingFire = now
            trigger(scene: .longSitting)
            return
        }

        let cpu = SystemMetricsSampler.shared.cpuUsage
        if cpu >= 90, now.timeIntervalSince(lastLoadFire) > 2 * 60 * 60 {
            lastLoadFire = now
            trigger(scene: .highLoad)
        }
    }

    // MARK: - 核心触发

    private func trigger(scene: TriggerScene, instanceID: UUID? = nil, bypassLimits: Bool = false) {
        guard let store else { return }
        guard !isGenerating else { return }

        let agents = store.instances.filter { $0.kind == .aiAgent }
        let target = instanceID.flatMap { id in agents.first { $0.id == id } } ?? agents.first
        guard let target else { return }

        let settings = AISettingsStore.shared.settings
        if !bypassLimits {
            if inQuietHours(settings) { return }
            resetDailyCountIfNeeded()
            if todayCount >= settings.dailyLimit { return }
            if Date().timeIntervalSince(lastFire) < 60 { return }
        }

        isGenerating = true
        let context = ContextCollector.collect(store: store, scene: scene, settings: settings)
        let targetID = target.id

        Task { @MainActor in
            let message = await AIService.shared.generateReminder(context: context, settings: settings)
            self.isGenerating = false
            self.lastFire = Date()
            self.resetDailyCountIfNeeded()
            self.todayCount += 1
            self.presentBubble(message: message, scene: scene, targetID: targetID)
        }
    }

    private func presentBubble(message: String, scene: TriggerScene, targetID: UUID) {
        BubblePresenter.shared.show(
            message: message,
            scene: scene,
            near: targetID,
            onOpenChat: {
                NotificationCenter.default.post(
                    name: Self.openChatNotification,
                    object: targetID
                )
            },
            onRemindLater: { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 10 * 60) {
                    self?.trigger(scene: scene, instanceID: targetID, bypassLimits: true)
                }
            }
        )
    }

    // MARK: - 限制与状态

    private var hasAgent: Bool {
        store?.instances.contains { $0.kind == .aiAgent } ?? false
    }

    private func inQuietHours(_ settings: AISettings) -> Bool {
        guard let start = minutesOfDay(settings.quietStart),
              let end = minutesOfDay(settings.quietEnd) else { return false }
        let nowMinutes = Calendar.current.component(.hour, from: Date()) * 60
            + Calendar.current.component(.minute, from: Date())
        if start == end { return false }
        if start < end {
            return nowMinutes >= start && nowMinutes < end
        }
        // 跨午夜,如 22:00 - 08:00
        return nowMinutes >= start || nowMinutes < end
    }

    private func minutesOfDay(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    private func resetDailyCountIfNeeded() {
        let key = dayKey(Date())
        if key != countDayKey {
            countDayKey = key
            todayCount = 0
        }
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// 有 AI 组件时才让系统指标采样器常驻运行,供上下文使用。
    private func updateMetricsSubscription(for instances: [WidgetInstance]) {
        let needs = instances.contains { $0.kind == .aiAgent }
        if needs && !metricsSubscribed {
            SystemMetricsSampler.shared.addSubscriber()
            metricsSubscribed = true
        } else if !needs && metricsSubscribed {
            SystemMetricsSampler.shared.removeSubscriber()
            metricsSubscribed = false
        }
    }
}
