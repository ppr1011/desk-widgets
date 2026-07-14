import SwiftUI

/// 时钟组件 —— 用于验证组件框架跑通(便签/系统监控在后续里程碑)。
/// 实现 WidgetProvider(≈ 实现 interface)并在 WidgetRegistry.registerBuiltins() 登记。
struct ClockWidget: WidgetProvider {
    let kind: WidgetKind = .clock
    let displayName = "时钟"
    let defaultSize = CGSize(width: 220, height: 110)

    func makeView(instance: WidgetInstance, store: WidgetStore) -> AnyView {
        AnyView(ClockView())
    }
}

/// TimelineView(.periodic) 让 SwiftUI 每秒自动重绘,无需手动 Timer。
private struct ClockView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            VStack(spacing: 4) {
                Text(date, format: .dateTime.hour().minute().second())
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(date, format: .dateTime.year().month().day().weekday(.wide))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
