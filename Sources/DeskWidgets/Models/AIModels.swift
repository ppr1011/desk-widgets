import Foundation

/// AI 助手人格。切换即切换 System Prompt 的语气模板。
/// 第一版四种人格文案齐全,后续可继续细化。
enum Persona: String, Codable, CaseIterable, Identifiable {
    case gentle
    case coach
    case roast
    case zen
    case sisterLin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gentle: return "温柔陪伴"
        case .coach: return "高效教练"
        case .roast: return "毒舌监工"
        case .zen: return "禅意"
        case .sisterLin: return "志玲御姐"
        }
    }

    /// 注入到 System Prompt 的语气说明。
    var toneInstruction: String {
        switch self {
        case .gentle:
            return "你的语气温柔、体贴、有共情，像一位关心同事的朋友，让人放松下来。"
        case .coach:
            return "你的语气积极、干练、目标导向，像一位高效教练，帮用户聚焦当下最重要的一件事。"
        case .roast:
            return "你的语气俏皮、略带毒舌吐槽，但本质是善意的督促，让用户会心一笑然后动起来。"
        case .zen:
            return "你的语气平和、简练、有禅意，提醒用户放慢呼吸、专注当下。"
        case .sisterLin:
            return """
            你的语气成熟优雅、温柔大方，像知性御姐林志玲一样轻声细语地关心用户。\
            措辞得体、从容不迫，偶尔用「嗯」「喔」「好哒」等温柔语气词，\
            既有大姐姐的包容与气场，又让人如沐春风、愿意听进去。
            """
        }
    }
}

/// 模型提供商类型。默认本地 Ollama。
enum LLMProviderKind: String, Codable, CaseIterable, Identifiable {
    case ollama
    case openAICompatible

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "本地 Ollama"
        case .openAICompatible: return "云端 (OpenAI 兼容)"
        }
    }
}

/// 气泡弹出位置。
enum BubbleAnchor: String, Codable, CaseIterable, Identifiable {
    case nearWidget
    case menuBar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nearWidget: return "组件旁"
        case .menuBar: return "顶部菜单栏"
        }
    }
}

/// 触发场景,决定提示的侧重点与气泡图标。
enum TriggerScene: String, Codable {
    case scheduled
    case longSitting
    case idle
    case highLoad
    case manual
    case conversation

    /// 注入 Prompt 的场景提示,引导内容方向。
    var hint: String {
        switch self {
        case .scheduled: return "这是一次定时的日常关心。"
        case .longSitting: return "用户已经连续工作很久没有起身，请温和提醒适当休息、活动身体、补充水分。"
        case .idle: return "用户似乎发呆走神了一会儿，可以轻轻拉回注意力。"
        case .highLoad: return "电脑负载偏高，用户可能正忙于处理任务，注意不要过度打扰。"
        case .manual: return "用户主动请你关心一下。"
        case .conversation: return ""
        }
    }

    /// 气泡左上角图标 (SF Symbol)。
    var symbolName: String {
        switch self {
        case .scheduled: return "bell.fill"
        case .longSitting: return "figure.walk"
        case .idle: return "cloud.fill"
        case .highLoad: return "cpu"
        case .manual: return "hand.wave.fill"
        case .conversation: return "bubble.left.and.bubble.right.fill"
        }
    }
}

/// 一条对话消息 (运行期 + 可选持久化)。
struct ChatMessage: Codable, Equatable, Identifiable {
    enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    var id: UUID = UUID()
    let role: Role
    let content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

/// 采集到的工作上下文快照 (运行期,不持久化)。
/// 只填充「已启用且可得」的信号,渲染时自动跳过 nil。
struct AIContext {
    let scene: TriggerScene
    let now: Date

    var screenUsageMinutes: Int?
    var continuousActiveMinutes: Int?
    var idleMinutes: Int?

    var cpuPercent: Double?
    var memoryPercent: Double?
    var networkBusy: String?

    var todoTotal: Int?
    var todoPending: Int?
    var pendingTodos: [String] = []

    var noteSummaries: [String] = []

