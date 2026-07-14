# ADR-0001:统一 JSON 编解码约定

- 状态:已采纳
- 日期:2026-07-14

## 背景

项目有多处本地持久化:`WidgetStore`(`widgets.json`)、`FocusStore`(`focus.json`)。最初两处各自 `new` 一个 `JSONEncoder`:

- `WidgetStore`:只设了 `outputFormatting`,没设日期策略(因为 `WidgetInstance` 没有 `Date` 字段,当时"没表态")。
- `FocusStore`:设了 `.iso8601` 日期策略(因为有 `Date` 字段)。

结果是**两处编解码配置不一致**,且没有单一出处 —— 随着 store 增多必然继续跑偏。

## 决策

抽一个共享工厂 `Core/JSONCoders.swift`,所有持久化统一经过它:

```swift
enum JSONCoders {
    static func makeEncoder() -> JSONEncoder   // .prettyPrinted + .sortedKeys + .iso8601
    static func makeDecoder() -> JSONDecoder   // .iso8601
}
```

日期策略统一为 **ISO8601**。

## 理由

- **一致性**:单一出处,新增 store 直接复用,不会再各写各的。
- **可读性**:ISO8601 在 json 里是 `"2026-07-14T10:00:00Z"`,便于调试查看;默认策略是 `timeIntervalSinceReferenceDate` 浮点秒数(如 `773452800.0`),不可读。
- **稳定性**:ISO8601 跨版本/跨平台含义明确。
- **diff 友好**:`sortedKeys` 让 json 键有序,版本管理 diff 干净。

## 影响

- `WidgetStore.load/save`、`FocusStore.load/persist` 均改用 `JSONCoders`。
- `WidgetInstance` 当前无 `Date`,改动对既有 `widgets.json` 无影响(无日期可解)。
- 约定:**今后任何本地 JSON 持久化都必须走 `JSONCoders`**,不要再直接 `new JSONEncoder()`。
