//  Copyright © 2019 650 Industries. All rights reserved.

import Foundation
import EXManifests

func assertType<T>(value: Any, description: String) -> T {
  if !(value is T) {
    let exception = NSException(
      name: NSExceptionName.internalInconsistencyException,
      reason: description,
      userInfo: [:]
    )
    exception.raise()
  }

  // exception above will preempt force_cast
  // swiftlint:disable:next force_cast
  return value as! T
}

public extension Optional {
  func require(_ desc: String) -> Wrapped {
    if self == nil {
      let exception = NSException(
        name: NSExceptionName.internalInconsistencyException,
        reason: desc,
        userInfo: [:]
      )
      exception.raise()
    }

    // exception above will preempt force_unwrapping
    // swiftlint:disable:next force_unwrapping
    return self!
  }
}

/**
 * Download status that indicates whether or under what conditions an
 * update is able to be launched.
 *
 * It's important that the integer value of each status stays constant across
 * all versions of this library since they are stored in SQLite on user devices.
 */
@objc
public enum EXUpdatesUpdateStatus: Int {
  case Status0_Unused = 0
  /**
   * The update has been fully downloaded and is ready to launch.
   */
  case StatusReady = 1
  case Status2_Unused = 2
  /**
   * The update manifest has been download from the server but not all
   * assets have finished downloading successfully.
   */
  case StatusPending = 3
  case Status4_Unused = 4
  /**
   * The update has been partially loaded (copied) from its location
   * embedded in the app bundle, but not all assets have been copied
   * successfully. The update may be able to be launched directly from
   * its embedded location unless a new binary version with a new
   * embedded update has been installed.
   */
  case StatusEmbedded = 5
  /**
   * The update manifest has been downloaded and indicates that the
   * update is being served from a developer tool. It can be launched by a
   * host application that can run a development bundle.
   */
  case StatusDevelopment = 6
}

@objc
public enum EXUpdatesUpdateError: Int, Error {
  case invalidExpoProtocolVersion
}

@objcMembers
public class EXUpdatesUpdate: NSObject {
  public let updateId: UUID
  public let scopeKey: String
  public let commitTime: Date
  public let runtimeVersion: String
  public let keep: Bool
  public let isDevelopmentMode: Bool
  private let assetsFromManifest: [EXUpdatesAsset]?

  public internal(set) var serverDefinedHeaders: [String: Any]?
  public internal(set) var manifestFilters: [String: Any]?

  public let manifest: EXManifestsManifest

  public var status: EXUpdatesUpdateStatus
  public var lastAccessed: Date
  public var successfulLaunchCount: Int
  public var failedLaunchCount: Int

  private let config: EXUpdatesConfig
  private let database: EXUpdatesDatabase?

  public init(
    manifest: EXManifestsManifest,
    config: EXUpdatesConfig,
    database: EXUpdatesDatabase?,
    updateId: UUID,
    scopeKey: String,
    commitTime: Date,
    runtimeVersion: String,
    keep: Bool,
    status: EXUpdatesUpdateStatus,
    isDevelopmentMode: Bool,
    assetsFromManifest: [EXUpdatesAsset]?
  ) {
    self.updateId = updateId
    self.commitTime = commitTime
    self.runtimeVersion = runtimeVersion
    self.keep = keep
    self.manifest = manifest
    self.config = config
    self.database = database
    self.scopeKey = scopeKey
    self.status = status
    self.assetsFromManifest = assetsFromManifest

    self.lastAccessed = Date()
    self.successfulLaunchCount = 0
    self.failedLaunchCount = 0
    self.isDevelopmentMode = isDevelopmentMode
  }

  public static func update(
    withManifest: [String: Any],
    manifestHeaders: EXUpdatesManifestHeaders,
    extensions: [String: Any],
    config: EXUpdatesConfig,
    database: EXUpdatesDatabase
  ) throws -> EXUpdatesUpdate {
    let protocolVersion = manifestHeaders.protocolVersion
    switch protocolVersion {
    case nil:
      return EXUpdatesLegacyUpdate.update(
        withLegacyManifest: EXManifestsLegacyManifest(rawManifestJSON: withManifest),
        config: config,
        database: database
      )
    case "0":
      return EXUpdatesNewUpdate.update(
        withNewManifest: EXManifestsNewManifest(rawManifestJSON: withManifest),
        manifestHeaders: manifestHeaders,
        extensions: extensions,
        config: config,
        database: database
      )
    default:
      throw EXUpdatesUpdateError.invalidExpoProtocolVersion
    }
  }

  public static func update(
    withEmbeddedManifest: [String: Any],
    config: EXUpdatesConfig,
    database: EXUpdatesDatabase?
  ) -> EXUpdatesUpdate {
    if withEmbeddedManifest["releaseId"] != nil {
      return EXUpdatesLegacyUpdate.update(
        withLegacyManifest: EXManifestsLegacyManifest(rawManifestJSON: withEmbeddedManifest),
        config: config,
        database: database
      )
    } else {
      return EXUpdatesBareUpdate.update(
        withBareManifest: EXManifestsBareManifest(rawManifestJSON: withEmbeddedManifest),
        config: config,
        database: database
      )
    }
  }

  /**
   * Accessing this property may lazily load the assets from the database, if this update object
   * originated from the database.
   */
  public func assets() -> [EXUpdatesAsset]? {
    guard let assetsFromManifest = self.assetsFromManifest else {
      return self.assetsFromDatabase()
    }
    return assetsFromManifest
  }

  private func assetsFromDatabase() -> [EXUpdatesAsset]? {
    guard let database = self.database else {
      return nil
    }

    var assetsLocal: [EXUpdatesAsset] = []
    database.databaseQueue.sync {
      // The pattern is valid, so it'll never throw
      // swiftlint:disable:next force_try
      assetsLocal = try! database.assets(withUpdateId: self.updateId)
    }
    return assetsLocal
  }

  public func loggingId() -> String {
    self.updateId.uuidString.lowercased()
  }
}
