# 🤖 AI 办公助手组件 设计

> 第二款重量级组件。定位：桌面上一个全天候的 AI 办公伙伴。平时是一个安静的小头像，会在恰当的时刻（定点，或察觉你久坐/发呆/高负荷时）冒出一个气泡，说一句恰到好处的话——缓解压力、提高效率、健康工作。它感知你的待办、便签、屏幕使用与系统忙碌情况，但从不喧宾夺主。默认使用本地 Ollama，隐私优先、零成本。

## 一、定调

| 维度 | 决定 |
|---|---|
| 定位 | 全天候 AI 办公助手（关怀 + 提效 + 健康） |
| 形态 | 桌面小头像 + 按需弹出的浮动气泡 + 可展开对话/设置 |
| 触发 | 定时（默认 11:00 / 15:30 / 19:00，可配置）+ 事件（久坐/发呆/高负荷）+ 手动 |
| 人格 | 多人格可切换（温柔陪伴 / 高效教练 / 毒舌监工 / 禅意），**第一版先落地「温柔」，架构预留其余** |
| 模型 | 可选提供商，**默认本地 Ollama**；云端（OpenAI 兼容）为可选项 |
| 气泡 | **自定义桌面浮动气泡**（带指向头像的小尾巴），非系统通知 |
| 隐私 | 默认本地推理，上下文不出本机；切换云端时明确提示 |
| 不打扰原则 | 静默时段 + 每日频次上限 + 「稍后提醒」，宁可少说不可打扰 |

## 二、核心体验闭环

```
桌面小头像(今日已陪你 4h20m) 
   ├─ 定时触发(11:00/15:30/19:00)
   ├─ 事件触发(连续工作>90min / 发呆过久 / CPU 高负荷持续)
   └─ 手动「关心我一下」
        → ContextCollector 采集上下文
          (时间 · 待办 · 便签 · 屏幕使用时长 · 发呆时长 · CPU/内存/网络忙碌等级)
        → PromptBuilder 组装(场景 + 人格 + 上下文)
        → AIService 调 LLM(优先本地 Ollama;失败→本地兜底文案库)
        → 一句简短提示
        → BubblePresenter 在头像旁弹出浮动气泡
             ├ 知道了      → 关闭
             ├ 稍后提醒    → N 分钟后重弹
             └ 展开对话    → 打开对话面板,可继续追问
```

## 三、整体架构

```
Triggers(触发层)
  ├─ ReminderScheduler   定时:11:00/15:30/19:00 + 静默时段 + 频次上限
  └─ 事件触发             久坐 / 发呆 / 高负荷 / 手动
        ↓
Context(上下文采集层)
  ├─ ActivityTracker     屏幕使用时长 / 发呆(空闲)时长   ← 新增
  ├─ SystemMetricsSampler CPU / 内存 / 网络              ← 已有,直接订阅
  └─ ContextCollector    汇总待办/便签/系统信号 → 结构化上下文
        ↓
Brain(决策层)
  ├─ PromptBuilder       场景 + 人格 + 上下文 → System/User Prompt
  └─ AIService(LLMProvider 抽象)
        ├─ OllamaProvider            本地默认 http://localhost:11434
        └─ OpenAICompatibleProvider  云端可选 baseURL + apiKey + model
        ↓
UI(呈现层)
  ├─ BubblePresenter / BubblePanel   自定义浮动气泡
  └─ AIAgentWidget                   桌面头像 + 对话 + 设置
```

## 四、与现有架构的契合

沿用现有插件化模式（`WidgetProvider` + `WidgetRegistry` + `WidgetStore` JSON 持久化），增量集成：

| 复用现有能力 | 文件 | 用途 |
|---|---|---|
| 插件注册 | `Core/WidgetRegistry.swift` | 注册 `AIAgentWidget` |
| 全局状态/持久化 | `Core/WidgetStore.swift` | 实例配置、提示/对话历史 |
| 系统指标 | `Services/SystemMetricsSampler.swift` | 「忙碌情况」上下文（CPU/内存/网络已就绪） |
| 跨组件只读 | `store.instances[].config` | 读取待办 `items`、便签 `content` 作上下文 |
| 透明浮动窗口 | `Core/WidgetPanel.swift` | 气泡窗口技术基础 |
| 原生文本控件 | `UI/NativeTextControls.swift` | 对话输入框 |
| JSON 编解码 | `Core/JSONCoders.swift` | 序列化配置与历史 |

**需新建的能力（当前完全缺失）**：LLM 网络层、任务调度器、屏幕使用/发呆追踪、气泡通知系统、密钥安全存储。

