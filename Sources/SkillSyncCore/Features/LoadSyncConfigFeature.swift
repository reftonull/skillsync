import Dependencies
import Foundation
import TOMLDecoder

public struct LoadSyncConfigFeature {
    public struct Result: Equatable, Sendable {
        public var targets: [SyncTarget]
        public var observation: ObservationSettings

        public init(
            targets: [SyncTarget],
            observation: ObservationSettings = .default
        ) {
            self.targets = targets
            self.observation = observation
        }
    }

    @Dependency(\.pathClient) var pathClient
    @Dependency(\.fileSystemClient) var fileSystemClient

    public init() {}

    public func run() throws -> Result {
        let configPath = pathClient.skillsyncRoot().appendingPathComponent("config.toml")

        guard fileSystemClient.fileExists(configPath.path) else {
            return Result(targets: [], observation: .default)
        }

        let data = try fileSystemClient.data(configPath)
        guard let contents = String(data: data, encoding: .utf8) else {
            return Result(targets: [], observation: .default)
        }

        return Result(
            targets: Self.parseTargets(from: contents),
            observation: Self.parseObservationSettings(from: contents)
        )
    }

    // MARK: - TOML Decodable types

    private struct ConfigFile: Decodable {
        var targets: [TargetEntry]?
        var observation: ObservationSection?

        struct TargetEntry: Decodable {
            var id: String?
            var path: String?
            var source: String?
        }

        struct ObservationSection: Decodable {
            var mode: String?
        }
    }

    // MARK: - Parsing via TOMLDecoder

    static func parseTargets(from contents: String) -> [SyncTarget] {
        guard let config = try? TOMLDecoder().decode(ConfigFile.self, from: contents) else {
            return []
        }

        return (config.targets ?? []).compactMap { entry in
            guard
                let id = entry.id,
                let path = entry.path,
                let sourceRaw = entry.source,
                let source = SyncTarget.Source(rawValue: sourceRaw)
            else {
                return nil
            }
            return SyncTarget(id: id, path: path, source: source)
        }
    }

    static func parseObservationSettings(from contents: String) -> ObservationSettings {
        guard let config = try? TOMLDecoder().decode(ConfigFile.self, from: contents) else {
            return .default
        }

        let mode = config.observation?.mode
            .flatMap(ObservationMode.init(rawValue:))
            ?? ObservationSettings.default.mode

        return ObservationSettings(mode: mode)
    }
}
