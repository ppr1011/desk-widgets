# 🌱 守苗 · 专注组件 设计

> 第一款组件。定位:一个温柔但有原则的专注伙伴。平时是桌面上一株安静的小苗,需要专注时化作全屏护眼结界。它从不责备你,但你亲手栽下的树苗,会因你的坚持而长大,因你的分心而枯萎。

## 一、定调

| 维度 | 决定 |
|---|---|
| 基调 | 正负结合(生长收获 ↔ 枯萎断连) |
| 形态 | 桌面小组件 ⇄ 全屏专注会话 可切换 |
| 人格 | 温柔陪伴(第一版单人格,架构预留多人格) |
| 分心检测 | 缓冲期机制(切走有宽限,及时归位不算失败) |
| 视觉主角 | 🌱 树苗成长 |
| 时长 | 预设(25/45/60)+ 自定义 |
| 离开电脑(锁屏/休眠) | 视为离开 → 进入缓冲 |

## 二、核心体验闭环

```
桌面小苗(今日 2h15m·连胜6天) ─点击→ 设意图+选时长 ─→ 三次呼吸(可跳过)
   ─→ 全屏护眼结界(暖色·呼吸光·树苗生长·温柔文案·计时)
       ├ 时间到 → 收获成树 → 花园 → 休息/再战一程
       └ 切出去 → 分心·缓冲中(15s) ─┬ 及时归位 → 继续(记1次分心)
                                      └ 超时未归 → 枯萎·连胜清零(温柔安慰)
```

## 三、核心状态机 `FocusSession`(ObservableObject)

`@Published`:`phase / remaining / graceRemaining / growthProgress`,变更自动驱动 SwiftUI 重绘。

```
idle ──start(config)──▶ focusing        // startAt = Date()
focusing ──remaining≤0──▶ completed      // 写 FocusRecord + GardenTree(bloomed)
focusing ──onLeave──▶ distracted         // distractStartAt,树苗低头(可逆)
distracted ──onReturn(缓冲内)──▶ focusing // distractionCount++
distracted ──graceRemaining≤0──▶ failed   // 树苗枯萎,写 FocusRecord(failed)
```

- **onLeave 触发源**:① 前台切到别的 App;② 结界窗口失焦;③ 锁屏/休眠。
- **onReturn**:前台切回本 App / 结界重新 becomeKey / 唤醒解锁。
- **计时铁律**:`remaining`、`actualFocused` 一律用 `Date()` 绝对时间戳相减,`Timer`(0.5s)只触发刷新、不做累加,以免后台/休眠漂移。`actualFocused = 已过时间 - 累计分心时长`。

## 四、数据模型(见 `Models/FocusModels.swift`)

- `FocusPhase`:idle / intent / breathing / focusing / distracted / completed / failed(运行期,不持久化)
- `FocusOutcome`:completed / failed
- `SaplingState`:growing / distracted / withered / bloomed
- `FocusSessionConfig`:intent / duration / graceSeconds(15) / showDigits
- `FocusRecord`(持久化):id / startedAt / intent / plannedDuration / actualFocused / outcome / distractionCount / distractedApps
- `GardenTree`(持久化):id / recordId / plantedDate / state
- **连胜(streak)** 由记录派生(连续「当日有 completed」的天数),不单独存字段,避免不一致。
- **持久化**:`FocusStore` → `focus.json`,统一走 `JSONCoders`(日期 ISO8601,见 ADR-0001)。

## 五、全屏护眼结界 `FocusOverlayWindow`

设计哲学:**结界不是监狱**。

- 无边框、`frame = 主屏 frame`、`NSHostingView` 承载 SwiftUI。
- 层级 `.normal`(不用 shielding 高层级):专注时 `NSApp.activate` + `orderFront` 占满;用户 Cmd-Tab 切走时别的 App 正常盖上(结界沉底,不物理锁死)。
- 进入设 `NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]`,退出恢复 → 干净护眼全屏。
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`。
- 进出 alpha 渐变;多屏 MVP 只在主屏(副屏变暗留后续)。

## 六、分心检测 `DistractionMonitor` + 召回

- 检测:`NSWorkspace` `didActivateApplicationNotification` 比较 bundleId;锁屏 `com.apple.screenIsLocked`(DistributedNotificationCenter)+ `NSWorkspace.willSleepNotification`。
- 召回(结界被切走看不到红光):`NSSound` 提示音 + `UserNotifications` 系统通知(首启请求权限,被拒退化为仅声音)。
- 记录切去的 App 名 → 后续「分心报告」。

## 七、树苗视图 `SaplingView`

- 输入 `growthProgress(0…1)` + `SaplingState`。
- MVP:SF Symbols(`leaf.fill`/`tree.fill`)分 4 阶段(种子→芽→枝→树)+ 缩放/透明动画;distracted 降饱和+下垂,withered 转褐+落叶,bloomed 开花+粒子。
- 视图接口稳定,后续可无痛替换为插画/Lottie。

## 八、关键技术难点 → 对策

| 难点 | 对策 |
|---|---|
| 结界被切走看不到提示 | 系统通知 + NSSound 召回 |
| 判断是否离开本 App | NSWorkspace 前台 bundleId 比较 |
| 计时后台/休眠漂移 | 全程 Date() 时间戳相减 |
| 通知权限被拒 | 退化为仅声音 |
| 护眼全屏不干净 | presentationOptions 隐藏 Dock/菜单栏 |

## 九、MVP 实现顺序

| 阶段 | 内容 | 验证点 |
|---|---|---|
| **F0** ✅ | FocusModels + FocusStore + FocusWidget 小苗卡片 | 桌面出现小苗卡片,显示今日时长/连胜 |
| **F1** | FocusSessionController + 全屏结界窗口 + IntentSetupView | 点小苗 → 设意图 → 进/出全屏顺畅 |
| **F2** | FocusSession 状态机 + 计时 + FocusSessionView + SaplingView | 完整计时,树苗随进度生长,到点收获 |
| **F3** | DistractionMonitor + 缓冲 + 召回 + 锁屏休眠 | 切走→红光/声音/通知,15s 内回来继续、超时枯萎 |
| **F4** | 结算 + 花园 + 连胜统计回写小苗 | 完成入花园、失败留枯枝,小苗数据真实更新 |

## 十、后续迭代

多人格(监工/毒舌/禅意)、白噪音、心流延长、分心报告热力图、多植物种类、成就系统、赌注/社交周报。
