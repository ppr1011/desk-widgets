import AppKit
import SwiftUI

/// 菜单栏图标 + 下拉菜单(≈ 系统托盘)。
/// 继承 NSObject 以支持 target/action 选择器机制。
final class StatusBarController: NSObject {
    private let store: WidgetStore
    private let statusItem: NSStatusItem
    private var managerPanel: NSPanel?

    init(store: WidgetStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "square.grid.2x2",
                                accessibilityDescription: "DeskWidgets")
            image?.isTemplate = true
            button.image = image
        }
        statusItem.isVisible = true
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        // 「添加组件」子菜单:遍历注册表中所有组件
        let addItem = NSMenuItem(title: "添加组件", action: nil, keyEquivalent: "")
        let addSub = NSMenu()
        for provider in WidgetRegistry.shared.allProviders {
            let mi = NSMenuItem(title: provider.displayName,
                                action: #selector(addWidget(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = provider.kind.rawValue
            addSub.addItem(mi)
        }
        addItem.submenu = addSub
        menu.addItem(addItem)

        let manage = NSMenuItem(title: "管理组件…", action: #selector(openManager), keyEquivalent: "")
        manage.target = self
        menu.addItem(manage)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 DeskWidgets", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func addWidget(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let kind = WidgetKind(rawValue: raw),
              let provider = WidgetRegistry.shared.provider(for: kind) else { return }
        let size = provider.defaultSize
        let placement = ScreenPlacement.centeredOnActiveScreen(
            size: size,
            index: store.instances.count
        )
        let instance = WidgetInstance(
            kind: kind,
            frame: placement.frame,
            screenKey: placement.screenKey
        )
        store.add(instance)
    }

    @objc private func openManager() {
        if managerPanel == nil {
            let hosting = NSHostingController(rootView: ManagerView().environmentObject(store))
            // 不加 .nonactivatingPanel:管理面板需要成为 key 窗口,否则 SwiftUI 按钮点击不触发
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.title = "管理组件"
            panel.isReleasedWhenClosed = false
            panel.isExcludedFromWindowsMenu = true
            panel.hidesOnDeactivate = false
            panel.contentViewController = hosting
            managerPanel = panel
        }
        managerPanel?.center()
        // 激活 App 使面板成为 key(激活不改变 .accessory 策略,不会出现 Dock 图标)
        NSApp.activate(ignoringOtherApps: true)
        managerPanel?.makeKeyAndOrderFront(nil)
        AccessoryModeEnforcer.apply()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
