import Foundation
import ActivityKit

/// Generic ActivityAttributes that can carry arbitrary key-value data.
/// Used by LiveActivityManager to support any Flutter-defined Live Activity
/// without requiring compiled-in attribute types.
@available(iOS 16.2, *)
struct GenericLiveActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var data: [String: AnyCodable]

        init(data: [String: Any]) {
            self.data = data.mapValues { AnyCodable($0) }
        }
    }

    var type: String
}

// MARK: - AnyCodable

/// A type-erased Codable wrapper that supports common JSON-compatible types.
/// Enables encoding and decoding of `Any` values within Codable structs.
struct AnyCodable: Codable, Hashable {

    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if value is NSNull {
            try container.encodeNil()
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let arrayVal = value as? [Any] {
            try container.encode(arrayVal.map { AnyCodable($0) })
        } else if let dictVal = value as? [String: Any] {
            try container.encode(dictVal.mapValues { AnyCodable($0) })
        } else {
            // Fall back to string representation
            try container.encode(String(describing: value))
        }
    }

    // MARK: - Hashable

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        let lhsData = try? JSONEncoder().encode(lhs)
        let rhsData = try? JSONEncoder().encode(rhs)
        return lhsData == rhsData
    }

    func hash(into hasher: inout Hasher) {
        if let data = try? JSONEncoder().encode(self) {
            hasher.combine(data)
        }
    }
}
