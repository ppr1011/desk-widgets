import Foundation

/// LLM 调用错误。
enum LLMError: Error, LocalizedError {
    case invalidURL
    case notReachable
    case http(Int, String)
    case emptyResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "服务地址无效"
        case .notReachable: return "无法连接到模型服务"
        case .http(let code, let body): return "服务返回错误 \(code)：\(body)"
        case .emptyResponse: return "模型返回为空"
        case .decoding: return "无法解析模型响应"
        }
    }
}

/// 模型提供商统一契约。屏蔽不同后端差异。
protocol LLMProvider {
    func chat(messages: [ChatMessage], model: String) async throws -> String
}

/// 线路消息(与后端 JSON 对齐)。
struct WireMessage: Codable {
    let role: String
    let content: String
}

extension Array where Element == ChatMessage {
    var wire: [WireMessage] {
        map { WireMessage(role: $0.role.rawValue, content: $0.content) }
    }
}

/// 模型输出清洗工具。
enum LLMText {
    /// 剥离思考模型可能内嵌的 <think>…</think> 段落,并去除首尾空白。
    static func stripThinking(_ text: String) -> String {
        var result = text
        while let start = result.range(of: "<think>"),
              let end = result.range(of: "</think>") {
            let removeUpper = max(start.upperBound, end.upperBound)
            result.removeSubrange(start.lowerBound..<removeUpper)
        }
        result = result.replacingOccurrences(of: "<think>", with: "")
        result = result.replacingOccurrences(of: "</think>", with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
