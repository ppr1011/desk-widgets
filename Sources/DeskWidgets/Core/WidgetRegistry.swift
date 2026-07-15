import Foundation

/// 组件注册表:按类型存放 provider。类比 Spring 里按类型注册的工厂 Bean。
/// 单例(shared),App 启动时注册所有内置组件。
final class WidgetRegistry {
    static let shared = WidgetRegistry()

    private(set) var providers: [WidgetKind: WidgetProvider] = [:]

    private init() {}

    func register(_ provider: WidgetProvider) {
        providers[provider.kind] = provider
    }

    func provider(for kind: WidgetKind) -> WidgetProvider? {
        providers[kind]
    }

    /// 按 WidgetKind 声明顺序返回所有已注册 provider(用于菜单/管理面板列表)
    var allProviders: [WidgetProvider] {
        WidgetKind.allCases.compactMap { providers[$0] }
    }

    /// 注册所有内置组件。新增组件后在这里补一行。
    func registerBuiltins() {
        register(ClockWidget())
        register(NoteWidget())
        register(TodoWidget())
        register(SystemMonitorWidget())
    }
}
