import Foundation
import Combine

/// 全局状态与持久化。ObservableObject ≈ 带监听器的可观察 Bean:
/// @Published 的属性一变化,订阅者(SwiftUI 视图 / WindowManager)自动收到通知。
final class WidgetStore: ObservableObject {
    /// 桌面上所有组件实例
    @Published private(set) var instances: [WidgetInstance] = []

    /// 落盘路径:~/Library/Application Support/DeskWidgets/widgets.json
    private let fileURL: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeskWidgets", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("widgets.json")
        load()
    }

    // MARK: - 增删改(每次变更后自动落盘)

    func add(_ instance: WidgetInstance) {
        instances.append(instance)
        save()
    }

    func remove(id: UUID) {
        instances.removeAll { $0.id == id }
        save()
    }

    /// 更新某个实例(拖动、改配置、切换层级时调用)
    func update(_ instance: WidgetInstance) {
        guard let idx = instances.firstIndex(where: { $0.id == instance.id }) else { return }
        instances[idx] = instance
        save()
    }

    /// 仅更新位置/尺寸(拖动/缩放结束时),避免整对象替换
    func updateFrame(id: UUID, frame: CGRect) {
        guard let idx = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[idx].frame = frame
        save()
    }

    func instance(id: UUID) -> WidgetInstance? {
        instances.first { $0.id == id }
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONCoders.makeDecoder().decode([WidgetInstance].self, from: data) else { return }
        instances = decoded
    }

    private func save() {
        guard let data = try? JSONCoders.makeEncoder().encode(instances) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
