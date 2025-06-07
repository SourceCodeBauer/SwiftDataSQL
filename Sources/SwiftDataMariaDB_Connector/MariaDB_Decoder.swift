import Foundation
import SwiftData 

// MARK: - UserInfo Key
extension CodingUserInfoKey {
    static let iso8601DateFormatter = CodingUserInfoKey(rawValue: "iso8601DateFormatter")!
}

// MARK: - Decoder Principal
struct MariaDB_Decoder: Decoder {
    
    fileprivate let data: Any // Puede ser un diccionario, array, o valor único
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var storeIdentifier: String
    var targetIdentifier: String

    init(data: Any, codingPath: [CodingKey] = [], storeIdentifier: String, targetIdentifier: String, userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.data = data
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.storeIdentifier = storeIdentifier
        self.targetIdentifier = targetIdentifier
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard let dictionary = self.data as? [String: Any] else {
            throw DecodingError.typeMismatch([String:Any].self, DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected dictionary data to create keyed container but found \(String(describing: Swift.type(of: self.data)))."
            ))
        }
        let container = MariaDB_DictionaryKeyedDecodingContainer<Key>(
            dictionary: dictionary, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier,
            codingPath: self.codingPath,
            userInfo: self.userInfo
        )
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let array = self.data as? [Any] else {
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected array data to create unkeyed container but found \(String(describing: Swift.type(of: self.data)))."
            ))
        }
        return MariaDB_DictionaryUnkeyedDecodingContainer(
            array: array,
            codingPath: self.codingPath, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier,
            userInfo: self.userInfo
        )
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return MariaDB_DictionarySingleValueDecodingContainer(
            value: self.data,
            codingPath: self.codingPath, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier,
            userInfo: self.userInfo
        )
    }
}

