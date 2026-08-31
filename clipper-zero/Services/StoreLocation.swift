import Foundation

/// Filesystem locations of the SwiftData stores.
///
/// `ModelConfiguration(_ name:)` derives its URL as
/// `Application Support/<name>.store`; these helpers mirror that so the
/// same files can be probed and quarantined without opening a container.
enum StoreLocation {
    static let localName = "ClipperZero"
    static let cloudName = "ClipperZeroSnippets"

    static var local: URL { url(for: localName) }
    static var cloud: URL { url(for: cloudName) }

    static func url(for name: String) -> URL {
        URL.applicationSupportDirectory.appending(path: "\(name).store")
    }

    static func exists(_ storeURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false))
    }

    /// Every file SwiftData keeps for one store: the SQLite file, its
    /// journal sidecars, and the `.<name>_SUPPORT` directory holding
    /// `.externalStorage` blobs.
    static func companions(of storeURL: URL) -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let name = storeURL.deletingPathExtension().lastPathComponent
        return [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal"),
            directory.appending(path: ".\(name)_SUPPORT"),
        ]
    }

    /// Moves a store and its sidecars aside so a fresh one can be created.
    ///
    /// Nothing is deleted — the files are renamed with a timestamp suffix so a
    /// corrupted store stays recoverable. Returns the destination of the main
    /// store file, or nil if there was nothing to move.
    @discardableResult
    static func quarantine(_ storeURL: URL) -> URL? {
        guard exists(storeURL) else { return nil }

        let stamp = ISO8601DateFormatter.quarantineStamp.string(from: Date())
        var movedStore: URL?

        for source in companions(of: storeURL) {
            guard FileManager.default.fileExists(atPath: source.path(percentEncoded: false)) else { continue }

            let destination = source.deletingLastPathComponent()
                .appending(path: "\(source.lastPathComponent).quarantined-\(stamp)")
            do {
                try FileManager.default.moveItem(at: source, to: destination)
                if source == storeURL { movedStore = destination }
            } catch {
                NSLog("ClipperZero: could not quarantine \(source.lastPathComponent): \(error)")
            }
        }

        return movedStore
    }
}

private extension ISO8601DateFormatter {
    /// Colons are legal in HFS+/APFS filenames but display as `/` in Finder,
    /// so keep the stamp to digits, dashes and a `T`.
    static let quarantineStamp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withDashSeparatorInDate]
        return formatter
    }()
}
