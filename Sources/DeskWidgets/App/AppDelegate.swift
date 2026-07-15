import AppKit

/// 应用生命周期。类比 Java 里 main 启动后装配各单例组件。
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = WidgetStore()
    private var windowManager: WindowManager!
    private var statusBar: StatusBarController!

    func applicationWillFinishLaunching(_ notification: Notification) {
        AccessoryModeEnforcer.apply()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else { return }
        AccessoryModeEnforcer.apply()
        WidgetRegistry.shared.registerBuiltins()
        windowManager = WindowManager(store: store)
        statusBar = StatusBarController(store: store)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AccessoryModeEnforcer.apply()
    }

    /// 禁止多开:重复启动时激活已有实例并退出当前进程。
    private func ensureSingleInstance() -> Bool {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let others = NSWorkspace.shared.runningApplications.filter { app in
            app.processIdentifier != currentPID
                && (app.bundleIdentifier == Bundle.main.bundleIdentifier
                    || app.localizedName == "DeskWidgets"
                    || app.executableURL?.lastPathComponent == "DeskWidgets")
        }
        if let existing = others.first {
            existing.activate(options: [.activateIgnoringOtherApps])
            NSApp.terminate(nil)
            return false
        }
        return true
    }
}
