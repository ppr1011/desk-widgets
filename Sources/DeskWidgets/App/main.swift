import AppKit

// 程序入口。executableTarget 中存在 main.swift 即作为启动文件。
// 用 AppKit 手动启动(而非 SwiftUI @main App),以便完全控制菜单栏 App 行为。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// .accessory:无 Dock 图标、无主菜单栏,纯菜单栏常驻(等价于 Info.plist 的 LSUIElement)
app.setActivationPolicy(.accessory)
app.run()
