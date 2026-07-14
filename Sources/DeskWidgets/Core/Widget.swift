import SwiftUI

/// 组件契约(protocol ≈ Java interface)。
/// 每种组件实现该协议,并注册到 WidgetRegistry。
/// 新增组件 = 实现此协议 + 在注册表登记 + 在 WidgetKind 增加 case。
protocol WidgetProvider {
    /// 该 provider 对应的组件类型
    var kind: WidgetKind { get }
    /// 面向用户的显示名(用于菜单/管理面板)
    var displayName: String { get }
    /// 新建时的默认尺寸
    var defaultSize: CGSize { get }

    /// 根据实例与全局 store 产出 SwiftUI 视图。
    /// 用 AnyView 做类型擦除,以便注册表统一存放不同 provider(类比返回 interface 引用)。
    func makeView(instance: WidgetInstance, store: WidgetStore) -> AnyView
}
