import AppKit

/// 应用生命周期。类比 Java 里 main 启动后装配各单例组件。
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = WidgetStore()
    private var windowManager: WindowManager!
    private var statusBar: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1) 注册内置组件
        WidgetRegistry.shared.registerBuiltins()
        // 2) 启动窗口管理器(订阅 store,自动恢复已保存组件)
        windowManager = WindowManager(store: store)
        // 3) 菜单栏图标
        statusBar = StatusBarController(store: store)
    }
}
