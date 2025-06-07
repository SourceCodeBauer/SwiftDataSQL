//
//  PerfectCRUDDatabase.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation
import SwiftData

public struct Database<C: DatabaseConfigurationProtocol>: DatabaseProtocol {
	public typealias Configuration = C
	public let configuration: Configuration
	public init(configuration c: Configuration) {
		configuration = c
	}
	public func table<T: Codable>(_ form: T.Type) -> Table<T, Database> {
		return .init(database: self)
	}
}

public extension Database {
	func sql(_ sql: String, bindings: Bindings = []) throws {
		//CRUDLogging.log(.query, sql)
		let delegate = try configuration.sqlExeDelegate(forSQL: sql)
		try delegate.bind(bindings, skip: 0)
		_ = try delegate.hasNext()
	}
	func sql<A: Codable>(_ sql: String, bindings: Bindings = [], _ type: A.Type) throws -> [A] {
		//CRUDLogging.log(.query, sql)
		let delegate = try configuration.sqlExeDelegate(forSQL: sql)
		try delegate.bind(bindings, skip: 0)
		var ret: [A] = []
		while try delegate.hasNext() {
			let rowDecoder: CRUDRowDecoder<ColumnKey> = CRUDRowDecoder(delegate: delegate)
			ret.append(try A(from: rowDecoder))
		}
		return ret
	}
}

public extension Database {
	func transaction<T>(_ body: () throws -> T) throws -> T {
		try sql("BEGIN")
		do {
			let r = try body()
			try sql("COMMIT")
			return r
		} catch {
			try sql("ROLLBACK")
			throw error
		}
	}
}
/*
public extension Database {
    // Esta función NO es la que implementa el protocolo directamente.
    // Es una función de ayuda interna.
    private func fetchRawDictionaries(_ sqlString: String, bindings: Bindings = []) throws -> [[String: Any]] {
        let delegate = try configuration.sqlExeDelegate(forSQL: sqlString)
        try delegate.bind(bindings, skip: 0)
        var results: [[String: Any]] = []
        let rowDecoder = CRUDRowDecoder<ColumnKey>(delegate: delegate)

        // Instanciar fuera del bucle para eficiencia si se usa repetidamente
        let iso8601Formatter = ISO8601DateFormatter()

        while try delegate.hasNext() {
            let container = try rowDecoder.container(keyedBy: ColumnKey.self)
            var preparedRowValues: [String: Any] = [:]

            for key in container.allKeys {
                let columnName = key.stringValue
                if try container.decodeNil(forKey: key) {
                    preparedRowValues[columnName] = NSNull()
                } else if let dateValue = try? container.decode(Date.self, forKey: key) {
                    preparedRowValues[columnName] = iso8601Formatter.string(from: dateValue)
                } else if let uuidValue = try? container.decode(UUID.self, forKey: key) { // <--- AÑADIDO SOPORTE UUID
                    preparedRowValues[columnName] = uuidValue.uuidString
                } else if let stringValue = try? container.decode(String.self, forKey: key) {
                    preparedRowValues[columnName] = stringValue
                } else if let intValue = try? container.decode(Int64.self, forKey: key) {
                    preparedRowValues[columnName] = intValue
                } else if let doubleValue = try? container.decode(Double.self, forKey: key) {
                    preparedRowValues[columnName] = doubleValue
                } else if let boolValue = try? container.decode(Bool.self, forKey: key) {
                    preparedRowValues[columnName] = boolValue
                } else if let dataValue = try? container.decode(Data.self, forKey: key) {
                    preparedRowValues[columnName] = dataValue.base64EncodedString()
                }
                else {
                    print("Advertencia: Tipo de columna no manejado explícitamente para '\(columnName)'. Se intentará como String o se usará NSNull.")
                    if let fallbackString = try? container.decode(String.self, forKey: key) {
                        preparedRowValues[columnName] = fallbackString
                    } else {
                        preparedRowValues[columnName] = NSNull()
                    }
                }
            }
            if !preparedRowValues.isEmpty {
                results.append(preparedRowValues)
            }
        }
        return results
    }

    
    // En tu clase/struct que implementa el protocolo sql
    func sql<A: PersistentModel>(_ sqlString: String, bindings: Bindings = [], _ modelType: A.Type) throws -> [A] {
        let dictionaries = try fetchRawDictionaries(sqlString, bindings: bindings) // Obtienes [[String: Any]]
        
        var resultingModels: [A] = []
        
        // AHORA, A debe ser Decodable para que esto funcione.
        // Si el protocolo sql no puede tener A: Decodable, necesitas la verificación en tiempo de ejecución.
        guard let DecodableA = A.self as? Decodable.Type else {
            throw YourCustomError.typeNotDecodable("El tipo \(A.self) no es Decodable y no puede usarse con DictionaryDecoder.")
        }

        for dict in dictionaries {
            guard !dict.isEmpty else { continue }
            do {
                let dictionaryDecoder = DictionaryDecoder(dictionary: dict)
                // Aquí es donde A.init(from: Decoder) se invoca.
                // El cast as! A es porque DecodableA.init devuelve Decodable (o Self),
                // y necesitamos el tipo concreto A.
                let modelInstance = try DecodableA.init(from: dictionaryDecoder) as! A
                resultingModels.append(modelInstance)
            } catch {
                print("Error al decodificar diccionario a \(A.self) usando DictionaryDecoder: \(error). Diccionario: \(dict)")
                // Manejar error
                // Si el error es de DictionaryDecoder, su codingPath y debugDescription deberían ser útiles.
                if let decodingError = error as? DecodingError {
                    print("DecodingError: \(decodingError.localizedDescription)")
                    // Puedes inspeccionar los casos de DecodingError para más detalles
                }
            }
        }
        return resultingModels
    }
    
    // Define tu error personalizado
    enum YourCustomError: Error {
        case typeNotDecodable(String)
        // otros casos
    }

}
*/