// MARK: - Keyed Container
fileprivate struct MariaDB_DictionaryKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K
    let dictionary: [String: Any]
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var storeIdentifier: String
    var targetIdentifier: String

    var allKeys: [Key] {
        return dictionary.keys.compactMap { Key(stringValue: $0) }
    }

    init(dictionary: [String: Any], storeIdentifier: String, targetIdentifier: String, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
        self.dictionary = dictionary
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.storeIdentifier = storeIdentifier
        self.targetIdentifier = targetIdentifier
    }

    func contains(_ key: Key) -> Bool {
        return dictionary[key.stringValue] != nil
    }

    private func getValue(forKey key: Key) throws -> Any {
        guard let value = dictionary[key.stringValue] else {
            let description = "Key \(key.stringValue) not found. Available keys: \(dictionary.keys.sorted().joined(separator: ", "))."
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath, debugDescription: description))
        }
        return value
    }
    
    private func decodePrimitive<T>(_ value: Any, forKey key: Key, as type: T.Type) throws -> T {
        let currentPath = self.codingPath + [key]
        if key.stringValue == "persistentIdentifier" {
            guard let identifier = dictionary["id"] as? String else {
                fatalError("I don't support missing IDs yet.")
            }

            return try PersistentIdentifier.identifier(for: storeIdentifier, entityName: targetIdentifier, primaryKey: identifier) as! T
        }
            if value is NSNull {
            let description = "Expected \(T.self) but found NSNull for key \(key.stringValue)."
            throw DecodingError.valueNotFound(T.self, DecodingError.Context(codingPath: currentPath, debugDescription: description))
        }

        if let castedValue = value as? T {
            return castedValue
        }

        if T.self == Date.self, let dateString = value as? String {
            let formatter = userInfo[.iso8601DateFormatter] as? ISO8601DateFormatter ?? ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) { return date as! T }
            let desc = "Cannot parse date string '\(dateString)' for key \(key.stringValue)."
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: currentPath, debugDescription: desc))
        }
        
        if T.self == UUID.self, let uuidString = value as? String {
            if let uuid = UUID(uuidString: uuidString) { return uuid as! T }
            let desc = "Cannot parse UUID string '\(uuidString)' for key \(key.stringValue)."
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: currentPath, debugDescription: desc))
        }
        
        if T.self == Data.self, let base64String = value as? String {
            if let data = Data(base64Encoded: base64String) { return data as! T }
            let desc = "Cannot parse Base64 string for key \(key.stringValue)."
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: currentPath, debugDescription: desc))
        }

        if let number = value as? NSNumber {
            if T.self == Int.self { return number.intValue as! T }
            if T.self == Int64.self { return number.int64Value as! T }
            if T.self == Double.self { return number.doubleValue as! T }
            if T.self == Float.self { return number.floatValue as! T }
            // ... otros UInts, etc.
        }
        
        let description = "Cannot convert value for key \(key.stringValue) (type: \(String(describing: Swift.type(of: value)))) to \(String(describing: T.self))."
        throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: currentPath, debugDescription: description))
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let entry = dictionary[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Key \(key.stringValue) not found."))
        }
        return entry is NSNull
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try decodePrimitive(try getValue(forKey: key), forKey: key, as: type) }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        if key.stringValue == "persistentIdentifier" {
            guard let identifier = dictionary["id"] as? UUID else {
                fatalError("I don't support missing IDs yet.")
            }
                return try PersistentIdentifier.identifier(for: storeIdentifier, entityName: targetIdentifier, primaryKey: identifier.uuidString) as! T
        } else if key.stringValue == "id" {
            if let identifier = dictionary["id"] as? UUID
            {
                return identifier as! T
            }
            /*
            guard let identifier = dictionary["id"] as? String   else {
                fatalError("I don't support missing IDs yet.")
            }
             */
            guard let identifier = dictionary["id"] as? UUID   else {
                fatalError("I don't support missing IDs yet.")
            }
            return UUID(uuidString: identifier.uuidString) as! T
        } else if (type == [PersistentIdentifier].self)
        {
            return [] as! T;
        }
        else {
            return dictionary[key.stringValue] as! T
        }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let value = try getValue(forKey: key)
        let newPath = self.codingPath + [key]
        guard let nestedDict = value as? [String: Any] else {
            let description = "Expected nested dictionary for key \(key.stringValue) but found \(String(describing: Swift.type(of: value)))."
            throw DecodingError.typeMismatch([String:Any].self, DecodingError.Context(codingPath: newPath, debugDescription: description))
        }
        let container = MariaDB_DictionaryKeyedDecodingContainer<NestedKey>(
            dictionary: nestedDict, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier ,
            codingPath: newPath,
            userInfo: self.userInfo
        )
        return KeyedDecodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let value = try getValue(forKey: key)
        let newPath = self.codingPath + [key]
        guard let nestedArray = value as? [Any] else {
            let description = "Expected nested array for key \(key.stringValue) but found \(String(describing: Swift.type(of: value)))."
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(codingPath: newPath, debugDescription: description))
        }
        return MariaDB_DictionaryUnkeyedDecodingContainer(
            array: nestedArray,
            codingPath: newPath, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier,
            userInfo: self.userInfo
        )
    }

    func superDecoder() throws -> Decoder {

        return MariaDB_Decoder(data: self.dictionary, codingPath: self.codingPath, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier , userInfo: self.userInfo)
    }
    func superDecoder(forKey key: Key) throws -> Decoder {
        let value = try getValue(forKey: key)
        let newPath = self.codingPath + [key]
        return MariaDB_Decoder(data: value, codingPath: newPath, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier, userInfo: self.userInfo)
    }
}

