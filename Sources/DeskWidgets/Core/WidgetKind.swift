import Foundation

/// 组件类型枚举。新增一种组件时在这里加一个 case。
/// 类比 Java:`enum WidgetKind { CLOCK("时钟"); ... }`,String 原始值用于 JSON 持久化。
enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case clock

    var id: String { rawValue }

    /// 兜底显示名(真正的显示名以各 WidgetProvider 为准)
    var title: String {
        switch self {
        case .clock: return "时钟"
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
