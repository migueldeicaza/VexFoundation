// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/version.ts` and `VexFlow.BUILD` from `src/vexflow.ts` (VexFlow 5.9.0).

import Foundation

/// Build metadata (upstream `VexFlow.BUILD`).
public struct VexBuildInfo: Sendable, Equatable {
    /// Version number.
    public let version: String
    /// Git commit ID that this library was built from.
    public let gitCommitID: String
    /// The date when this library was built.
    public let buildDate: String
    /// The name of the build (upstream: vexflow, vexflow-bravura, vexflow-core).
    public let info: String

    public init(version: String, gitCommitID: String, buildDate: String, info: String = "") {
        self.version = version
        self.gitCommitID = gitCommitID
        self.buildDate = buildDate
        self.info = info
    }

    /// Upstream `BUILD.VERSION`.
    public var VERSION: String { version }
    /// Upstream `BUILD.ID`.
    public var ID: String { gitCommitID }
    /// Upstream `BUILD.DATE`.
    public var DATE: String { buildDate }
    /// Upstream `BUILD.INFO`.
    public var INFO: String { info }
}

/// Build and version source for VexFoundation.
///
/// The values identify the upstream VexFlow release that this code ports.
public enum VexVersion {
    /// The upstream VexFlow version that this code ports.
    public static let version: String = "5.9.0"

    /// The upstream VexFlow commit of tag `5.9.0`.
    public static let gitCommitID: String = "136e78e2ae8619bb275cc42d91fdd39b8767526f"

    /// The date of the upstream VexFlow `5.9.0` commit.
    public static let buildDate: String = "2026-11-21T20:30:15-05:00"

    /// The build name.
    public static let info: String = "vexfoundation"

    /// Aggregated build metadata.
    public static let build = VexBuildInfo(
        version: version,
        gitCommitID: gitCommitID,
        buildDate: buildDate,
        info: info
    )
}

/// Upstream `version.ts` constants (`VERSION`, `ID`, `DATE`).
public enum Version {
    public static let VERSION: String = VexVersion.version
    public static let ID: String = VexVersion.gitCommitID
    public static let DATE: String = VexVersion.buildDate
}
