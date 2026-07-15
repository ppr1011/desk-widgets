import SwiftUI

/// 系统监控组件 —— 展示 CPU / 内存 / 网速,数据来自 SystemMetricsSampler。
struct SystemMonitorWidget: WidgetProvider {
    let kind: WidgetKind = .systemMonitor
    let displayName = "系统监控"
    let defaultSize = CGSize(width: 280, height: 220)

    func makeView(instance: WidgetInstance, store: WidgetStore) -> AnyView {
        AnyView(SystemMonitorView())
    }
}

private struct SystemMonitorView: View {
    @ObservedObject private var sampler = SystemMetricsSampler.shared
    @Environment(\.colorScheme) private var colorScheme

    private var memPercent: Double {
        guard sampler.memoryTotal > 0 else { return 0 }
        return Double(sampler.memoryUsed) / Double(sampler.memoryTotal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            metricCard(
                icon: "cpu",
                tint: Color(red: 0.35, green: 0.62, blue: 1.0),
                label: "CPU",
                value: String(format: "%.0f%%", sampler.cpuUsage),
                progress: sampler.cpuUsage / 100
            )

            metricCard(
                icon: "memorychip",
                tint: Color(red: 0.55, green: 0.45, blue: 1.0),
                label: "内存",
                value: "\(formatBytes(sampler.memoryUsed)) / \(formatBytes(sampler.memoryTotal))",
                progress: memPercent
            )

            HStack(spacing: 8) {
                networkCard(
                    icon: "arrow.down",
                    tint: Color(red: 0.2, green: 0.78, blue: 0.55),
                    label: "下载",
                    speed: sampler.downloadSpeed
                )
                networkCard(
                    icon: "arrow.up",
                    tint: Color(red: 1.0, green: 0.55, blue: 0.35),
                    label: "上传",
                    speed: sampler.uploadSpeed
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
        .onAppear {
            sampler.addSubscriber()
        }
        .onDisappear {
            sampler.removeSubscriber()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentGradient)
            Text("系统监控")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .shadow(color: .green.opacity(0.6), radius: 3)
        }
    }

    private func metricCard(
        icon: String,
        tint: Color,
        label: String,
        value: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(labelColor)
                Spacer()
                Text(value)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(valueColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackColor)
                    Capsule()
                        .fill(progressGradient(for: progress, tint: tint))
                        .frame(width: geo.size.width * min(max(progress, 0), 1))
                        .animation(.easeInOut(duration: 0.35), value: progress)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(metricCardBackground)
    }

    private func networkCard(icon: String, tint: Color, label: String, speed: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 7)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(labelColor)
                Text("\(formatSpeed(speed))/s")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(valueColor)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(metricCardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        colorScheme == .dark
                            ? Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.55)
                            : Color.white.opacity(0.45)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(0.12)
                            : Color.white.opacity(0.55),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 12, y: 4)
    }

    private var metricCardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                colorScheme == .dark
                    ? Color.white.opacity(0.07)
                    : Color.black.opacity(0.04)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.black.opacity(0.05),
                        lineWidth: 0.5
                    )
            }
    }

    private var labelColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.65)
            : Color.black.opacity(0.55)
    }

    private var valueColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.92)
            : Color.black.opacity(0.82)
    }

    private var trackColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.35, green: 0.62, blue: 1.0),
                Color(red: 0.55, green: 0.45, blue: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func progressGradient(for progress: Double, tint: Color) -> LinearGradient {
        let accent = progressAccent(progress, fallback: tint)
        return LinearGradient(
            colors: [accent.opacity(0.85), accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func progressAccent(_ progress: Double, fallback: Color) -> Color {
        if progress > 0.85 { return Color(red: 1.0, green: 0.38, blue: 0.38) }
        if progress > 0.6 { return Color(red: 1.0, green: 0.62, blue: 0.25) }
        return fallback
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if value >= 1_073_741_824 {
            return String(format: "%.1f GB", value / 1_073_741_824)
        }
        if value >= 1_048_576 {
            return String(format: "%.0f MB", value / 1_048_576)
        }
        return String(format: "%.0f KB", value / 1_024)
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1f MB", bytesPerSec / 1_048_576)
        }
        if bytesPerSec >= 1_024 {
            return String(format: "%.1f KB", bytesPerSec / 1_024)
        }
        return String(format: "%.0f B", bytesPerSec)
    }
}
