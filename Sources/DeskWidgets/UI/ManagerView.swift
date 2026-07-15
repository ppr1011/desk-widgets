import SwiftUI

/// 管理面板:列出已放置组件,可切换层级、删除。
/// @EnvironmentObject 注入 store,数据变化自动刷新(≈ 观察者绑定)。
struct ManagerView: View {
    @EnvironmentObject var store: WidgetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("已放置的组件").font(.headline)

            if store.instances.isEmpty {
                Spacer()
                Text("暂无组件\n请从菜单栏「添加组件」")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(store.instances) { instance in
                        row(instance)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .frame(width: 360, height: 420)
    }

    private func row(_ instance: WidgetInstance) -> some View {
        let name = WidgetRegistry.shared.provider(for: instance.kind)?.displayName
            ?? instance.kind.title
        return HStack {
            Image(systemName: "square.dashed")
            Text(name)
            Spacer()
            Button("显示") {
                let index = store.instances.firstIndex(where: { $0.id == instance.id }) ?? 0
                let placement = ScreenPlacement.centeredFrame(
                    size: instance.frame.size,
                    screenKey: instance.screenKey,
                    index: index
                )
                var updated = instance
                updated.frame = placement.frame
                updated.screenKey = placement.screenKey
                store.update(updated)
                // 同时把组件召回到当前正在查看的桌面(Space),避免它停留在别的桌面看不到。
                NotificationCenter.default.post(
                    name: WindowManager.moveToActiveSpaceNotification,
                    object: instance.id
                )
            }
            .buttonStyle(.bordered)
            .help("移到当前桌面并居中显示")
            Button(instance.level == .desktop ? "贴桌面" : "悬浮") {
                var updated = instance
                updated.level = (instance.level == .desktop) ? .floating : .desktop
                store.update(updated)
            }
            .buttonStyle(.bordered)
            // 删除
            Button(role: .destructive) {
                store.remove(id: instance.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}