// MARK: - Unkeyed Container
fileprivate struct MariaDB_DictionaryUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let array: [Any]
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var currentIndex: Int = 0
    

    var count: Int? { return array.count }
    var isAtEnd: Bool { return currentIndex >= array.count }
    var storeIdentifier: String
    var targetIdentifier: String
    init(array: [Any], codingPath: [CodingKey], storeIdentifier: String, targetIdentifier: String, userInfo: [CodingUserInfoKey: Any]) {
        self.array = array
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.storeIdentifier = storeIdentifier
        self.targetIdentifier = targetIdentifier
    }
    
    private func currentItemPath() -> [CodingKey] {
        return self.codingPath + [MariaDB_DictionaryIndexKey(intValue: currentIndex)]
    }

    private mutating func checkAndAdvance<T>(forType type: T.Type) throws -> Any {
        if isAtEnd {
            let description = "Unkeyed container is at end."
            throw DecodingError.valueNotFound(T.self, DecodingError.Context(codingPath: currentItemPath(), debugDescription: description))
        }
        let value = array[currentIndex]
        currentIndex += 1 // Avanzar índice DESPUÉS de obtener el valor
        return value
    }
    
    private mutating func decodePrimitive<T>(as type: T.Type) throws -> T {
        let value = try checkAndAdvance(forType: T.self)
        let currentPathForElement = self.codingPath + [MariaDB_DictionaryIndexKey(intValue: currentIndex - 1)] // Path del elemento que acabamos de obtener

        if value is NSNull {
            let description = "Expected \(T.self) but found NSNull at index \(currentIndex - 1)."
            throw DecodingError.valueNotFound(T.self, DecodingError.Context(codingPath: currentPathForElement, debugDescription: description))
        }

        if let castedValue = value as? T {
            return castedValue
        }
        
        if T.self == Date.self, let dateString = value as? String {
            let formatter = userInfo[.iso8601DateFormatter] as? ISO8601DateFormatter ?? ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) { return date as! T }
            let desc = "Cannot parse date string '\(dateString)' at index \(currentIndex - 1)."
            throw DecodingError.dataCorruptedError(in: self, debugDescription: desc)
        }
        if T.self == UUID.self, let uuidString = value as? String {
            if let uuid = UUID(uuidString: uuidString) { return uuid as! T }
            let desc = "Cannot parse UUID string '\(uuidString)' at index \(currentIndex - 1)."
            throw DecodingError.dataCorruptedError(in: self, debugDescription: desc)
        }
        if T.self == Data.self, let base64String = value as? String {
            if let data = Data(base64Encoded: base64String) { return data as! T }
            let desc = "Cannot parse Base64 string at index \(currentIndex - 1)."
            throw DecodingError.dataCorruptedError(in: self, debugDescription: desc)
        }
        
        let description = "Cannot convert array element at index \(currentIndex - 1) (value: \(value), type: \(String(describing: Swift.type(of: value)))) to \(String(describing: T.self))."
        throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: currentPathForElement, debugDescription: description))
    }

    mutating func decodeNil() throws -> Bool {
        if isAtEnd {
            throw DecodingError.valueNotFound(Any?.self, DecodingError.Context(codingPath: currentItemPath(), debugDescription: "Unkeyed container is at end, cannot decode nil."))
        }
        if array[currentIndex] is NSNull {
            currentIndex += 1
            return true
        }
        return false // El valor no es NSNull, por lo tanto no es nil en este contexto.
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool { try decodePrimitive(as: type) }
    mutating func decode(_ type: String.Type) throws -> String { try decodePrimitive(as: type) }
    mutating func decode(_ type: Double.Type) throws -> Double { try decodePrimitive(as: type) }
    mutating func decode(_ type: Float.Type) throws -> Float { try decodePrimitive(as: type) }
    mutating func decode(_ type: Int.Type) throws -> Int { try decodePrimitive(as: type) }
    // ... Implementar para todos los Int/UInt ...

    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let value = try checkAndAdvance(forType: T.self)
        let currentPathForElement = self.codingPath + [MariaDB_DictionaryIndexKey(intValue: currentIndex - 1)]
        
        let elementDecoder = MariaDB_Decoder(data: value, codingPath: currentPathForElement, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier, userInfo: self.userInfo)
        return try T(from: elementDecoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let value = try checkAndAdvance(forType: [String:Any].self)
        let currentPathForElement = self.codingPath + [MariaDB_DictionaryIndexKey(intValue: currentIndex - 1)]
        guard let dict = value as? [String: Any] else {
            let description = "Expected nested dictionary at index \(currentIndex - 1) but found \(String(describing: Swift.type(of: value)))."
            throw DecodingError.typeMismatch([String:Any].self, DecodingError.Context(codingPath: currentPathForElement, debugDescription: description))
        }
        let container = MariaDB_DictionaryKeyedDecodingContainer<NestedKey>(
            dictionary: dict, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier,
            codingPath: currentPathForElement,
            userInfo: userInfo
        )
        return KeyedDecodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let value = try checkAndAdvance(forType: [Any].self)
        let currentPathForElement = self.codingPath + [MariaDB_DictionaryIndexKey(intValue: currentIndex - 1)]
        guard let arr = value as? [Any] else {
            let description = "Expected nested array at index \(currentIndex - 1) but found \(String(describing: Swift.type(of: value)))."
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(codingPath: currentPathForElement, debugDescription: description))
        }
        return MariaDB_DictionaryUnkeyedDecodingContainer(
            array: arr,
            codingPath: currentPathForElement, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier,
            userInfo: userInfo
        )
    }
    
    mutating func superDecoder() throws -> Decoder {
         let value = try checkAndAdvance(forType: Any.self)
         let currentPathForElement = self.codingPath + [MariaDB_DictionaryIndexKey(intValue: currentIndex - 1)]
         return MariaDB_Decoder(data: value, codingPath: currentPathForElement, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier, userInfo: userInfo)
    }
}

