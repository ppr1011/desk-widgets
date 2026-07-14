import Foundation
import CoreGraphics

/// 一个"放在桌面上的组件"实例。可序列化为 JSON 持久化。
/// 类比 Java:一个带 Jackson 注解的 DTO/record。
/// 注意:CGRect/CGPoint/CGSize 在导入 Foundation 后已自带 Codable 能力。
struct WidgetInstance: Codable, Identifiable, Equatable {
    let id: UUID
    var kind: WidgetKind
    /// 窗口位置与尺寸(屏幕坐标系,原点在左下角 —— AppKit 约定)
    var frame: CGRect
    var level: WidgetLevel
    /// 各组件私有配置。用字符串字典保持通用;复杂内容(如便签文本)也以字符串存放。
    var config: [String: String]

    init(
        id: UUID = UUID(),
        kind: WidgetKind,
        frame: CGRect,
        level: WidgetLevel = .floating,
        config: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.frame = frame
        self.level = level
        self.config = config
    }
}
