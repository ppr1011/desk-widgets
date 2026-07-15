import Foundation

/// 本地 Ollama 提供商(默认)。调用 POST /api/chat,非流式。
struct OllamaProvider: LLMProvider {
    let baseURL: String

    private struct RequestBody: Encodable {
        let model: String
        let messages: [WireMessage]
        let stream: Bool
        /// 关闭思考模型的推理过程,避免气泡响应极慢(思考模型会输出大量 reasoning)。
        let think: Bool
        let options: Options
        struct Options: Encodable { let temperature: Double }
    }

    private struct ResponseBody: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message?
    }

    func chat(messages: [ChatMessage], model: String) async throws -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "\(trimmed)/api/chat") else { throw LLMError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = RequestBody(
            model: model,
            messages: messages.wire,
            stream: false,
            think: false,
            options: .init(temperature: 0.85)
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
        let raw = decoded.message?.content ?? ""
        let content = LLMText.stripThinking(raw)
        guard !content.isEmpty else { throw LLMError.emptyResponse }
        return content
    }
}