// MARK: - Single Value Container
fileprivate struct MariaDB_DictionarySingleValueDecodingContainer: SingleValueDecodingContainer {
    let value: Any
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var storeIdentifier: String
    var targetIdentifier: String
    init(value: Any, codingPath: [CodingKey], storeIdentifier: String, targetIdentifier: String, userInfo: [CodingUserInfoKey: Any]) {
        self.value = value
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.storeIdentifier = storeIdentifier
        self.targetIdentifier = targetIdentifier
    }

    private func decodePrimitive<T>(as type: T.Type) throws -> T {
        if value is NSNull {
             let description = "Expected \(T.self) but found NSNull for single value."
             throw DecodingError.valueNotFound(T.self, DecodingError.Context(codingPath: codingPath, debugDescription: description))
        }
        if let castedValue = value as? T {
            return castedValue
        }
        
        if T.self == Date.self, let dateString = value as? String {
            let formatter = userInfo[.iso8601DateFormatter] as? ISO8601DateFormatter ?? ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) { return date as! T }
            let desc = "Cannot parse date string '\(dateString)'"; throw DecodingError.dataCorruptedError(in: self, debugDescription: desc)
        }
        if T.self == UUID.self, let uuidString = value as? String {
            if let uuid = UUID(uuidString: uuidString) { return uuid as! T }
            let desc = "Cannot parse UUID string '\(uuidString)'"; throw DecodingError.dataCorruptedError(in: self, debugDescription: desc)
        }
        if T.self == Data.self, let base64String = value as? String {
            if let data = Data(base64Encoded: base64String) { return data as! T }
            let desc = "Cannot parse Base64 string"; throw DecodingError.dataCorruptedError(in: self, debugDescription: desc)
        }
        
        if let number = value as? NSNumber {
            if T.self == Int.self { return number.intValue as! T }
            // ... más números ...
        }
        
        let description = "Cannot convert single value (value: \(value), type: \(String(describing: Swift.type(of: value)))) to \(String(describing: T.self))."
        throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: codingPath, debugDescription: description))
    }

    func decodeNil() -> Bool {
        return value is NSNull
    }
    func decode(_ type: Bool.Type) throws -> Bool { try decodePrimitive(as: type) }
    func decode(_ type: String.Type) throws -> String { try decodePrimitive(as: type) }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let valueDecoder = MariaDB_Decoder(data: self.value, codingPath: self.codingPath, storeIdentifier: storeIdentifier, targetIdentifier: targetIdentifier, userInfo: self.userInfo)
        return try T(from: valueDecoder)
    }
}

// MARK: - IndexKey (Helper)
fileprivate struct MariaDB_DictionaryIndexKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "[\(intValue)]"
    }
    init?(stringValue: String) {
        return nil
    }
}

