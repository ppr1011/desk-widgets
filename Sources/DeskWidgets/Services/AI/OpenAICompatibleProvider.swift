import Foundation

/// 云端 OpenAI 兼容提供商。覆盖 OpenAI / DeepSeek / 通义 / Kimi 等。
/// 调用 POST {baseURL}/chat/completions。
struct OpenAICompatibleProvider: LLMProvider {
    let baseURL: String
    let apiKey: String

    private struct RequestBody: Encodable {
        let model: String
        let messages: [WireMessage]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }

    func chat(messages: [ChatMessage], model: String) async throws -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/chat/completions") else { throw LLMError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body = RequestBody(
            model: model,
            messages: messages.wire,
            temperature: 0.85,
            max_tokens: 200
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.notReachable
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(http.statusCode, text)
        }

        guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            throw LLMError.decoding
        }
        let raw = decoded.choices.first?.message.content ?? ""
        let content = LLMText.stripThinking(raw)
        guard !content.isEmpty else { throw LLMError.emptyResponse }
        return content
    }
}
