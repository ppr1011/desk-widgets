import SwiftUI

/// 便签组件 —— 支持自由文本编辑,内容持久化到 instance.config["content"]。
struct NoteWidget: WidgetProvider {
    let kind: WidgetKind = .note
    let displayName = "便签"
    let defaultSize = CGSize(width: 240, height: 200)

    func makeView(instance: WidgetInstance, store: WidgetStore) -> AnyView {
        AnyView(NoteView(instanceID: instance.id, store: store))
    }
}

private struct NoteView: View {
    let instanceID: UUID
    @ObservedObject var store: WidgetStore
    @State private var text = ""
    @State private var saveWorkItem: DispatchWorkItem?

    private var noteColor: Color {
        let raw = store.instance(id: instanceID)?.config["color"] ?? "yellow"
        switch raw {
        case "pink": return Color(red: 1.0, green: 0.85, blue: 0.9)
        case "blue": return Color(red: 0.85, green: 0.92, blue: 1.0)
        case "green": return Color(red: 0.88, green: 0.96, blue: 0.88)
        default: return Color(red: 1.0, green: 0.96, blue: 0.7)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            WindowDragHandle(instanceID: instanceID, store: store, title: "便签")
            HStack {
                Spacer()
                colorPicker
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 4)

            NativeTextEditor(text: $text) { newValue in
                scheduleSave(content: newValue)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(noteColor, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            text = store.instance(id: instanceID)?.config["content"] ?? ""
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 4) {
            ForEach(["yellow", "pink", "blue", "green"], id: \.self) { name in
                Button {
                    saveColor(name)
                } label: {
                    Circle()
                        .fill(colorForName(name))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    store.instance(id: instanceID)?.config["color"] == name
                                        ? Color.primary.opacity(0.6) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "pink": return Color(red: 1.0, green: 0.75, blue: 0.85)
        case "blue": return Color(red: 0.7, green: 0.85, blue: 1.0)
        case "green": return Color(red: 0.75, green: 0.92, blue: 0.75)
        default: return Color(red: 1.0, green: 0.9, blue: 0.5)
        }
    }

    private func scheduleSave(content: String) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [instanceID] in
            guard var instance = store.instance(id: instanceID) else { return }
            instance.config["content"] = content
            store.update(instance)
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func saveColor(_ name: String) {
        guard var instance = store.instance(id: instanceID) else { return }
        instance.config["color"] = name
        store.update(instance)
    }
}
