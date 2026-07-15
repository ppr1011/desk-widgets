import AppKit
import SwiftUI

/// 承载气泡的无边框浮动面板。非激活,不抢焦点。
final class BubblePanel: NSPanel {
    /// interactive=true 时允许成为 key 窗口(用于气泡内直接对话输入)。
    init(contentView: NSView, size: NSSize, interactive: Bool = false) {
        var style: NSWindow.StyleMask = [.borderless]
        if !interactive { style.insert(.nonactivatingPanel) }
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isExcludedFromWindowsMenu = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.contentView = contentView
        contentView.autoresizingMask = [.width, .height]
    }

    override var canBecomeKey: Bool { true }
}

/// 允许首次点击即响应,让气泡按钮无需先激活面板也能点击。
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// 气泡呈现器 (单例)。定位到 AI 组件附近弹出,自动消失,同一时刻仅一个。
@MainActor
final class BubblePresenter {
    static let shared = BubblePresenter()

    private var panel: BubblePanel?
    private var dismissTimer: Timer?

    private init() {}

    func show(
        message: String,
        scene: TriggerScene,
        near instanceID: UUID,
        onOpenChat: @escaping () -> Void,
        onRemindLater: @escaping () -> Void
    ) {
        dismiss()

        // 提示气泡尺寸(尾巴方向不影响尺寸)。
        let probe = FirstMouseHostingView(rootView: BubbleView(
            message: message, scene: scene, pointsDown: false,
            onKnown: {}, onRemindLater: {}, onOpenChat: {}
        ))
        var size = probe.fittingSize
        if size.width < 40 { size.width = 300 }
        if size.height < 40 { size.height = 120 }

        let anchor = AISettingsStore.shared.settings.bubbleAnchor
        if anchor == .menuBar {
            showMenuBar(message: message, scene: scene, size: size, onRemindLater: onRemindLater)
            return
        }

        guard let widgetFrame = anchorFrame(for: instanceID) else {
            showMenuBar(message: message, scene: scene, size: size, onRemindLater: onRemindLater)
            return
        }
        let layout = nearWidgetLayout(size: size, widgetFrame: widgetFrame)
        let view = AnyView(BubbleView(
            message: message, scene: scene, pointsDown: layout.pointsDown,
            onKnown: { [weak self] in self?.dismiss() },
            onRemindLater: { [weak self] in self?.dismiss(); onRemindLater() },
            onOpenChat: { [weak self] in self?.dismiss(); onOpenChat() }
        ))
        presentPanel(view: view, frame: layout.frame, size: size, interactive: false)
    }

    /// 顶部菜单栏模式:提示气泡可就地展开为对话框。
    private func showMenuBar(
        message: String,
        scene: TriggerScene,
        size: NSSize,
        onRemindLater: @escaping () -> Void
    ) {
        let host = TopBubbleHost(
            message: message,
            scene: scene,
            reminderSize: size,
            onKnown: { [weak self] in self?.dismiss() },
            onRemindLater: { [weak self] in self?.dismiss(); onRemindLater() },
            onEnterChat: { [weak self] in self?.enterChatMode() },
            onResize: { [weak self] height in self?.resizeMenuBar(height: height) }
        )
        let layout = menuBarLayout(size: size)
        presentPanel(view: AnyView(host), frame: layout.frame, size: size, interactive: true)
    }

    private func presentPanel(view: AnyView, frame: NSRect, size: NSSize, interactive: Bool) {
        let hosting = FirstMouseHostingView(rootView: view)
        let newPanel = BubblePanel(contentView: hosting, size: size, interactive: interactive)
        newPanel.setFrame(frame, display: true)
        newPanel.alphaValue = 0
        newPanel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            newPanel.animator().alphaValue = 1
        }
        panel = newPanel
        scheduleAutoDismiss()
    }

    private func scheduleAutoDismiss() {
        dismissTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
        RunLoop.main.add(timer, forMode: .common)
        dismissTimer = timer
    }

    /// 进入对话:停止自动消失,并让气泡面板获得键盘焦点。
    private func enterChatMode() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        InputActivationManager.shared.activateForInput()
        panel?.makeKeyAndOrderFront(nil)
    }

    /// 对话展开/收起时按新高度重新定位到菜单栏下方(顶部对齐)。
    private func resizeMenuBar(height: CGFloat) {
        guard let panel else { return }
        var size = panel.frame.size
        size.height = height
        let layout = menuBarLayout(size: size)
        panel.setFrame(layout.frame, display: true, animate: true)
    }

    /// 组件旁:优先在组件上方(尾巴朝下),上方放不下则翻到下方(尾巴朝上)。
    private func nearWidgetLayout(size: NSSize, widgetFrame: NSRect) -> (frame: NSRect, pointsDown: Bool) {
        let screen = NSScreen.screens.first { $0.frame.intersects(widgetFrame) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? widgetFrame
        let margin: CGFloat = 6
        var pointsDown = true
        var originY = widgetFrame.maxY + margin
        if originY + size.height > visible.maxY {
            pointsDown = false
            originY = widgetFrame.minY - margin - size.height
        }
        var originX = widgetFrame.midX - size.width / 2
        originX = min(max(originX, visible.minX + 4), visible.maxX - size.width - 4)
        originY = min(max(originY, visible.minY + 4), visible.maxY - size.height - 4)
        return (NSRect(x: originX, y: originY, width: size.width, height: size.height), pointsDown)
    }

    /// 顶部菜单栏:锚定到状态栏图标下方(尾巴朝上);取不到图标则退回右上角。
    private func menuBarLayout(size: NSSize) -> (frame: NSRect, pointsDown: Bool) {
        let statusFrame = statusItemFrame()
        let screen = statusFrame
            .flatMap { f in NSScreen.screens.first { $0.frame.intersects(f) } }
            ?? ScreenPlacement.screenUnderMouse()
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let centerX = statusFrame?.midX ?? (visible.maxX - size.width / 2 - 12)
        var originX = centerX - size.width / 2
        originX = min(max(originX, visible.minX + 4), visible.maxX - size.width - 4)
        let originY = visible.maxY - size.height - 4
        return (NSRect(x: originX, y: originY, width: size.width, height: size.height), false)
    }

    /// 尝试定位状态栏图标窗口(用于顶部菜单栏锚定)。
    private func statusItemFrame() -> NSRect? {
        for window in NSApp.windows {
            let name = String(describing: type(of: window))
            if name.contains("StatusBar"), window.frame.height < 60 {
                return window.frame
            }
        }
        return nil
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    private func anchorFrame(for instanceID: UUID) -> NSRect? {
        for window in NSApp.windows {
            if let widgetPanel = window as? WidgetPanel, widgetPanel.instanceID == instanceID {
                return widgetPanel.frame
            }
        }
        return nil
    }
}
