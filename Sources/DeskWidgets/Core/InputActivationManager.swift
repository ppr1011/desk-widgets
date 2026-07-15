import AppKit

/// 便签/待办获得焦点时激活 App 以接收键盘输入。
/// 注意:不可切换为 .regular,否则 Dock 会出现图标。
final class InputActivationManager: NSObject {
    static let shared = InputActivationManager()

    private override init() {
        super.init()
    }

    func activateForInput() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
