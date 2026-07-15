import SwiftUI

/// 待办组件 —— 支持增删改查与勾选完成,列表以 JSON 存入 instance.config["items"]。
struct TodoWidget: WidgetProvider {
    let kind: WidgetKind = .todo
    let displayName = "待办"
    let defaultSize = CGSize(width: 260, height: 280)

    func makeView(instance: WidgetInstance, store: WidgetStore) -> AnyView {
        AnyView(TodoView(instanceID: instance.id, store: store))
    }
}

private struct TodoItem: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    var isDone: Bool

    init(id: UUID = UUID(), text: String, isDone: Bool = false) {
        self.id = id
        self.text = text
        self.isDone = isDone
    }
}

private enum TodoCodec {
    static func decode(from config: [String: String]) -> [TodoItem] {
        guard let raw = config["items"],
              let data = raw.data(using: .utf8),
              let items = try? JSONCoders.makeDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return items
    }

    static func encode(_ items: [TodoItem]) -> String {
        guard let data = try? JSONCoders.makeEncoder().encode(items),
              let raw = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return raw
    }
}

private struct TodoView: View {
    let instanceID: UUID
    @ObservedObject var store: WidgetStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var items: [TodoItem] = []
    @State private var newItemText = ""

    private let accent = Color(red: 0.25, green: 0.55, blue: 1.0)

    private var doneCount: Int {
        items.filter(\.isDone).count
    }

    private var progress: Double {
        items.isEmpty ? 0 : Double(doneCount) / Double(items.count)
    }

    private var isDark: Bool { colorScheme == .dark }

    private var titleColor: Color {
        isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.85)
    }

    private var labelColor: Color {
        isDark ? Color.white.opacity(0.6) : Color.black.opacity(0.5)
    }

    private var rowBg: Color {
        isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }

    var body: some View {
        VStack(spacing: 10) {
            WindowDragHandle(instanceID: instanceID, store: store, title: "待办")

            header

            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(items) { item in
                            todoRow(item)
                        }
                    }
                    .padding(.bottom, 2)
                }
            }

            inputBar
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
        .onAppear {
            loadItems()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(accent, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("待办事项")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                    Spacer()
                    if !items.isEmpty {
                        Text("\(doneCount)/\(items.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(labelColor)
                    }
                }
                if !items.isEmpty {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                            Capsule()
                                .fill(progress >= 1 ? Color.green : accent)
                                .frame(width: geo.size.width * progress)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(labelColor)
            Text("暂无任务")
                .font(.callout.weight(.medium))
                .foregroundStyle(labelColor)
            Text("在下方输入并回车添加")
                .font(.caption2)
                .foregroundStyle(labelColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundStyle(labelColor)
            NativeTextField(text: $newItemText, placeholder: "添加新任务…", onSubmit: addItem)
            Button(action: addItem) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(canAdd ? accent : labelColor.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rowBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    private var canAdd: Bool {
        !newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        isDark
                            ? Color(red: 0.14, green: 0.15, blue: 0.18).opacity(0.75)
                            : Color.white.opacity(0.82)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(isDark ? 0.4 : 0.12), radius: 10, y: 3)
    }

    private func todoRow(_ item: TodoItem) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleItem(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(item.isDone ? Color.green : labelColor)
            }
            .buttonStyle(.plain)

            Text(item.text)
                .font(.callout)
                .strikethrough(item.isDone, color: labelColor)
                .foregroundStyle(item.isDone ? labelColor : titleColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)

            Button {
                deleteItem(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(labelColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(item.isDone ? Color.green.opacity(isDark ? 0.15 : 0.1) : rowBg)
        )
    }

    private func loadItems() {
        guard let instance = store.instance(id: instanceID) else { return }
        items = TodoCodec.decode(from: instance.config)
    }

    private func persist() {
        guard var instance = store.instance(id: instanceID) else { return }
        instance.config["items"] = TodoCodec.encode(items)
        store.update(instance)
    }

    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        items.append(TodoItem(text: text))
        newItemText = ""
        persist()
        InputActivationManager.shared.activateForInput()
    }

    private func toggleItem(_ item: TodoItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isDone.toggle()
        persist()
    }

    private func deleteItem(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }
}
