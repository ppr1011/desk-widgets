# 整体架构总览

> 描述 DeskWidgets 的技术栈、目录结构、核心抽象与数据流。本文档需手动维护,不会自动同步代码变更。

## 技术栈

- **语言/框架**:Swift 5.10 + SwiftUI + AppKit(原生)
- **工程组织**:Swift Package Manager(`Package.swift` ≈ Maven `pom.xml`),仅需 Command Line Tools 即可编译运行
- **App 形态**:菜单栏常驻(`.accessory` / `LSUIElement`,无 Dock 图标)
- **打包**:`build-app.sh` 组装 `.app`;正式签名/公证/DMG 需完整 Xcode(里程碑 M5)

## 目录结构

```
Sources/DeskWidgets/
├── App/          入口、生命周期、菜单栏
│   ├── main.swift               NSApplication 启动
│   ├── AppDelegate.swift        装配 store / WindowManager / 菜单栏
│   └── StatusBarController.swift 菜单栏图标 + 菜单
├── Core/         组件框架与基础设施
│   ├── Widget.swift             WidgetProvider 协议(组件契约)
│   ├── WidgetKind.swift         组件类型枚举 + 窗口层级枚举
│   ├── WidgetInstance.swift     组件实例模型(Codable)
│   ├── WidgetRegistry.swift     组件注册表(类型→provider)
│   ├── WidgetStore.swift        桌面组件实例的状态 + 持久化
│   ├── WidgetPanel.swift        透明浮动窗口(NSPanel 封装)
│   ├── WindowManager.swift      数据↔窗口 diff 同步
│   ├── JSONCoders.swift         统一 JSON 编解码(见 ADR-0001)
│   └── FocusStore.swift         专注数据的状态 + 持久化
├── Models/
│   └── FocusModels.swift        专注相关模型/枚举
├── Widgets/      具体组件
│   ├── Clock/                   时钟(框架验证组件)
│   └── Focus/                   专注「守苗」小苗卡片
└── UI/
    └── ManagerView.swift        组件管理面板
```

## 核心抽象

| 类型 | 职责 | Java 类比 |
|---|---|---|
| `WidgetProvider`(protocol) | 组件契约:kind/displayName/defaultSize/makeView | `interface` |
| `WidgetRegistry` | 按类型注册/查找 provider | 工厂 Bean 注册表 |
| `WidgetInstance`(Codable) | 一个放在桌面上的组件实例 | DTO |
| `WidgetStore`(ObservableObject) | 实例集合 + JSON 持久化 | 可观察 Bean |
| `WidgetPanel`(NSPanel) | 承载组件的透明浮动窗口 | 底层原生窗口 |
| `WindowManager` | 订阅 store,创建/销毁窗口 | 监听器同步器 |
| `JSONCoders` | 全局统一的编解码配置 | 共享 ObjectMapper |

## 两条数据线

1. **桌面组件线**:`WidgetStore`(`widgets.json`)→ `WindowManager` diff → `WidgetPanel`。拖动组件 → panel 节流回写 frame → store 落盘。
2. **专注数据线**:`FocusStore`(`focus.json`)持有专注记录与花园,供小苗卡片与(后续)全屏会话读写。

两者都通过 `JSONCoders` 落盘到 `~/Library/Application Support/DeskWidgets/`。

## 扩展一个新组件

1. 在 `WidgetKind` 增加 case;
2. 实现 `WidgetProvider`;
3. 在 `WidgetRegistry.registerBuiltins()` 登记一行。

## 里程碑

- [x] M0 脚手架 + 菜单栏 + 透明窗口
- [x] M1 组件框架(协议/注册表/持久化/层级/恢复)+ 时钟
- [~] 专注组件「守苗」F0(数据模型 + FocusStore + 小苗卡片)—— 详见 [01-focus-widget.md](01-focus-widget.md)
- [ ] 便签/待办、系统监控等(backlog)
