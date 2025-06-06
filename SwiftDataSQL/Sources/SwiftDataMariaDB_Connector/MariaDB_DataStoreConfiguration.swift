import Foundation
import SwiftData
import SwiftUI
internal import SwiftDataSQL_MariaDB

public enum MariaDB_DataStoreConfigurationError : Error, LocalizedError {
    case ImposibleConnectar(String)
    case ImposibleObtenerBaseDeDatos(String)
    case BaseDeDatosInexistente(String)
    case TablaInvalida(String)
    case EstructuraNoValida(String)
}

public final class MariaDB_DataStoreConfiguration : DataStoreConfiguration, Hashable {

    public init(schemas: Schema, db_host: String, db_user: String, db_password: String, db_name: String, db_port: UInt32) throws {
        self.name = "MariaDB_DataStoreConfiguration"
        self.db_host = db_host
        self.db_user = db_user
        self.db_password = db_password
        self.db_name = db_name
        self.db_port = db_port
        SQL_Connection = MySQL() // Create an instance of MySQL to work with
        let connected = SQL_Connection!.connect(host: db_host, user: db_user, password: db_password, port: db_port)
        
        guard connected else {
            // verify we connected successfully
            print(SQL_Connection!.errorMessage())
            SQL_Connection = nil;
            throw MariaDB_DataStoreConfigurationError.ImposibleConnectar("No fue posible conectarse a la base de datos. Error:\(SQL_Connection!.errorMessage())")
        }
        
        SQL_Configuration = MySQLDatabaseConfiguration(connection: SQL_Connection!)
        guard SQL_Connection!.selectDatabase(named: self.db_name) == true else {
            throw MariaDB_DataStoreConfigurationError.BaseDeDatosInexistente("No fue posible seleccionar BBDD")
        }
        let sql_tables =  SQL_Connection!.listTables()
        var num_tables_pendientes : Int = schemas.entities.count
        for sql_table in sql_tables {
            print("Tabla: \(sql_table)")
            let entity = schemas.entitiesByName[sql_table]
            guard entity != nil else {
                print("La clase \(sql_table) no implementa PersistentModel")
                throw MariaDB_DataStoreConfigurationError.TablaInvalida(sql_table)
                
            }
            num_tables_pendientes -= 1
        }
    
        guard num_tables_pendientes == 0 else {
            let message = "El modelo Swift declara \(schemas.entities.count) tablas, pero la base de datos tiene que declarar \(num_tables_pendientes) modelos mas"
            print (message)
            throw MariaDB_DataStoreConfigurationError.EstructuraNoValida(message)
        }
        schema = schemas
        
    }
    
    public var schema: Schema?
    
    public var name: String = "MariaDB Configuration"
    
    private var db_host: String
    private var db_user: String
    private var db_password: String
    private var db_name: String
    private var db_port: UInt32
    private var SQL_Connection : MySQL? = nil
    private var SQL_Configuration : MySQLDatabaseConfiguration? = nil
    
    public static func == (lhs: MariaDB_DataStoreConfiguration, rhs: MariaDB_DataStoreConfiguration) -> Bool {
        return lhs.name == rhs.name
    }
    internal func getMariaConfiguration() -> MySQLDatabaseConfiguration? {
        return SQL_Configuration
    }
    public typealias Store = MariaDB_SwiftDataStore
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(schema)
    }
}
