import Foundation
import SwiftData

final class SQLInsertBuilder {

    func buildInsertSQL(storeIdentifier:String, from snapshot: DefaultSnapshot, tableName: String) -> String? {
        let encoder = SQLSnapshotEncoder(storeIdentifier: storeIdentifier)
        do {
            // Intentamos codificar los valores del snapshot al encoder
            try snapshot.encode(to: encoder)
            return encoder.buildInsertSQL(tableName: tableName)
        } catch {
            print("Error encoding snapshot: \(error)")
            return nil
        }
    }
}

class SQLSnapshotEncoder: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey : Any]
    public var storage: [String: Any] = [:]
    let storeIdentifier: String
    
    init(storeIdentifier:String, codingPath: [CodingKey] = [], userInfo: [CodingUserInfoKey : Any] = [:]) {
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.storeIdentifier = storeIdentifier;
    }
    
    let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()
    
    
    func stringfyValue(_ value: Any) -> String {
        if value is NSNull {
            return "NULL" // O "nil", o "" según tu preferencia para valores nulos explícitos
        }
        
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional && mirror.children.isEmpty {
            return "NULL" // O "nil", o ""
        }
        
        if let stringValue = value as? String {
            let escapedString = stringValue.replacingOccurrences(of: "'", with: "")
            return "'\(escapedString)'"
        } else if let boolValue = value as? Bool {
            return boolValue ? "1" : "0" // Formato numérico para booleanos
        } else if let uuid = value as? UUID {
            return "'\(uuid.uuidString)'" // UUIDs como strings, entre comillas
        } else if let date = value as? Date {
            return "'\(iso8601DateFormatter.string(from: date))'" // Fecha en ISO8601, entre comillas
        } else if let url = value as? URL {
            return "'\(url.absoluteString)'" // URLs como strings, entre comillas
        }
        else if let intValue = value as? Int {
            return String(intValue)
        } else if let intValue = value as? Int64 {
            return String(intValue)
        } else if let intValue = value as? Int32 {
            return String(intValue)
        } else if let floatValue = value as? Float {
            return String(floatValue)
        } else if let doubleValue = value as? Double { // Añadido Double
            return String(doubleValue)
        } else if let numberValue = value as? NSNumber { // Captura otros NSNumber (ej. Decimal)
            if CFGetTypeID(numberValue) == CFBooleanGetTypeID() {
                return numberValue.boolValue ? "1" : "0"
            }
            return numberValue.stringValue
        }
        else {
            let stringRepresentation = String(describing: value)
            return stringRepresentation // Sin comillas por defecto para tipos desconocidos
        }
    }
    
    
    // Contenedor para almacenar las claves y los valores en SQL
    func buildInsertSQL(tableName: String) -> String? {
        
        guard !storage.isEmpty else { return nil }
        let columns = storage.keys.map { "`\($0)`" }.joined(separator: ", ")
        let values = storage.values
            .map { stringfyValue($0) }
            .joined(separator: ", ")
        return "INSERT INTO `\(tableName)` (\(columns)) VALUES (\(values));"
    }
    // Contenedor para almacenar las claves y los valores en SQL
    func buildUpdateSQL(tableName: String, column : String, value : String) -> String? {
        
        guard !storage.isEmpty else { return nil }
        guard let id = storage["id"] else { return nil }
        let setClause = storage
            .filter { $0.key != "id" }
            .map { "`\($0.key)` = \(stringfyValue($0.value))" }
            .joined(separator: ", ")

        let idValue = stringfyValue(id)

        return "UPDATE `\(tableName)` SET \(setClause) WHERE `ID` = \(idValue);"

    }
    
    
    
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let container = SQLSnapshotKeyedEncodingContainer<Key>(encoder: self, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return SQLSnapshotUnkeyedEncodingContainer(encoder: self, codingPath: codingPath)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return SQLSnapshotSingleValueEncodingContainer(encoder: self, codingPath: codingPath)
    }
    // Contenedor para almacenar las claves y los valores en SQL
    func buildDeleteSQL(tableName: String, column : String, value : String) -> String? {
        
        return "DELETE FROM `\(tableName)` WHERE \(column) = \(value);"
    }
    
}