public extension Database
{
    // Asunciones:
    // - CRUDRowDecoder y ColumnKey están definidos (de Perfect-CRUD).
    // - 'configuration.sqlExeDelegate' es accesible para obtener el SQLExeDelegate.
    // - Bindings es un tipo definido para los parámetros de la consulta.
    // - Tienes una forma fiable de obtener los nombres de las columnas (ver comentarios).

    // Si esto es un método de instancia de una clase/struct que tiene 'configuration':
    // public func fetchQueryResultsAsDictionaries(_ sqlString: String, bindings: Bindings = []) throws -> [[String: Any]] {

    // Si es una función global o estática, necesitarías pasar 'configuration' o el 'delegate'
    // public static func fetchQueryResultsAsDictionaries(sql sqlString: String, bindings: Bindings = [], using configuration: YourDatabaseConfiguration) throws -> [[String: Any]] {

    // Asumiré que es un método de instancia para el ejemplo:
    // extension YourDatabaseService { // O como se llame tu clase/struct

    func fetchQueryResultsAsDictionaries(    
        _ sqlString: String,
        bindings: Bindings = []
    ) throws -> [[String: Any]] {

        // 'self.configuration' o simplemente 'configuration' si está en el mismo ámbito
        let delegate = try self.configuration.sqlExeDelegate(forSQL: sqlString)
        try delegate.bind(bindings, skip: 0)
        
        var results: [[String: Any]] = []
        
        // Usamos el CRUDRowDecoder original de Perfect-CRUD para leer filas.
        let rowDecoderFromDelegate = CRUDRowDecoder<ColumnKey>(delegate: delegate)

        // Lógica para obtener nombres de columna. Este es el punto más crítico
        // para la robustez si `container.allKeys` no es fiable.
        var columnNamesForIteration: [String]? = nil

        // Intento prioritario: Si tu delegate es MySQLStmt (o similar que exponga nombres de columna)
        // if let mariaDBStatement = delegate as? MySQLStmt { // Reemplaza MySQLStmt con tu tipo real
        //     columnNamesForIteration = mariaDBStatement.columnNames
        // }
        // Si lo anterior no es posible o no es el caso general, intentaremos con container.allKeys
        // pero con la advertencia de que podría estar vacío si hay un bug en la librería subyacente.

        while try delegate.hasNext() {
            let container = try rowDecoderFromDelegate.container(keyedBy: ColumnKey.self)
            var currentRowDictionary: [String: Any] = [:]

            // Si no se obtuvieron nombres de columna del delegate, intenta desde el primer contenedor.
            if columnNamesForIteration == nil {
                columnNamesForIteration = container.allKeys.map { $0.stringValue }
                
                // VERIFICACIÓN CRÍTICA: Si después de esto columnNamesForIteration sigue vacío
                // y hay filas, tienes un problema para obtener los nombres de columna.
                // La corrección que hiciste en Perfect-MariaDB para `allKeys` debería ayudar aquí.
                if (columnNamesForIteration == nil || columnNamesForIteration!.isEmpty) && results.isEmpty {
                     print("Advertencia: No se pudieron obtener los nombres de columna de la primera fila. Los diccionarios podrían estar vacíos o incompletos.")
                     // Podrías optar por lanzar un error aquí si es un fallo crítico.
                     // throw MySQLError.couldNotDetermineColumnNames
                }
            }

            // Si, incluso después del primer intento, no hay nombres de columna, pero hay filas,
            // no podemos continuar de forma significativa.
            guard let currentColumnNames = columnNamesForIteration, !currentColumnNames.isEmpty else {
                if results.isEmpty { // Solo imprimir/loguear una vez
                    print("Advertencia: No hay nombres de columna para procesar las filas. La consulta podría no devolver columnas.")
                }
                break // Salir del bucle while si no hay columnas
            }
            
            for columnNameString in currentColumnNames {
                // Es buena idea verificar si la clave realmente existe en el contenedor actual,
                // aunque si `currentColumnNames` viene de `allKeys`, debería existir.
                guard let columnKey = ColumnKey(stringValue: columnNameString), container.contains(columnKey) else {
                    // Si la columna estaba en la lista pero no en este contenedor específico (muy raro),
                    // podrías añadir NSNull o simplemente omitirla.
                    // currentRowDictionary[columnNameString] = NSNull()
                    // print("Advertencia: La columna '\(columnNameString)' estaba en allKeys pero no en el contenedor actual.")
                    continue
                }

                if try container.decodeNil(forKey: columnKey) {
                    currentRowDictionary[columnKey.stringValue] = NSNull()
                } else if let value = try? container.decode(Date.self, forKey: columnKey) {
                    currentRowDictionary[columnKey.stringValue] = value
                } else if let value = try? container.decode(UUID.self, forKey: columnKey) {
                    currentRowDictionary[columnKey.stringValue] = value
                } else if let value = try? container.decode(String.self, forKey: columnKey) {
                    currentRowDictionary[columnKey.stringValue] = value
                } else if let value = try? container.decode(Int64.self, forKey: columnKey) { // Prioriza Int64 para números enteros de BD
                    currentRowDictionary[columnKey.stringValue] = value
                } else if let value = try? container.decode(Double.self, forKey: columnKey) { // Para números decimales
                    currentRowDictionary[columnKey.stringValue] = value
                } else if let value = try? container.decode(Data.self, forKey: columnKey) {
                    currentRowDictionary[columnKey.stringValue] = value
                } else if let value = try? container.decode(Bool.self, forKey: columnKey) {
                    currentRowDictionary[columnKey.stringValue] = value
                }
                // Si necesitas distinguir Int de Int64, o Float de Double, añade más casos:
                // else if let value = try? container.decode(Int.self, forKey: columnKey) {
                //     currentRowDictionary[columnKey.stringValue] = value
                // }
                else {
                    // Como último recurso, intenta obtenerlo como un String si no es nil.
                    // Esto es útil si la base de datos devuelve tipos numéricos como strings a veces.
                    if let fallbackValue = try? container.decode(String.self, forKey: columnKey) {
                        currentRowDictionary[columnKey.stringValue] = fallbackValue
                        // print("Info: Columna '\(columnKey.stringValue)' decodificada como String de fallback.")
                    } else {
                        // Si todo falla, representa el valor como NSNull.
                        currentRowDictionary[columnKey.stringValue] = NSNull()
                        print("Advertencia: No se pudo decodificar la columna '\(columnKey.stringValue)' a ningún tipo conocido y no es un String. Se almacena NSNull.")
                    }
                }
            }
            
            // Solo añadir el diccionario si contiene algo (evita diccionarios vacíos si no hay columnas)
            if !currentRowDictionary.isEmpty {
                
                results.append(currentRowDictionary)
            }
        }
        return results
    }

    // } // Fin de la extensión/clase

}