    /// 渲染为中文上下文文本块,喂给 LLM。
    func render() -> String {
        var lines: [String] = []
        lines.append("当前时间：\(Self.timeString(now))（\(Self.timeOfDay(now))）")

        if let usage = screenUsageMinutes {
            lines.append("今日屏幕使用：约 \(Self.minutesText(usage))")
        }
        if let active = continuousActiveMinutes, active > 0 {
            lines.append("已连续工作：约 \(Self.minutesText(active)) 未离开")
        }
        if let idle = idleMinutes, idle >= 3 {
            lines.append("最近约 \(idle) 分钟没有键鼠操作（可能在发呆/离开）")
        }
        if let cpu = cpuPercent {
            lines.append("CPU 使用率：\(Int(cpu.rounded()))%")
        }
        if let mem = memoryPercent {
            lines.append("内存使用率：\(Int(mem.rounded()))%")
        }
        if let net = networkBusy {
            lines.append("网络状态：\(net)")
        }
        if let total = todoTotal {
            let pending = todoPending ?? 0
            lines.append("待办：共 \(total) 项，未完成 \(pending) 项")
            if !pendingTodos.isEmpty {
                let list = pendingTodos.prefix(5).map { "「\($0)」" }.joined(separator: "、")
                lines.append("未完成事项：\(list)")
            }
        }
        if !noteSummaries.isEmpty {
            let notes = noteSummaries.prefix(3).joined(separator: " | ")
            lines.append("便签摘要：\(notes)")
        }

        if !scene.hint.isEmpty {
            lines.append("场景：\(scene.hint)")
        }
        return lines.joined(separator: "\n")
    }

    private static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private static func timeOfDay(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<9: return "清晨"
        case 9..<12: return "上午"
        case 12..<14: return "中午"
        case 14..<18: return "下午"
        case 18..<23: return "晚上"
        default: return "深夜"
        }
    }

    private static func minutesText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分钟"
    }
}

/// AI 助手全局设置,持久化到 ai-settings.json (API Key 除外,存 Keychain)。
struct AISettings: Codable, Equatable {
    var providerKind: LLMProviderKind = .ollama
    var ollamaBaseURL: String = "http://localhost:11434"
    var ollamaModel: String = "qwen3.5:4b"
    var cloudBaseURL: String = "https://api.openai.com/v1"
    var cloudModel: String = "gpt-4o-mini"

    var scheduleTimes: [String] = ["11:00", "15:30", "19:00"]
    var quietStart: String = "22:00"
    var quietEnd: String = "08:00"

    var persona: Persona = .gentle
    var dailyLimit: Int = 8
    var bubbleAnchor: BubbleAnchor = .nearWidget

    var useTodos: Bool = true
    var useNotes: Bool = true
    var useSystemMetrics: Bool = true
    var useActivity: Bool = true

    var eventTriggersEnabled: Bool = true
    var sittingMinutesThreshold: Int = 90

    init() {}

    /// 容错解码:缺失字段回退默认值,便于后续平滑增字段。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AISettings()
        providerKind = try c.decodeIfPresent(LLMProviderKind.self, forKey: .providerKind) ?? d.providerKind
        ollamaBaseURL = try c.decodeIfPresent(String.self, forKey: .ollamaBaseURL) ?? d.ollamaBaseURL
        ollamaModel = try c.decodeIfPresent(String.self, forKey: .ollamaModel) ?? d.ollamaModel
        cloudBaseURL = try c.decodeIfPresent(String.self, forKey: .cloudBaseURL) ?? d.cloudBaseURL
        cloudModel = try c.decodeIfPresent(String.self, forKey: .cloudModel) ?? d.cloudModel
        scheduleTimes = try c.decodeIfPresent([String].self, forKey: .scheduleTimes) ?? d.scheduleTimes
        quietStart = try c.decodeIfPresent(String.self, forKey: .quietStart) ?? d.quietStart
        quietEnd = try c.decodeIfPresent(String.self, forKey: .quietEnd) ?? d.quietEnd
        persona = try c.decodeIfPresent(Persona.self, forKey: .persona) ?? d.persona
        dailyLimit = try c.decodeIfPresent(Int.self, forKey: .dailyLimit) ?? d.dailyLimit
        bubbleAnchor = try c.decodeIfPresent(BubbleAnchor.self, forKey: .bubbleAnchor) ?? d.bubbleAnchor
        useTodos = try c.decodeIfPresent(Bool.self, forKey: .useTodos) ?? d.useTodos
        useNotes = try c.decodeIfPresent(Bool.self, forKey: .useNotes) ?? d.useNotes
        useSystemMetrics = try c.decodeIfPresent(Bool.self, forKey: .useSystemMetrics) ?? d.useSystemMetrics
        useActivity = try c.decodeIfPresent(Bool.self, forKey: .useActivity) ?? d.useActivity
        eventTriggersEnabled = try c.decodeIfPresent(Bool.self, forKey: .eventTriggersEnabled) ?? d.eventTriggersEnabled
        sittingMinutesThreshold = try c.decodeIfPresent(Int.self, forKey: .sittingMinutesThreshold)
            ?? d.sittingMinutesThreshold
    }
}