struct SQLSnapshotKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K

    var codingPath: [CodingKey]
    private var encoder: SQLSnapshotEncoder // Reference to the main encoder

    init(encoder: SQLSnapshotEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    
    private func extraerTablaYUUID(from string: String) -> (tabla: String, id: UUID)? {
        // Dividir la cadena en dos partes usando el delimitador "/"
        let partes = string.split(separator: "/")
        
        // Comprobar que la cadena tiene al menos dos partes
        guard partes.count == 3 else { return nil }
        
        // Extraer la tabla (antes del UUID) y el UUID
        let tabla = String(partes[1]) // quitar "x-swiftdata:"
        let id = String(partes[2]).dropLast(1)
        let uuid = UUID(uuidString: String(partes[2].dropLast()))!

        return (tabla, uuid)
    }

    
    // Helper to convert values to SQL-compatible strings
    private func sqlString<T>(_ value: T) throws -> String {
        var ret_value: String = ""
        
        if let str = value as? String {
            // Usar comillas simples para valores string
            ret_value = "'\(str.replacingOccurrences(of: "'", with: "''"))'"
            
        } else if value is Int || value is Double || value is Float {
            ret_value = "\(value)"
            
        } else if let boolVal = value as? Bool {
            ret_value = boolVal ? "1" : "0"
            
        } else if let uuidVal = value as? UUID {
            ret_value = "'\(uuidVal.uuidString)'"
            print("\(uuidVal.uuidString)")

        } else if let relation = value as? SwiftData.PersistentIdentifier {
            let resultado = extraerTablaYUUID(from: String(describing: relation.id))
            //ret_value = "( SELECT id from '\(relation.entityName)' WHERE \(resultado!.tabla) = '\(resultado!.id)')"
            ret_value = resultado!.id.uuidString;
        } else if value is [SwiftData.PersistentIdentifier] {
            throw MariaEnconderException.DoNotSerialize("Is relation");
        }
        
        return ret_value
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        if (key.stringValue == "persistentIdentifier") {
            return ;
        }
        do {
            encoder.storage[key.stringValue] = try sqlString(value)
        }
        catch {
            
        }
    }

    mutating func encodeNil(forKey key: Key) throws {
        encoder.storage[key.stringValue] = nil as AnyObject?
    }

    mutating func nestedContainer<NK>(keyedBy keyType: NK.Type, forKey key: Key) -> KeyedEncodingContainer<NK> where NK : CodingKey {
        fatalError("Nested keyed containers not implemented for SQLSnapshotEncoder")
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        fatalError("Nested unkeyed containers not implemented for SQLSnapshotEncoder")
    }

    mutating func superEncoder() -> Encoder {
        fatalError("superEncoder not implemented for SQLSnapshotEncoder")
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        fatalError("superEncoder(forKey:) not implemented for SQLSnapshotEncoder")
    }
}

struct SQLSnapshotUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    var codingPath: [CodingKey]
    var count: Int = 0
    private var encoder: SQLSnapshotEncoder

    init(encoder: SQLSnapshotEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    // Helper (similar to KeyedContainer)
    private func sqlString<T>(_ value: T) -> String {
        if let str = value as? String {
            return "'\(str.replacingOccurrences(of: "'", with: "''"))'"
        } else if value is Int || value is Double || value is Float {
            return "\(value)"
        } else if let boolVal = value as? Bool {
            return boolVal ? "1" : "0"
        }
        return "'\(String(describing: value))'"
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        print("Encoding unkeyed value: \(value) at index \(count)")
        encoder.storage["\(codingPath.last?.stringValue ?? "array")_\(count)"] = sqlString(value)
        count += 1
    }

    mutating func encodeNil() throws {
        encoder.storage["\(codingPath.last?.stringValue ?? "array")_\(count)"] = "NULL"
        count += 1
    }

    mutating func nestedContainer<NK>(keyedBy keyType: NK.Type) -> KeyedEncodingContainer<NK> where NK : CodingKey {
        fatalError("Not implemented")
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("Not implemented")
    }

    mutating func superEncoder() -> Encoder {
        fatalError("Not implemented")
    }
}

struct SQLSnapshotSingleValueEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey]
    private var encoder: SQLSnapshotEncoder

    init(encoder: SQLSnapshotEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    // Helper (similar to KeyedContainer)
    private func sqlString<T>(_ value: T) -> String {
        if let str = value as? String {
            return "'\(str.replacingOccurrences(of: "'", with: "''"))'"
        } else if value is Int || value is Double || value is Float {
            return "\(value)"
        } else if let boolVal = value as? Bool {
            return boolVal ? "1" : "0"
        }
        return "'\(String(describing: value))'"
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {

        let key = codingPath.map { $0.stringValue }.joined(separator: "_")
        if key.isEmpty {
             print("Warning: Encoding single value at top level. No key derived. Storing with 'single_value'.")
             encoder.storage["single_value"] = sqlString(value)
        } else {
             encoder.storage[key] = sqlString(value)
        }
    }

    mutating func encodeNil() throws {
        let key = codingPath.map { $0.stringValue }.joined(separator: "_")
        if key.isEmpty {
            encoder.storage["single_value"] = "NULL"
        } else {
            encoder.storage[key] = "NULL"
        }
    }
}


private enum MariaEnconderException: Error {
    case DoNotSerialize(String)
}

