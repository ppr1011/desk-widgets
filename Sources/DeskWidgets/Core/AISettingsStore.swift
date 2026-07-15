import Foundation
import Combine

/// AI 助手全局设置存储 (单例)。
/// settings 变更自动落盘 ai-settings.json;API Key 走 Keychain。
final class AISettingsStore: ObservableObject {
    static let shared = AISettingsStore()

    @Published var settings: AISettings {
        didSet { save() }
    }

    private let fileURL: URL
    private let apiKeyAccount = "cloudApiKey"

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeskWidgets", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("ai-settings.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONCoders.makeDecoder().decode(AISettings.self, from: data) {
            settings = decoded
        } else {
            settings = AISettings()
        }
    }

    /// 云端 API Key(仅在 Keychain 中,不进 JSON)。
    var apiKey: String {
        get { KeychainStore.shared.get(apiKeyAccount) ?? "" }
        set { KeychainStore.shared.set(newValue, for: apiKeyAccount) }
    }

    private func save() {
        guard let data = try? JSONCoders.makeEncoder().encode(settings) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
