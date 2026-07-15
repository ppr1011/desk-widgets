# DeskWidgets

macOS 桌面小组件管理工具(类似 Widgetify)。在桌面上放置可拖动、可配置的浮动小组件,并通过菜单栏统一管理。

- **技术栈**:Swift 5.10 + SwiftUI + AppKit(原生),SwiftPM 组织项目
- **形态**:菜单栏常驻 App + 透明浮动 `NSPanel` 承载 SwiftUI 组件
- **定位**:认真做的产品(插件化组件架构,面向后续扩展与分发)

> 面向读者:资深 Java 开发者、Swift 新手。代码注释中大量使用 Java 类比。

## 开发命令

```bash
swift build            # 编译(仅需 Command Line Tools,无需完整 Xcode)
./build-app.sh         # 编译并组装成 DeskWidgets.app
open DeskWidgets.app   # 启动(菜单栏出现 ▦ 图标)

# 前台运行看日志/崩溃信息:
./DeskWidgets.app/Contents/MacOS/DeskWidgets
```

> 打包分发(签名 / 公证 / DMG / 上架)需安装完整 Xcode —— 见里程碑 M5。

## 项目结构

```
Sources/DeskWidgets/
├── App/                 # 入口、生命周期、菜单栏
├── Core/                # 组件框架:协议 / 注册表 / 模型 / 持久化 / 窗口封装
├── Widgets/             # 各具体组件(Clock / Note / Todo / SystemMonitor)
├── Services/            # 系统指标采集(SystemMetricsSampler)
└── UI/                  # 管理面板
```

## 核心架构(Java 类比)

| Swift | 作用 | Java 类比 |
|---|---|---|
| `WidgetProvider`(protocol) | 组件契约 | `interface` |
| `WidgetRegistry` | 按类型注册 provider | 工厂 Bean 注册表 |
| `WidgetInstance`(Codable) | 组件实例模型 | 带 Jackson 注解的 DTO |
| `WidgetStore`(ObservableObject) | 状态 + JSON 持久化 | 可观察 Bean |
| `WidgetPanel`(NSPanel) | 透明浮动窗口 | 无(底层原生窗口) |
| `WindowManager` | 数据↔窗口桥接 | 监听器同步器 |

**数据流**:菜单/管理面板改动 → `WidgetStore`(自动落盘 `~/Library/Application Support/DeskWidgets/widgets.json`)→ `WindowManager` diff → 创建/关闭 `WidgetPanel`。拖动组件 → panel 节流回写 frame → store 落盘。

**扩展一个新组件**:① 在 `WidgetKind` 加 case;② 实现 `WidgetProvider`;③ 在 `WidgetRegistry.registerBuiltins()` 登记。

## 里程碑进度

- [x] **M0** 脚手架 + 菜单栏 App + 透明浮动窗口
- [x] **M1** 组件框架(协议 / 注册表 / 持久化 / 窗口层级 / 启动恢复)+ 时钟组件验证
- [x] **M2** 便签 / 待办组件
- [x] **M3** 系统监控组件(CPU / 内存 / 网速)
- [ ] **M4** 管理面板打磨 + 开机自启(SMAppService)
- [ ] **M5** 打包分发(Xcode / 签名 / 公证 / DMG)

## 沙盒说明

系统监控用到的部分底层 API 在 App Store 沙盒下受限。优先目标为**非沙盒 DMG 分发**;App Store 上架作为后续可选目标评估。
