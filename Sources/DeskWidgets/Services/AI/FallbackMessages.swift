import Foundation

/// 断网 / 无 Ollama / 模型报错时的本地兜底文案库,保证任何时候都有一句气泡。
enum FallbackMessages {
    static func random(for scene: TriggerScene) -> String {
        let pool = messages[scene] ?? messages[.scheduled]!
        return pool.randomElement() ?? "记得照顾好自己，工作再忙也要喝口水～"
    }

    private static let messages: [TriggerScene: [String]] = [
        .scheduled: [
            "先深呼吸一下，把最重要的一件事做好就够了。",
            "工作节奏还好吗？累了就停一分钟，起来走两步。",
            "别忘了喝口水，身体舒服了效率才会跟上来。",
            "挑一件最想推进的事，先专注 25 分钟试试。"
        ],
        .longSitting: [
            "已经坐了好一会儿啦，起来接杯水、活动下肩颈吧。",
            "久坐伤身，站起来伸个懒腰，一分钟就回来。",
            "眼睛也累了吧？远眺窗外 20 秒，放松一下。"
        ],
        .idle: [
            "走神了没关系，轻轻把注意力拉回来就好。",
            "发会儿呆挺好的，准备好了我们继续。",
            "要不先写下接下来要做的一小步？"
        ],
        .highLoad: [
            "看起来正忙，我就不多说啦，注意别太赶。",
            "任务有点重，记得给自己留个小喘息。"
        ],
        .manual: [
            "我在呢～有我陪着，慢慢来别着急。",
            "今天也辛苦啦，先照顾好自己再谈效率。",
            "想聊点什么，或者要我帮你理理待办？"
        ],
        .conversation: [
            "我暂时连不上模型，等下再问我吧～"
        ]
    ]
}
