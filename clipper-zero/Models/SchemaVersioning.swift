import SwiftData
import Foundation

// MARK: - Schema V1 (Frozen)
// These definitions lock the V1 shape so future property changes
// don't silently alter the v1 snapshot used during migration.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [V1ClipItem.self, V1ClipCollection.self, V1ExcludedApp.self]
    }

    @Model
    final class V1ClipItem {
        var id: UUID
        @Attribute(.externalStorage) var content: Data
        var contentType: ClipContentType
        var plainText: String?
        var sourceAppBundle: String?
        var sourceAppName: String?
        var createdAt: Date
        var isPinned: Bool
        @Attribute(.externalStorage) var previewData: Data?
        var collections: [V1ClipCollection]?

        init(content: Data, contentType: ClipContentType, plainText: String? = nil,
             sourceAppBundle: String? = nil, sourceAppName: String? = nil,
             isPinned: Bool = false, previewData: Data? = nil) {
            self.id = UUID()
            self.content = content
            self.contentType = contentType
            self.plainText = plainText
            self.sourceAppBundle = sourceAppBundle
            self.sourceAppName = sourceAppName
            self.createdAt = Date()
            self.isPinned = isPinned
            self.previewData = previewData
        }
    }

    @Model
    final class V1ClipCollection {
        var id: UUID
        var name: String
        var icon: String
        var createdAt: Date
        @Relationship(deleteRule: .nullify, inverse: \V1ClipItem.collections)
        var items: [V1ClipItem]?

        init(name: String, icon: String = "folder") {
            self.id = UUID()
            self.name = name
            self.icon = icon
            self.createdAt = Date()
            self.items = []
        }
    }

    @Model
    final class V1ExcludedApp {
        var id: UUID
        @Attribute(.unique) var bundleIdentifier: String
        var appName: String

        init(bundleIdentifier: String, appName: String) {
            self.id = UUID()
            self.bundleIdentifier = bundleIdentifier
            self.appName = appName
        }
    }
}

// MARK: - Schema V2 (Live Types)

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        // SnippetItem excluded — its schema is managed by CloudKit.
        [ClipItem.self, ClipCollection.self, ExcludedApp.self, SecureSnippetItem.self]
    }
}

// MARK: - Migration Plan

enum ClipperZeroMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    // Lightweight migration — all new fields have defaults.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
