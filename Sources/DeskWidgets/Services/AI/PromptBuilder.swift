import Foundation

/// 组装发给 LLM 的消息:System(人格 + 输出要求)+ User(上下文 + 指令)。
enum PromptBuilder {
    /// 生成一句气泡提示的 Prompt。
    static func buildReminder(context: AIContext, persona: Persona) -> [ChatMessage] {
        let system = """
        你是用户桌面上的 AI 办公助手，目标是缓解工作压力、提高效率、守护健康。
        \(persona.toneInstruction)
        输出要求：
        - 只用中文，输出 1~2 句话，总长不超过 40 个字。
        - 结合给定的工作情况，说一句贴心、自然、具体的话，可包含一个小建议。
        - 不要复述数据，不要客套开场白，不要加引号或前后缀，直接说这句话。
        - 不使用 emoji。
        """
        let user = """
        【当前工作情况】
        \(context.render())

        请据此对用户说一句话。
        """
        return [
            ChatMessage(role: .system, content: system),
            ChatMessage(role: .user, content: user)
        ]
    }

    /// 对话模式的 System Prompt(用户主动追问时)。
    static func conversationSystem(persona: Persona) -> ChatMessage {
        let content = """
        你是用户桌面上的 AI 办公助手，帮助他更高效、更健康地工作。
        \(persona.toneInstruction)
        回答简洁、务实，用中文，控制在 3 句话以内。
        """
        return ChatMessage(role: .system, content: content)
    }
}
