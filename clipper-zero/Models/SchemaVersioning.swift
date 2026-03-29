import SwiftData

// TODO: Freeze model definitions inside SchemaV1 before adding SchemaV2.
// Currently SchemaV1.models references live types, so any property changes
// will silently alter the v1 snapshot. Before creating a new schema version,
// duplicate each model class inside the enum to lock the v1 shape in place.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        // SnippetItem excluded — its schema is managed by CloudKit.
        [ClipItem.self, ClipCollection.self, ExcludedApp.self]
    }
}

enum ClipperZeroMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
