import Foundation

public actor JSONStore<Value: Codable & Sendable> {
    private let url: URL
    private let defaultValue: Value
    private var cached: Value?

    public init(url: URL, defaultValue: Value) {
        self.url = url
        self.defaultValue = defaultValue
    }

    public func load() throws -> Value {
        if let cached { return cached }
        guard FileManager.default.fileExists(atPath: url.path) else {
            cached = defaultValue
            return defaultValue
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let value = try decoder.decode(Value.self, from: data)
        cached = value
        return value
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
        cached = value
    }

    public func update(_ transform: @Sendable (inout Value) -> Void) throws -> Value {
        var value = try load()
        transform(&value)
        try save(value)
        return value
    }
}

public actor ConfigStore {
    private let store: JSONStore<SightConfig>

    public init(url: URL = AppPaths.configURL) {
        self.store = JSONStore(url: url, defaultValue: SightConfig())
    }

    public func load() async throws -> SightConfig { try await store.load() }
    public func save(_ config: SightConfig) async throws { try await store.save(config) }
}

public actor RuleStore {
    private let store: JSONStore<[CategoryRule]>

    public init(url: URL = AppPaths.rulesURL) {
        self.store = JSONStore(url: url, defaultValue: [])
    }

    public func load() async throws -> [CategoryRule] { try await store.load() }
    public func save(_ rules: [CategoryRule]) async throws { try await store.save(rules) }
}