## 五、模块设计

### 5.1 `AIAgentWidget`（`Widgets/AIAgent/`）
- 桌面形态：一个可爱头像（SF Symbol / emoji 角色）+ 状态行（如「今日已陪你 4h20m」）。
- 交互：
  - 点击头像 → 展开对话面板（最近提示列表 + 可主动追问）。
  - 齿轮 → 设置面板（提供商/模型/定时点/静默时段/人格/信号开关）。
  - 「关心我一下」→ 手动触发一次提示。
- `WidgetKind` 新增 `case aiAgent`；`acceptsKeyboardInput = true`（对话需输入，走 `NativeTextField`/`NativeTextEditor` + `InputActivationManager`）。

### 5.2 `AIService` + `LLMProvider` 抽象（`Services/AI/`）
统一协议，屏蔽提供商差异，**默认本地 Ollama**，原生 `URLSession`，无第三方依赖。

```swift
protocol LLMProvider {
    func chat(messages: [ChatMessage], model: String) async throws -> String
}
```

| Provider | 说明 | 端点 |
|---|---|---|
| `OllamaProvider`（默认） | 本地零成本、隐私最佳 | `POST http://localhost:11434/api/chat` |
| `OpenAICompatibleProvider` | 覆盖 OpenAI / DeepSeek / 通义 / Kimi 等 | `baseURL + apiKey + model` |

- 启动/触发前探测 Ollama 是否在线；离线或报错 → 降级为**本地兜底文案库**（预置数十条按场景分类的关怀语），保证断网也有气泡。

### 5.3 `ReminderScheduler`（`Services/AI/`）
- 管理定时点（默认 11:00 / 15:30 / 19:00，可增删改）。
- 「下一个触发时刻」定时器方案：`Timer` + `Date()` 绝对时间戳，避免后台/休眠漂移（参考专注组件的「计时铁律」）。
- 支持**静默时段**（午休/下班后不打扰）与**每日频次上限**。

### 5.4 `ActivityTracker`（`Services/AI/`）——新增信号
- **发呆/空闲时长**：`CGEventSource.secondsSinceLastEventType(.combinedSessionState, .any)` 取距上次键鼠输入的秒数。
- **屏幕使用时间**：累计「有输入活动」的时间；结合锁屏（`com.apple.screenIsLocked` via `DistributedNotificationCenter`）与休眠（`NSWorkspace.willSleepNotification`）扣除离开时段。按天统计，持久化 `ai-activity.json`。
- **久坐检测**：连续活跃时长超阈值 → 事件触发。

### 5.5 `ContextCollector` + `PromptBuilder`
把所有信号汇总为结构化上下文喂 LLM：

```
当前时间/时段、今日屏幕使用时长、连续工作/久坐时长、最近发呆时长、
CPU/内存/网络忙碌等级、待办(未完成 N 项 / 临近项)、便签摘要、触发场景
```

`PromptBuilder` 按「场景 + 人格 + 上下文」拼 System Prompt，要求 LLM 输出**一句简短气泡**（1~2 句，含一个可选小建议）。人格切换即切换 System Prompt 的语气模板。

### 5.6 `BubblePresenter` + `BubblePanel`（`UI/`）——自定义气泡
- 无边框 `NSPanel`，在 AI 头像附近弹出，**带指向头像的小尾巴**。
- 内容：一句关怀 + 操作按钮（`知道了` / `稍后提醒` / `展开对话`）。
- 进出 alpha 渐变；N 秒后自动消失；`collectionBehavior = [.canJoinAllSpaces, .stationary]` 跨 Space 显示。
- 定位：读取 AI 头像 panel 的 frame，在其上方/侧边计算气泡位置（含多屏边界处理，复用 `ScreenPlacement` 思路）。

### 5.7 配置与安全
- **`AISettingsStore`** → `ai-settings.json`：provider、model、baseURL、scheduleTimes、quietHours、enabledSignals、persona、dailyLimit。
- **API Key 存 Keychain**（新增 `KeychainStore` 封装），**绝不明文写 JSON**（仅云端 Provider 需要；Ollama 无需 Key）。

## 六、数据模型（`Models/AIModels.swift`）

