import AppKit
import SwiftUI

/// 菜单栏图标 + 下拉菜单(≈ 系统托盘)。
/// 继承 NSObject 以支持 target/action 选择器机制。
final class StatusBarController: NSObject {
    private let store: WidgetStore
    private let statusItem: NSStatusItem
    private var managerWindow: NSWindow?

    init(store: WidgetStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2",
                                   accessibilityDescription: "DeskWidgets")
        }
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
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        // 放在屏幕中心
        let origin = CGPoint(x: screen.midX - size.width / 2,
                             y: screen.midY - size.height / 2)
        let instance = WidgetInstance(kind: kind,
                                      frame: CGRect(origin: origin, size: size))
        store.add(instance)
    }

    @objc private func openManager() {
        if managerWindow == nil {
            let hosting = NSHostingController(rootView: ManagerView().environmentObject(store))
            let window = NSWindow(contentViewController: hosting)
            window.title = "管理组件"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            managerWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        managerWindow?.center()
        managerWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
