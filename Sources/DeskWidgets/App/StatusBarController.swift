import AppKit
import SwiftUI

/// 菜单栏图标 + 下拉菜单(≈ 系统托盘)。
/// 继承 NSObject 以支持 target/action 选择器机制。
final class StatusBarController: NSObject, NSMenuItemValidation {
    private let store: WidgetStore
    private let statusItem: NSStatusItem
    private var managerPanel: NSPanel?

    init(store: WidgetStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = Self.makeMascotIcon()
        }
        statusItem.isVisible = true
        buildMenu()
    }

    /// 自绘萌系「小助手」表情脸图标(模板图,自动适配菜单栏明暗)。
    private static func makeMascotIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setStroke()
        NSColor.black.setFill()

        // 脸(圆角方块)
        let face = NSBezierPath(
            roundedRect: NSRect(x: 2, y: 2.5, width: 14, height: 13),
            xRadius: 4.5, yRadius: 4.5
        )
        face.lineWidth = 1.5
        face.stroke()

        // 眼睛
        for eyeX in [6.3, 11.7] {
            let eye = NSBezierPath(ovalIn: NSRect(x: eyeX - 1, y: 9.5, width: 2, height: 2))
            eye.fill()
        }

        // 微笑
        let smile = NSBezierPath()
        smile.appendArc(withCenter: NSPoint(x: 9, y: 8.2), radius: 3, startAngle: 205, endAngle: 335)
        smile.lineWidth = 1.4
        smile.lineCapStyle = .round
        smile.stroke()

        // 头顶小天线 + 闪光点(增加趣味/AI 感)
        let antenna = NSBezierPath()
        antenna.move(to: NSPoint(x: 9, y: 15.5))
        antenna.line(to: NSPoint(x: 9, y: 17.2))
        antenna.lineWidth = 1.3
        antenna.lineCapStyle = .round
        antenna.stroke()
        NSBezierPath(ovalIn: NSRect(x: 8, y: 16.6, width: 2, height: 2)).fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
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
        // 单例组件已存在时,聚焦已有实例而非新建
        if !kind.allowsMultiple, let existing = store.instances.first(where: { $0.kind == kind }) {
            focusExisting(existing)
            return
        }
        let size = provider.defaultSize
        let placement = ScreenPlacement.centeredOnActiveScreen(
            size: size,
            index: store.instances.count
        )
        // 新组件默认悬浮,保证添加后立即可见(贴桌面层会被普通窗口盖住)
        let instance = WidgetInstance(
            kind: kind,
            frame: placement.frame,
            level: .floating,
            screenKey: placement.screenKey
        )
        store.add(instance)
    }

    /// 单例组件已存在时,把已有实例移回当前屏可见处并置顶,替代新建。
    private func focusExisting(_ instance: WidgetInstance) {
        let index = store.instances.firstIndex(where: { $0.id == instance.id }) ?? 0
        let placement = ScreenPlacement.centeredOnActiveScreen(size: instance.frame.size, index: index)
        var updated = instance
        updated.frame = placement.frame
        updated.screenKey = placement.screenKey
        updated.level = .floating
        store.update(updated)
    }

    /// 菜单打开时自动校验:单例组件已存在则置灰对应「添加」项。
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(addWidget(_:)),
              let raw = menuItem.representedObject as? String,
              let kind = WidgetKind(rawValue: raw) else {
            return true
        }
        if !kind.allowsMultiple {
            return !store.instances.contains { $0.kind == kind }
        }
        return true
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
