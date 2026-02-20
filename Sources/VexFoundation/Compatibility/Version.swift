// VexFoundation - Lightweight compatibility metadata for VexFlow-style version/build access.

import Foundation

/// Build metadata exposed through compatibility surfaces.
public struct VexBuildInfo: Sendable, Equatable {
    public let version: String
    public let gitCommitID: String
    public let buildDate: String

    public init(version: String, gitCommitID: String, buildDate: String) {
        self.version = version
        self.gitCommitID = gitCommitID
        self.buildDate = buildDate
    }
}

/// Canonical build/version source for VexFoundation.
public enum VexVersion {
    private static func env(_ key: String, fallback: String) -> String {
        let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value, !value.isEmpty {
            return value
        }
        return fallback
    }

    /// Semantic version for this build. Override with `VEXFOUNDATION_VERSION` when packaging.
    public static let version: String = env("VEXFOUNDATION_VERSION", fallback: "development")

    /// Git commit id for this build. Override with `VEXFOUNDATION_GIT_COMMIT` when packaging.
    public static let gitCommitID: String = env("VEXFOUNDATION_GIT_COMMIT", fallback: "unknown")

    /// Build timestamp for this build. Override with `VEXFOUNDATION_BUILD_DATE` when packaging.
    public static let buildDate: String = env("VEXFOUNDATION_BUILD_DATE", fallback: "unknown")

    /// Aggregated build metadata.
    public static let build = VexBuildInfo(
        version: version,
        gitCommitID: gitCommitID,
        buildDate: buildDate
    )
}

/// VexFlow-like compatibility constants (`VERSION`, `ID`, `DATE`).
public enum Version {
    public static let VERSION: String = VexVersion.version
    public static let ID: String = VexVersion.gitCommitID
    public static let DATE: String = VexVersion.buildDate
}
