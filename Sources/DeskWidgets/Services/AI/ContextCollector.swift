import Foundation

/// 从各组件与系统服务汇总工作上下文。只读,不侵入其它组件。
enum ContextCollector {
    private struct RawTodo: Decodable {
        let text: String
        let isDone: Bool
    }

    static func collect(store: WidgetStore, scene: TriggerScene, settings: AISettings) -> AIContext {
        var context = AIContext(scene: scene, now: Date())

        if settings.useActivity {
            let tracker = ActivityTracker.shared
            context.screenUsageMinutes = Int(tracker.todayActiveSeconds / 60)
            context.continuousActiveMinutes = Int(tracker.continuousActiveSeconds / 60)
            context.idleMinutes = Int(tracker.idleSeconds / 60)
        }

        if settings.useSystemMetrics {
            let sampler = SystemMetricsSampler.shared
            context.cpuPercent = sampler.cpuUsage
            if sampler.memoryTotal > 0 {
                context.memoryPercent = Double(sampler.memoryUsed) / Double(sampler.memoryTotal) * 100
            }
            context.networkBusy = networkBusyLabel(
                down: sampler.downloadSpeed,
                up: sampler.uploadSpeed
            )
        }

        if settings.useTodos {
            let todos = collectTodos(store: store)
            if !todos.isEmpty || hasTodoWidget(store) {
                context.todoTotal = todos.count
                let pending = todos.filter { !$0.isDone }
                context.todoPending = pending.count
                context.pendingTodos = pending.map { $0.text }.filter { !$0.isEmpty }
            }
        }

        if settings.useNotes {
            context.noteSummaries = collectNotes(store: store)
        }

        return context
    }

    private static func hasTodoWidget(_ store: WidgetStore) -> Bool {
        store.instances.contains { $0.kind == .todo }
    }

    private static func collectTodos(store: WidgetStore) -> [RawTodo] {
        var result: [RawTodo] = []
        let decoder = JSONCoders.makeDecoder()
        for instance in store.instances where instance.kind == .todo {
            guard let raw = instance.config["items"],
                  let data = raw.data(using: .utf8),
                  let items = try? decoder.decode([RawTodo].self, from: data) else { continue }
            result.append(contentsOf: items)
        }
        return result
    }

    private static func collectNotes(store: WidgetStore) -> [String] {
        var result: [String] = []
        for instance in store.instances where instance.kind == .note {
            let content = (instance.config["content"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            let flat = content.replacingOccurrences(of: "\n", with: " ")
            result.append(String(flat.prefix(40)))
        }
        return result
    }

    private static func networkBusyLabel(down: Double, up: Double) -> String {
        let total = down + up
        let mb = total / (1024 * 1024)
        switch mb {
        case ..<0.1: return "空闲"
        case 0.1..<1: return "一般"
        default: return "繁忙"
        }
    }
}
