import AppKit

/// 强制保持菜单栏 App 模式(.accessory),避免 Dock 出现图标。
enum AccessoryModeEnforcer {
    static func apply() {
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
