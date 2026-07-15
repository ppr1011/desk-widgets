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

private struct ClockView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            VStack(spacing: 4) {
                Text(date, format: .dateTime.hour().minute().second())
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isDark ? .white : .black.opacity(0.85))
                Text(date, format: .dateTime.year().month().day().weekday(.wide))
                    .font(.system(size: 12))
                    .foregroundStyle(isDark ? Color.white.opacity(0.65) : Color.black.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(clockBackground)
        }
    }

    private var clockBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isDark
                            ? Color(red: 0.14, green: 0.15, blue: 0.18).opacity(0.75)
                            : Color.white.opacity(0.82)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08),
                        lineWidth: 0.5
                    )
            }
    }
}
