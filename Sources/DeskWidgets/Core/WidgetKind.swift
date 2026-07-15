import Foundation

/// 组件类型枚举。新增一种组件时在这里加一个 case。
/// 类比 Java:`enum WidgetKind { CLOCK("时钟"); ... }`,String 原始值用于 JSON 持久化。
enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case clock
    case note
    case todo
    case systemMonitor
    case aiAgent

    var id: String { rawValue }

    /// 兜底显示名(真正的显示名以各 WidgetProvider 为准)
    var title: String {
        switch self {
        case .clock: return "时钟"
        case .note: return "便签"
        case .todo: return "待办"
        case .systemMonitor: return "系统监控"
        case .aiAgent: return "AI 助手"
        }
    }

    /// 是否需要键盘/按钮交互(便签/待办)。为 true 时窗口可激活且关闭背景拖动。
    var acceptsKeyboardInput: Bool {
        switch self {
        case .note, .todo, .aiAgent: return true
        default: return false
        }
    }

    /// 是否允许放置多个实例。AI 助手为全局单例(共享同一份设置),只允许一个。
    var allowsMultiple: Bool {
        switch self {
        case .aiAgent: return false
        default: return true
        }
    }
}

/// 组件所在的窗口层级。
/// - desktop:贴桌面层,像壁纸上的挂件(在普通窗口之下)
/// - floating:悬浮置顶,始终在最前
enum WidgetLevel: String, Codable {
    case desktop
    case floating
}
