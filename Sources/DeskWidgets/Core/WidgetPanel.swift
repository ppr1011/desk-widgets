import AppKit

/// 承载单个桌面组件的透明浮动窗口(NSPanel 封装)—— 本项目的技术核心。
/// - borderless:无标题栏
/// - 透明背景:让 SwiftUI 视图自己决定外观(圆角、毛玻璃)
/// - isMovableByWindowBackground:拖动组件任意位置即可移动整个窗口
/// - level:切换"贴桌面层 / 悬浮置顶"
final class WidgetPanel: NSPanel, NSWindowDelegate {
    let instanceID: UUID
    /// 拖动/缩放结束后回写新 frame(由 WindowManager 注入 -> 落盘)
    var onFrameChanged: ((CGRect) -> Void)?
    private var saveWorkItem: DispatchWorkItem?

    /// 低于普通窗口一级,仍在壁纸之上,可接收鼠标事件(桌面层收不到点击)
    private static let belowNormalLevel = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1
    )

    init(instance: WidgetInstance, contentView: NSView, acceptsKeyboardInput: Bool = false) {
        self.instanceID = instance.id
        var style: NSWindow.StyleMask = [.borderless]
        if !acceptsKeyboardInput {
            style.insert(.nonactivatingPanel)
        }
        super.init(
            contentRect: instance.frame,
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovable = true
        acceptsMouseMovedEvents = true
        // 交互型组件(便签/待办)关闭背景拖动,否则 TextField/Button 点击会被吞掉
        isMovableByWindowBackground = !acceptsKeyboardInput
        becomesKeyOnlyIfNeeded = false
        if acceptsKeyboardInput {
            worksWhenModal = true
        }
        isExcludedFromWindowsMenu = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        self.contentView = contentView
        contentView.autoresizingMask = [.width, .height]
        delegate = self
        applyLevel(instance.level)
        applySpaceBehavior(instance.showOnAllSpaces)
        setFrame(instance.frame, display: true)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// 应用桌面(Space)显示策略。
    /// - true:在所有桌面显示(常驻,跟随切换)。
    /// - false:仅停留在其所在桌面。
    func applySpaceBehavior(_ showOnAllSpaces: Bool) {
        collectionBehavior = showOnAllSpaces
            ? [.canJoinAllSpaces, .stationary, .ignoresCycle]
            : [.ignoresCycle]
    }

    /// 把组件移动到当前正在显示的桌面(Space),保持原位置。
    /// 可靠做法:先隐藏窗口 → 设为 .moveToActiveSpace → 重新 orderFront,
    /// 让系统把它当作"新出现的窗口"落到当前桌面;稳定后恢复为仅当前桌面(钉住)。
    func moveToActiveSpace() {
        let targetFrame = frame
        orderOut(nil)
        collectionBehavior = [.moveToActiveSpace, .ignoresCycle]
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setFrame(targetFrame, display: false)
            self.orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.collectionBehavior = [.ignoresCycle]
            }
        }
    }

    /// 切换窗口层级
    func applyLevel(_ level: WidgetLevel) {
        switch level {
        case .desktop:
            // 贴桌面:低于普通 App 窗口,但高于壁纸,保留鼠标交互能力
            isFloatingPanel = true
            self.level = Self.belowNormalLevel
        case .floating:
            isFloatingPanel = true
            self.level = .floating
        }
    }

    func windowDidMove(_ notification: Notification) { scheduleFrameSave() }
    func windowDidResize(_ notification: Notification) { scheduleFrameSave() }

    private func scheduleFrameSave() {
        saveWorkItem?.cancel()
        let frame = self.frame
        let work = DispatchWorkItem { [weak self] in self?.onFrameChanged?(frame) }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}
