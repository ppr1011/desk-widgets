import Foundation

/// 项目统一的 JSON 编解码配置。所有本地持久化(WidgetStore / FocusStore …)
/// 都经过这里,确保行为一致、不再各写各的:
/// - 日期用 ISO8601:落盘的 json 里日期人类可读(便于调试),跨版本稳定
/// - 输出美化 + 键排序:文件 diff 友好
///
/// 类比 Java:相当于全局共享一个配置好的 ObjectMapper。
enum JSONCoders {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
