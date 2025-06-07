//
//  MariaDB_SwfitDataStore.swift
//  MariaDB_SwiftDataConnector
//

import Foundation
import SwiftData

internal import SwiftDataSQL_MariaDB // Make sure this library is compatible

public final class MariaDB_SwiftDataStore: DataStore {
    
    public var identifier: String
    public var schema: Schema
    public var configuration: MariaDB_DataStoreConfiguration
    
    public init(_ configuration: MariaDB_DataStoreConfiguration, migrationPlan: (any SchemaMigrationPlan.Type)?) throws {
        schema = configuration.schema ?? Schema()
        identifier = "Hola caracola"
        self.configuration = configuration
        self.identifier = UUID().uuidString
    }
    
    public typealias Configuration = MariaDB_DataStoreConfiguration

    private func get_mariadb_data_as_array<T: PersistentModel>(for type: T.Type) throws -> [[String: Any]] {
        guard let maria_config = configuration.getMariaConfiguration() else {
            print("Cannot access MariaDB configuration")
            return []
        }
        
        let database = SwiftDataSQL_MariaDB.Database(configuration: maria_config)
        let query = "SELECT * FROM \(String(describing: type))"
        print("Selecting all records from \(String(describing: type))")
        
        let sql_data: [[String: Any]] = try database.fetchQueryResultsAsDictionaries(query, bindings: [])
        return sql_data
    }
    
    public func fetch<T: PersistentModel>(_ request: DataStoreFetchRequest<T>) throws -> DataStoreFetchResult<T, DefaultSnapshot> {
        let objs = try get_mariadb_data_as_array(for: T.self)
        var snapshots = [DefaultSnapshot]()
        
        try objs.forEach { obj in
            let decoder = MariaDB_Decoder(data: obj, storeIdentifier: self.identifier, targetIdentifier: String(describing: T.self))
            let ob = try DefaultSnapshot(from: decoder)
            snapshots.append(ob)
        }
        
        return DataStoreFetchResult(descriptor: request.descriptor, fetchedSnapshots: snapshots)
    }

    private func loadFromSQL<T: PersistentModel>(for type: T.Type) throws -> [T] {
        guard let maria_config = configuration.getMariaConfiguration() else {
            print("Cannot access MariaDB configuration")
            return []
        }

        var snapshots = [DefaultSnapshot]()
        let records: [T] = []
        let database = SwiftDataSQL_MariaDB.Database(configuration: maria_config)
        let query = "SELECT * FROM \(String(describing: type))"
        
        do {
            print("Selecting all records from \(String(describing: type))")
            let sql_data: [[String: Any]] = try database.fetchQueryResultsAsDictionaries(query, bindings: [])
            
            for sql_entry in sql_data {
                let decoder = MariaDB_Decoder(data: sql_entry, storeIdentifier: self.identifier, targetIdentifier: String(describing: T.self))
                snapshots.append(try DefaultSnapshot(from: decoder))
            }
        } catch {
            print("SQL ERROR:\(error)\nEngine status\n\n")
        }
        
        return records // placeholder
    }

    public func save(_ request: DataStoreSaveChangesRequest<DefaultSnapshot>) throws -> DataStoreSaveChangesResult<DefaultSnapshot> {
        guard let maria_config = configuration.getMariaConfiguration() else {
            print("Cannot access MariaDB configuration")
            return DataStoreSaveChangesResult(for: self.identifier, remappedIdentifiers: [:])
        }

        let database = SwiftDataSQL_MariaDB.Database(configuration: maria_config)
        var serializedRegistros = [String: [String: Any]]()
        let remappedIdentifiers = [PersistentIdentifier: PersistentIdentifier]()
        var insertedSnapshots = [DefaultSnapshot]()
        var updatedSnapshots = [DefaultSnapshot]()
        var deletedIdentifiers = [PersistentIdentifier]()
        var snapshotMap = [PersistentIdentifier: Snapshot]()
        var snapshotsByIdentifier = [PersistentIdentifier: DefaultSnapshot]()
        
        for snapshot in request.inserted {
            insertedSnapshots.append(snapshot)
            snapshotsByIdentifier[snapshot.persistentIdentifier] = snapshot
            
            let cmd = try create_insert_cmd(data: snapshot)
            if let cmd = cmd {
                do {
                    print("Inserting\n\(cmd)")
                    try database.sql(cmd)
                } catch {
                    print("SQL ERROR:\(error)\nEngine status\n\n")
                }
            }
        }

        // Process updates
        for snapshot in request.updated {
            updatedSnapshots.append(snapshot)
            snapshotMap[snapshot.persistentIdentifier] = snapshot

            let encoder = SQLSnapshotEncoder(storeIdentifier: self.identifier)
            try snapshot.encode(to: encoder)
            var updatedRegistro = encoder.storage
            
            guard let updatedRegistroID = updatedRegistro["id"] as? String else {
                fatalError("Cannot find identifier for record: \(updatedRegistro)")
            }

            let cmd = encoder.buildUpdateSQL(tableName: snapshot.persistentIdentifier.entityName, column: "id", value: updatedRegistroID)
            if let cmd = cmd {
                do {
                    print("Updating\n\(cmd)")
                    try database.sql(cmd)
                } catch {
                    print("SQL ERROR:\(error)\nEngine status\n\n")
                }
            }

            for recipeID in serializedRegistros.keys {
                if recipeID == updatedRegistroID {
                    serializedRegistros[recipeID] = updatedRegistro as? [String: Any]
                }
            }
        }

        for snapshot in request.deleted {
            deletedIdentifiers.append(snapshot.persistentIdentifier)
            
            let encoder = SQLSnapshotEncoder(storeIdentifier: self.identifier)
            try snapshot.encode(to: encoder)
            var deletedRegistro = encoder.storage
            
            guard let deletedRegistroID = deletedRegistro["id"] as? String else {
                fatalError("Cannot find record with id: \(deletedRegistro)")
            }

            deletedRegistro["id"] = deletedRegistroID
            let cmd = encoder.buildDeleteSQL(tableName: snapshot.persistentIdentifier.entityName, column: "id", value: deletedRegistroID)
            if let cmd = cmd {
                do {
                    print("Deleting\n\(cmd)")
                    try database.sql(cmd)
                } catch {
                    print("SQL ERROR:\(error)\nEngine status\n\n")
                }
            }

            for recipeID in serializedRegistros.keys {
                if recipeID == deletedRegistroID {
                    serializedRegistros[recipeID] = nil
                }
            }
        }

        /*
        do {
            let recipes = serializedRegistros.values.map({ $0 })
            let jsonData = try JSONSerialization.data(withJSONObject: recipes)
            try jsonData.write(to: configuration.fileURL)
        } catch let error {
            print("\(self) save failed with error: \(error)")
            throw error
        }
        */
        
        return DataStoreSaveChangesResult(for: self.identifier,
                                          remappedIdentifiers: remappedIdentifiers)
    }

    private func create_insert_cmd(data: DefaultSnapshot) throws -> String? {
        let encoder = SQLSnapshotEncoder(storeIdentifier: self.identifier)
        do {
            _ = try data.encode(to: encoder)
        } catch {
            print(error)
            return ""
        }
        
        let str = encoder.buildInsertSQL(tableName: data.persistentIdentifier.entityName)
        return str
    }

    public func fetchIdentifiers<T: PersistentModel>(_ request: DataStoreFetchRequest<T>) throws -> [PersistentIdentifier] {
        return []
    }
}
