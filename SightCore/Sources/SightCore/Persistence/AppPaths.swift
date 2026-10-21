import Foundation

public enum AppPaths {
    public static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Sight", isDirectory: true)
    }

    public static var configURL: URL { applicationSupport.appendingPathComponent("config.json") }
    public static var rulesURL: URL { applicationSupport.appendingPathComponent("rules.json") }
    public static var journalURL: URL { applicationSupport.appendingPathComponent("journal.jsonl") }
    public static var modelsDirectory: URL { applicationSupport.appendingPathComponent("Models", isDirectory: true) }
    public static var modelDirectory: URL { modelsDirectory.appendingPathComponent("EmbeddingGemma2", isDirectory: true) }

    public static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
}
