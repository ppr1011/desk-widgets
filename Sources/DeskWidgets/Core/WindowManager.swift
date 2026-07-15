import AppKit
import SwiftUI
import Combine

/// 桥接 store 数据 与 屏幕上的 NSPanel 窗口。
/// 所有组件统一使用 WidgetPanel,避免 NSWindow 导致 Dock 出现图标。
final class WindowManager {
    private let store: WidgetStore
    private var panels: [UUID: WidgetPanel] = [:]
    private var cancellable: AnyCancellable?

    init(store: WidgetStore) {
        self.store = store
        cancellable = store.$instances
            .receive(on: RunLoop.main)
            .sink { [weak self] instances in self?.sync(instances) }
    }

    private func sync(_ instances: [WidgetInstance]) {
        let currentIDs = Set(instances.map { $0.id })

        for (id, panel) in panels where !currentIDs.contains(id) {
            panel.close()
            panels.removeValue(forKey: id)
        }

        for instance in instances {
            if let panel = panels[instance.id] {
                panel.applyLevel(instance.level)
                if panel.frame != instance.frame {
                    panel.setFrame(instance.frame, display: true)
                }
            } else {
                createPanel(for: instance)
            }
        }
    }

    private func createPanel(for instance: WidgetInstance) {
        guard let provider = WidgetRegistry.shared.provider(for: instance.kind) else { return }
        let root = AnyView(
            provider.makeView(instance: instance, store: store)
        )
        let hosting = WidgetHostingView(rootView: root)
        hosting.frame = CGRect(origin: .zero, size: instance.frame.size)
        hosting.allowsBackgroundDrag = !instance.kind.acceptsKeyboardInput
        hosting.instanceID = instance.id
        hosting.widgetStore = store

        let clamped = ScreenPlacement.normalizeFrame(
            instance.frame,
            screenKey: instance.screenKey,
            index: panels.count
        )
        var normalized = instance
        if normalized.frame != clamped.frame || normalized.screenKey != clamped.screenKey {
            normalized.frame = clamped.frame
            normalized.screenKey = clamped.screenKey
            store.update(normalized)
        }

        let panel = WidgetPanel(
            instance: normalized,
            contentView: hosting,
            acceptsKeyboardInput: instance.kind.acceptsKeyboardInput
        )
        panel.onFrameChanged = { [weak self] frame in
            self?.store.updateFrame(id: instance.id, frame: frame)
        }
        panels[instance.id] = panel
        panel.orderFrontRegardless()
        AccessoryModeEnforcer.apply()

        if normalized.frame != instance.frame || normalized.screenKey != instance.screenKey {
            store.update(normalized)
        }
    }
}
