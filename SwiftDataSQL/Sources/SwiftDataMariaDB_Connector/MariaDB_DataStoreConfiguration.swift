import Foundation
import SwiftData
import SwiftUI
internal import SwiftDataSQL_MariaDB

// MARK: - MariaDB Data Store Configuration Errors

public enum MariaDB_DataStoreConfigurationError: Error, LocalizedError {
    case ImposibleConnectar(String)               // Unable to connect
    case ImposibleObtenerBaseDeDatos(String)      // Unable to get database
    case BaseDeDatosInexistente(String)           // Database does not exist
    case TablaInvalida(String)                    // Invalid table
    case EstructuraNoValida(String)               // Invalid structure
}

// MARK: - MariaDB Data Store Configuration

public final class MariaDB_DataStoreConfiguration: DataStoreConfiguration, Hashable {

    // MARK: - Initializer

    public init(
        schemas: Schema,
        db_host: String,
        db_user: String,
        db_password: String,
        db_name: String,
        db_port: UInt32
    ) throws {
        self.name = "MariaDB_DataStoreConfiguration"
        self.db_host = db_host
        self.db_user = db_user
        self.db_password = db_password
        self.db_name = db_name
        self.db_port = db_port

        SQL_Connection = MySQL() // Create an instance of MySQL to work with
        let connected = SQL_Connection!.connect(
            host: db_host,
            user: db_user,
            password: db_password,
            port: db_port
        )

        guard connected else {
            // Verify that we connected successfully
            print(SQL_Connection!.errorMessage())
            SQL_Connection = nil
            throw MariaDB_DataStoreConfigurationError.ImposibleConnectar(
                "Unable to connect to the database. Error: \(SQL_Connection!.errorMessage())"
            )
        }

        SQL_Configuration = MySQLDatabaseConfiguration(connection: SQL_Connection!)

        guard SQL_Connection!.selectDatabase(named: self.db_name) == true else {
            throw MariaDB_DataStoreConfigurationError.BaseDeDatosInexistente(
                "Unable to select database."
            )
        }

        let sql_tables = SQL_Connection!.listTables()
        var num_tables_pendientes: Int = schemas.entities.count

        for sql_table in sql_tables {
            print("Table: \(sql_table)")
            let entity = schemas.entitiesByName[sql_table]

            guard entity != nil else {
                print("Class \(sql_table) does not implement PersistentModel")
                throw MariaDB_DataStoreConfigurationError.TablaInvalida(sql_table)
            }

            num_tables_pendientes -= 1
        }

        guard num_tables_pendientes == 0 else {
            let message = """
            The Swift model declares \(schemas.entities.count) tables, \
            but the database is missing \(num_tables_pendientes) model(s).
            """
            print(message)
            throw MariaDB_DataStoreConfigurationError.EstructuraNoValida(message)
        }

        schema = schemas
    }

    // MARK: - Properties

    public var schema: Schema?
    public var name: String = "MariaDB Configuration"

    private var db_host: String
    private var db_user: String
    private var db_password: String
    private var db_name: String
    private var db_port: UInt32

    private var SQL_Connection: MySQL? = nil
    private var SQL_Configuration: MySQLDatabaseConfiguration? = nil

    // MARK: - Equatable

    public static func == (lhs: MariaDB_DataStoreConfiguration, rhs: MariaDB_DataStoreConfiguration) -> Bool {
        return lhs.name == rhs.name
    }

    // MARK: - Internal

    internal func getMariaConfiguration() -> MySQLDatabaseConfiguration? {
        return SQL_Configuration
    }

    // MARK: - Store Typealias

    public typealias Store = MariaDB_SwiftDataStore

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(schema)
    }
}
