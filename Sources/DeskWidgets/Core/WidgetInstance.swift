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
    /// 所属显示器标识(名称+frame),重启后恢复到对应屏幕
    var screenKey: String?
    /// 各组件私有配置。用字符串字典保持通用;复杂内容(如便签文本)也以字符串存放。
    var config: [String: String]
    /// 是否在所有桌面(Space)显示。false = 仅停留在其所在的那个桌面。
    var showOnAllSpaces: Bool

    init(
        id: UUID = UUID(),
        kind: WidgetKind,
        frame: CGRect,
        level: WidgetLevel = .desktop,
        screenKey: String? = nil,
        config: [String: String] = [:],
        showOnAllSpaces: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.frame = frame
        self.level = level
        self.screenKey = screenKey
        self.config = config
        self.showOnAllSpaces = showOnAllSpaces
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, frame, level, screenKey, config, showOnAllSpaces
    }

    /// 容错解码:老数据缺少 showOnAllSpaces 字段时回退为 false。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(WidgetKind.self, forKey: .kind)
        frame = try c.decode(CGRect.self, forKey: .frame)
        level = try c.decodeIfPresent(WidgetLevel.self, forKey: .level) ?? .desktop
        screenKey = try c.decodeIfPresent(String.self, forKey: .screenKey)
        config = try c.decodeIfPresent([String: String].self, forKey: .config) ?? [:]
        showOnAllSpaces = try c.decodeIfPresent(Bool.self, forKey: .showOnAllSpaces) ?? false
    }
}
