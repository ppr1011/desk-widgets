import AppKit
import SwiftUI
import Combine

/// 桥接 store 数据 与 屏幕上的 NSPanel:
/// 订阅 store.instances 变化,做增/删 diff 并同步窗口层级。
/// 拖动时 panel 回写 frame 到 store —— 单向,避免与 sync 互相触发抖动。
final class WindowManager {
    private let store: WidgetStore
    private var panels: [UUID: WidgetPanel] = [:]
    private var cancellable: AnyCancellable?

    init(store: WidgetStore) {
        self.store = store
        // 订阅会立即收到当前值 —— 因此启动时自动恢复已保存的组件
        cancellable = store.$instances
            .receive(on: RunLoop.main)
            .sink { [weak self] instances in self?.sync(instances) }
    }

    private func sync(_ instances: [WidgetInstance]) {
        let currentIDs = Set(instances.map { $0.id })

        // 1) 关闭已被删除的组件窗口
        for (id, panel) in panels where !currentIDs.contains(id) {
            panel.close()
            panels.removeValue(forKey: id)
        }

        for instance in instances {
            if let panel = panels[instance.id] {
                // 2) 已存在:只同步层级,不动 frame(frame 由拖动单向回写)
                panel.applyLevel(instance.level)
            } else {
                // 3) 新增:创建窗口
                createPanel(for: instance)
            }
        }
    }

    private func createPanel(for instance: WidgetInstance) {
        guard let provider = WidgetRegistry.shared.provider(for: instance.kind) else { return }
        let root = provider.makeView(instance: instance, store: store)
            .environmentObject(store)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = CGRect(origin: .zero, size: instance.frame.size)

        let panel = WidgetPanel(instance: instance, contentView: hosting)
        panel.onFrameChanged = { [weak self] frame in
            self?.store.updateFrame(id: instance.id, frame: frame)
        }
        panel.orderFront(nil)
        panels[instance.id] = panel
    }
}
