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

    init(instance: WidgetInstance, contentView: NSView) {
        self.instanceID = instance.id
        super.init(
            contentRect: instance.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        isMovable = true
        isMovableByWindowBackground = true
        // 透明:窗口本身不画背景,交给内部 SwiftUI 视图
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        // 在所有 Space 显示、不进 Mission Control 循环、不随桌面切换
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.contentView = contentView
        delegate = self
        applyLevel(instance.level)
        setFrame(instance.frame, display: true)
    }

    /// borderless 窗口默认无法成为 key/main;组件若需键盘输入(如便签)必须放开
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// 切换窗口层级
    func applyLevel(_ level: WidgetLevel) {
        switch level {
        case .desktop:
            // 贴桌面层:像壁纸挂件,位于普通窗口之下
            self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        case .floating:
            self.level = .floating
        }
    }

    // MARK: - NSWindowDelegate:移动/缩放后节流落盘

    func windowDidMove(_ notification: Notification) { scheduleFrameSave() }
    func windowDidResize(_ notification: Notification) { scheduleFrameSave() }

    /// 拖动过程中会连续触发,debounce 0.4s 后再回写,避免频繁写磁盘
    private func scheduleFrameSave() {
        saveWorkItem?.cancel()
        let frame = self.frame
        let work = DispatchWorkItem { [weak self] in self?.onFrameChanged?(frame) }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}
