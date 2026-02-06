import Dependencies
import Foundation

public struct FileSystemClient: Sendable {
  public var fileExists: @Sendable (String) -> Bool
  public var isDirectory: @Sendable (String) -> Bool
  public var createDirectory: @Sendable (URL, Bool) throws -> Void
  public var contentsOfDirectory: @Sendable (URL) throws -> [URL]
  public var write: @Sendable (Data, URL) throws -> Void
  public var data: @Sendable (URL) throws -> Data

  public init(
    fileExists: @escaping @Sendable (String) -> Bool,
    isDirectory: @escaping @Sendable (String) -> Bool,
    createDirectory: @escaping @Sendable (URL, Bool) throws -> Void,
    contentsOfDirectory: @escaping @Sendable (URL) throws -> [URL],
    write: @escaping @Sendable (Data, URL) throws -> Void,
    data: @escaping @Sendable (URL) throws -> Data
  ) {
    self.fileExists = fileExists
    self.isDirectory = isDirectory
    self.createDirectory = createDirectory
    self.contentsOfDirectory = contentsOfDirectory
    self.write = write
    self.data = data
  }

  public static let live = FileSystemClient(
    fileExists: { FileManager.default.fileExists(atPath: $0) },
    isDirectory: { path in
      var isDirectory = ObjCBool(false)
      guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
        return false
      }
      return isDirectory.boolValue
    },
    createDirectory: { url, createIntermediates in
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: createIntermediates)
    },
    contentsOfDirectory: { url in
      try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
    },
    write: { data, url in
      try data.write(to: url)
    },
    data: { try Data(contentsOf: $0) }
  )
}

private enum FileSystemClientKey: DependencyKey {
  static var liveValue: FileSystemClient {
    .live
  }

  static var testValue: FileSystemClient {
    FileSystemClient(
      fileExists: { _ in
        testDependencyFailure("fileExists")
      },
      isDirectory: { _ in
        testDependencyFailure("isDirectory")
      },
      createDirectory: { _, _ in
        testDependencyFailure("createDirectory")
      },
      contentsOfDirectory: { _ in
        testDependencyFailure("contentsOfDirectory")
      },
      write: { _, _ in
        testDependencyFailure("write")
      },
      data: { _ in
        testDependencyFailure("data")
      }
    )
  }
}

private func testDependencyFailure<T>(_ endpoint: StaticString) -> T {
  fatalError(
    """
    Unimplemented FileSystemClient.\(endpoint).
    Override `fileSystemClient` in this test using `.dependencies { ... }`.
    """
  )
}

public extension DependencyValues {
  var fileSystemClient: FileSystemClient {
    get { self[FileSystemClientKey.self] }
    set { self[FileSystemClientKey.self] = newValue }
  }
}
