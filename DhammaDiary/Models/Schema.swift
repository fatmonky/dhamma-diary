import Foundation
import SwiftData

/// The first stored schema. Later model changes add `SchemaV2` and a stage
/// in `DhammaDiaryMigrationPlan`, so existing data migrates.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Stone.self, JournalEntry.self]
    }
}

enum DhammaDiaryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum DhammaDiaryStore {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: schema,
            migrationPlan: DhammaDiaryMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