- `Persona`：gentle / coach / roast / zen（运行期枚举，第一版仅 gentle 有完整模板）
- `LLMProviderKind`：ollama / openAICompatible
- `TriggerScene`：scheduled / longSitting / idle / highLoad / manual / conversation（运行期）
- `ChatMessage`：role(system/user/assistant) / content（运行期，可选持久化对话）
- `AISettings`（持久化）：provider / model / baseURL / scheduleTimes:[HHmm] / quietHours / enabledSignals:Set / persona / dailyLimit
- `ReminderRecord`（持久化）：id / firedAt / scene / message / provider / dismissed
- `DailyActivity`（持久化）：date / activeSeconds / longestIdleSeconds / sittingStreak
- **持久化**：`AISettingsStore` → `ai-settings.json`；活动统计 → `ai-activity.json`；提示/对话历史 → `instance.config` 或 `ai-history.json`（沿用 Todo 的 JSON-in-config 模式），统一走 `JSONCoders`（日期 ISO8601，见 ADR-0001）。

## 七、Prompt 示例（下午 15:30 定时触发 · 温柔人格）

> **System**：你是用户桌面上温柔的办公助手，只说 1~2 句话，语气自然不说教，可给一个小建议。
> **Context**：现在 15:30；今日屏幕已使用 6h10m；已连续工作 95 分钟未离开；待办剩 4 项（含「17:00 提交周报」临近）；CPU 高负荷持续中。
> → 期望输出：*「已经连续冲了一个半小时啦，起来接杯水吧～回来先搞定 17 点的周报，其它 3 项晚点也不迟。」*

## 八、关键技术难点 → 对策

| 难点 | 对策 |
|---|---|
| 无网络层 | 原生 `URLSession`，Ollama 本地端点，无三方依赖 |
| 定时器休眠漂移 | 全程 `Date()` 绝对时间戳，`Timer` 仅触发刷新 |
| 气泡在桌面层被遮挡 | `BubblePanel` 悬浮层级；可选叠加系统通知召回 |
| API Key 安全 | Keychain 存储，JSON 不落明文 |
| 打扰用户 | 静默时段 + 每日频次上限 + 「稍后提醒」 |
| 断网 / 无 Ollama | 本地兜底文案库降级 |
| 跨组件读上下文 | 只读遍历 `store.instances[].config`，不侵入其它组件 |
| 屏幕使用/发呆判定 | `CGEventSource` 空闲秒数 + 锁屏/休眠通知扣除离开时段 |

## 九、MVP 实现顺序

| 阶段 | 内容 | 验证点 |
|---|---|---|
| **A0** | `WidgetKind.aiAgent` + `AIAgentWidget` 头像卡片 + `AISettingsStore` | 桌面出现 AI 头像，可打开设置 |
| **A1** | `AIService` + `OllamaProvider` + 手动「关心我一下」 | 点击后调用本地 Ollama 出一句话 |
| **A2** | `BubblePresenter` + `BubblePanel` 自定义气泡 + 交互按钮 | 提示以浮动气泡弹出并可操作 |
| **A3** | `ReminderScheduler` 定时触发 + 静默时段 + 频次上限 | 到点自动弹气泡，非静默时段 |
| **A4** | `ContextCollector`（待办/便签/系统指标）接入 Prompt | 气泡内容真实反映当前工作状态 |
| **A5** | `ActivityTracker`（屏幕使用/发呆）+ 事件触发 + 久坐提醒 | 久坐/发呆时智能关怀 |
| **A6** | `OpenAICompatibleProvider` + Keychain + 多人格 + 断网兜底 | 可切云端模型、Key 安全、断网仍有气泡 |

## 十、后续迭代

云端多提供商预设、语音播报（TTS）、气泡角色形象/表情动画、周报总结（结合专注组件数据）、可训练的个性化偏好、成就与陪伴天数、与「守苗专注组件」联动（专注前后打气/复盘）。

## 十一、文件布局（规划）

```
Sources/DeskWidgets/
├── Widgets/AIAgent/
│   ├── AIAgentWidget.swift        # WidgetProvider + 头像/对话/设置 View
│   └── BubbleView.swift           # 气泡 SwiftUI 内容
├── Services/AI/
│   ├── AIService.swift            # LLMProvider 抽象 + 调度入口
│   ├── OllamaProvider.swift       # 本地默认
│   ├── OpenAICompatibleProvider.swift
│   ├── ReminderScheduler.swift    # 定时/事件触发
│   ├── ActivityTracker.swift      # 屏幕使用/发呆
│   ├── ContextCollector.swift     # 上下文汇总
│   ├── PromptBuilder.swift        # 场景+人格+上下文
│   └── FallbackMessages.swift     # 断网兜底文案库
├── Core/
│   ├── AISettingsStore.swift      # ai-settings.json
│   └── KeychainStore.swift        # API Key 安全存储
├── Models/
│   └── AIModels.swift             # 上述数据模型
└── UI/
    └── BubblePanel.swift          # 自定义浮动气泡 NSPanel
```
