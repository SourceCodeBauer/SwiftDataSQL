import Foundation
import SwiftData

final class SQLInsertBuilder {

    func buildInsertSQL(storeIdentifier:String, from snapshot: DefaultSnapshot, tableName: String) -> String? {
        let encoder = SQLSnapshotEncoder(storeIdentifier: storeIdentifier)
        do {
            // Attempt to encode the snapshot values using the encoder
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
            return "NULL"
        }

        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional && mirror.children.isEmpty {
            return "NULL"
        }

        if let stringValue = value as? String {
            let escapedString = stringValue.replacingOccurrences(of: "'", with: "")
            return "'\(escapedString)'"
        } else if let boolValue = value as? Bool {
            return boolValue ? "1" : "0"
        } else if let uuid = value as? UUID {
            return "'\(uuid.uuidString)'"
        } else if let date = value as? Date {
            return "'\(iso8601DateFormatter.string(from: date))'"
        } else if let url = value as? URL {
            return "'\(url.absoluteString)'"
        } else if let intValue = value as? Int {
            return String(intValue)
        } else if let intValue = value as? Int64 {
            return String(intValue)
        } else if let intValue = value as? Int32 {
            return String(intValue)
        } else if let floatValue = value as? Float {
            return String(floatValue)
        } else if let doubleValue = value as? Double {
            return String(doubleValue)
        } else if let numberValue = value as? NSNumber {
            if CFGetTypeID(numberValue) == CFBooleanGetTypeID() {
                return numberValue.boolValue ? "1" : "0"
            }
            return numberValue.stringValue
        } else {
            return String(describing: value)
        }
    }

    func buildInsertSQL(tableName: String) -> String? {
        guard !storage.isEmpty else { return nil }
        let columns = storage.keys.map { "`\($0)`" }.joined(separator: ", ")
        let values = storage.values.map { stringfyValue($0) }.joined(separator: ", ")
        return "INSERT INTO `\(tableName)` (\(columns)) VALUES (\(values));"
    }

    func buildUpdateSQL(tableName: String, column : String, value : String) -> String? {
        guard !storage.isEmpty else { return nil }
        guard let id = storage["id"] else { return nil }
        let setClause = storage.filter { $0.key != "id" }
            .map { "`\($0.key)` = \(stringfyValue($0.value))" }
            .joined(separator: ", ")
        let idValue = stringfyValue(id)
        return "UPDATE `\(tableName)` SET \(setClause) WHERE `ID` = \(idValue);"
    }

    func buildDeleteSQL(tableName: String, column : String, value : String) -> String? {
        return "DELETE FROM `\(tableName)` WHERE \(column) = \(value);"
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
}

struct SQLSnapshotKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    var codingPath: [CodingKey]
    private var encoder: SQLSnapshotEncoder

    init(encoder: SQLSnapshotEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        encoder.storage[key.stringValue] = value
    }

    mutating func encodeNil(forKey key: Key) throws {
        encoder.storage[key.stringValue] = NSNull()
    }

    mutating func nestedContainer<NK>(keyedBy keyType: NK.Type, forKey key: Key) -> KeyedEncodingContainer<NK> where NK : CodingKey {
        fatalError("Nested containers not supported")
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        fatalError("Nested unkeyed containers not supported")
    }

    mutating func superEncoder() -> Encoder {
        fatalError("Super encoder not supported")
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        fatalError("Super encoder for key not supported")
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

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        encoder.storage["\(count)"] = value
        count += 1
    }

    mutating func encodeNil() throws {
        encoder.storage["\(count)"] = NSNull()
        count += 1
    }

    mutating func nestedContainer<NK>(keyedBy keyType: NK.Type) -> KeyedEncodingContainer<NK> where NK : CodingKey {
        fatalError("Nested containers not supported")
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("Nested unkeyed containers not supported")
    }

    mutating func superEncoder() -> Encoder {
        fatalError("Super encoder not supported")
    }
}

struct SQLSnapshotSingleValueEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey]
    private var encoder: SQLSnapshotEncoder

    init(encoder: SQLSnapshotEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        encoder.storage["value"] = value
    }

    mutating func encodeNil() throws {
        encoder.storage["value"] = NSNull()
    }
}

private enum MariaEnconderException: Error {
    case DoNotSerialize(String)
}
