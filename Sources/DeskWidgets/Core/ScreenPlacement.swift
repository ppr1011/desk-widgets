import AppKit
import CoreGraphics

/// 组件在屏幕上的定位结果。
struct PlacementResult {
    let frame: CGRect
    let screenKey: String
}

enum ScreenPlacement {
    /// 将 frame 约束到指定可见区域内。
    static func clamp(_ frame: CGRect, to visible: CGRect) -> CGRect {
        var result = frame
        if result.width > visible.width { result.size.width = visible.width }
        if result.height > visible.height { result.size.height = visible.height }
        if result.minX < visible.minX { result.origin.x = visible.minX }
        if result.maxX > visible.maxX { result.origin.x = visible.maxX - result.width }
        if result.minY < visible.minY { result.origin.y = visible.minY }
        if result.maxY > visible.maxY { result.origin.y = visible.maxY - result.height }
        return result
    }

    /// 新建组件时放在鼠标所在屏幕(无则主屏),按 index 级联偏移。
    static func centeredOnActiveScreen(size: CGSize, index: Int = 0) -> PlacementResult {
        centeredFrame(size: size, screenKey: screenUnderMouse()?.placementKey, index: index)
    }

    /// 在指定屏幕上居中放置;screenKey 无效时根据 frame 推断,仍无效则用主屏。
    static func centeredFrame(
        size: CGSize,
        screenKey: String? = nil,
        index: Int = 0
    ) -> PlacementResult {
        let screen = resolveScreen(screenKey: screenKey, frame: nil) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let step = CGFloat(index) * 32
        let origin = CGPoint(
            x: visible.midX - size.width / 2 + step,
            y: visible.midY - size.height / 2 - step
        )
        let frame = clamp(CGRect(origin: origin, size: size), to: visible)
        let key = screen?.placementKey ?? NSScreen.main?.placementKey ?? "main"
        return PlacementResult(frame: frame, screenKey: key)
    }

    /// 将 frame 约束到其当前所在屏幕;仅当完全不可见时回退到已保存屏幕或主屏。
    static func normalizeFrame(
        _ frame: CGRect,
        screenKey: String? = nil,
        index: Int = 0
    ) -> PlacementResult {
        let screen = resolveScreen(screenKey: screenKey, frame: frame)
        if let screen {
            let visible = screen.visibleFrame
            if visible.intersects(frame) {
                return PlacementResult(
                    frame: clamp(frame, to: visible),
                    screenKey: screen.placementKey
                )
            }
            return centeredFrame(size: frame.size, screenKey: screen.placementKey, index: index)
        }
        return centeredFrame(size: frame.size, screenKey: nil, index: index)
    }

    /// 消除同一屏幕上完全重叠的组件位置。
    static func cascadeOverlapping(_ instances: [WidgetInstance]) -> [WidgetInstance] {
        var placedByScreen: [String: [CGRect]] = [:]
        return instances.map { instance in
            var current = instance
            let key = current.screenKey ?? ""
            var placed = placedByScreen[key, default: []]
            var index = 0
            while placed.contains(where: { overlapsSignificantly($0, current.frame) }) {
                index += 1
                let result = centeredFrame(
                    size: current.frame.size,
                    screenKey: current.screenKey,
                    index: index
                )
                current.frame = result.frame
                current.screenKey = result.screenKey
            }
            placed.append(current.frame)
            placedByScreen[key] = placed
            return current
        }
    }

    /// 鼠标当前所在的屏幕。
    static func screenUnderMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) }
    }

    /// 根据 frame 实际位置或 screenKey 查找屏幕。
    /// 优先按 frame 中心点匹配,以支持跨屏拖动;仅 frame 不可见时回退 screenKey。
    static func resolveScreen(screenKey: String?, frame: CGRect?) -> NSScreen? {
        if let frame {
            let center = CGPoint(x: frame.midX, y: frame.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
                return screen
            }
            if let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) {
                return screen
            }
        }
        if let key = screenKey, let matched = NSScreen.matching(key) {
            return matched
        }
        return nil
    }

    private static func overlapsSignificantly(_ a: CGRect, _ b: CGRect) -> Bool {
        a.equalTo(b) || a.intersection(b).area > 0.85 * min(a.area, b.area)
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}

private extension NSScreen {
    /// 显示器稳定标识:名称 + 全局 frame,用于重启后匹配屏幕。
    var placementKey: String {
        let frame = self.frame
        return "\(localizedName)|\(Int(frame.origin.x)),\(Int(frame.origin.y)),"
            + "\(Int(frame.width)),\(Int(frame.height))"
    }

    static func matching(_ key: String) -> NSScreen? {
        NSScreen.screens.first { $0.placementKey == key }
    }
}
