import AppKit
import SwiftUI

/// 承载 SwiftUI 组件的 NSHostingView。
/// - acceptsFirstMouse:首次点击即响应,无需先激活窗口再点第二次
/// - 交互型组件关闭背景拖动,避免吞掉 TextField / Button 点击
/// - 右键菜单(AppKit target-action):关闭当前组件
final class WidgetHostingView: NSHostingView<AnyView> {
    var allowsBackgroundDrag = true
    var instanceID: UUID?
    weak var widgetStore: WidgetStore?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.orderFrontRegardless()
        if !allowsBackgroundDrag {
            InputActivationManager.shared.activateForInput()
            window?.makeKeyAndOrderFront(nil)
            AccessoryModeEnforcer.apply()
        } else {
            window?.performDrag(with: event)
        }
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.orderFrontRegardless()
        // 激活 App,避免后台 accessory 状态下菜单项被判为不可用而置灰
        InputActivationManager.shared.activateForInput()
        if let menu = menu(for: event) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }
        super.rightMouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let instanceID, let store = widgetStore else { return nil }
        let instance = store.instance(id: instanceID)
        let name = instance.flatMap { inst in
            WidgetRegistry.shared.provider(for: inst.kind)?.displayName
        } ?? "组件"

        let menu = NSMenu()
        // 后台(accessory)状态下自动校验会把菜单项判为不可用而置灰,这里关闭自动校验,手动保证可点。
        menu.autoenablesItems = false

        let allSpacesItem = NSMenuItem(
            title: "在所有桌面显示",
            action: #selector(toggleAllSpaces(_:)),
            keyEquivalent: ""
        )
        allSpacesItem.target = self
        allSpacesItem.isEnabled = true
        allSpacesItem.state = (instance?.showOnAllSpaces == true) ? .on : .off
        menu.addItem(allSpacesItem)

        if instance?.showOnAllSpaces != true {
            let moveItem = NSMenuItem(
                title: "移到当前桌面",
                action: #selector(moveToActiveSpace(_:)),
                keyEquivalent: ""
            )
            moveItem.target = self
            moveItem.isEnabled = true
            menu.addItem(moveItem)
        }

        menu.addItem(.separator())

        let closeItem = NSMenuItem(
            title: "关闭\(name)",
            action: #selector(closeWidget(_:)),
            keyEquivalent: ""
        )
        closeItem.target = self
        closeItem.isEnabled = true
        menu.addItem(closeItem)
        return menu
    }

    @objc private func closeWidget(_ sender: NSMenuItem) {
        guard let instanceID else { return }
        widgetStore?.remove(id: instanceID)
    }

    @objc private func moveToActiveSpace(_ sender: NSMenuItem) {
        guard let instanceID else { return }
        NotificationCenter.default.post(
            name: WindowManager.moveToActiveSpaceNotification,
            object: instanceID
        )
    }

    @objc private func toggleAllSpaces(_ sender: NSMenuItem) {
        guard let instanceID, var instance = widgetStore?.instance(id: instanceID) else { return }
        instance.showOnAllSpaces.toggle()
        widgetStore?.update(instance)
    }
}

/// 顶部拖动手柄 —— 交互型组件通过此区域移动窗口。
struct WindowDragHandle: View {
    let instanceID: UUID
    let store: WidgetStore
    var title: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "line.3.horizontal")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                store.remove(id: instanceID)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(WindowDragHandleRepresentable())
    }
}

private struct WindowDragHandleRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView {
        DragHandleView()
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {}
}

private final class DragHandleView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.orderFrontRegardless()
        window?.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.orderFrontRegardless()
        InputActivationManager.shared.activateForInput()
        if let hosting = findHostingAncestor(), let menu = hosting.menu(for: event) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }
        super.rightMouseDown(with: event)
    }

    private func findHostingAncestor() -> WidgetHostingView? {
        var view: NSView? = superview
        while let current = view {
            if let hosting = current as? WidgetHostingView { return hosting }
            view = current.superview
        }
        return nil
    }
}
