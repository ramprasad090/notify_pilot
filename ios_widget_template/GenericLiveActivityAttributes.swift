// GenericLiveActivityAttributes.swift
// Copy this file into BOTH your Runner target AND Widget Extension target.
// Both targets must share the same App Group ID.

import ActivityKit
import Foundation

/// Generic attributes for Live Activities managed by notify_pilot.
///
/// Uses flexible key-value data so Flutter can send any data structure
/// without recompiling Swift code.
struct GenericLiveActivityAttributes: ActivityAttributes {
    /// Dynamic state that can be updated during the activity's lifetime.
    public struct ContentState: Codable, Hashable {
        var data: [String: AnyCodable]

        init(data: [String: Any]) {
            self.data = data.mapValues { AnyCodable($0) }
        }
    }

    /// Identifies which Widget Extension layout to use.
    var type: String
}

// MARK: - AnyCodable

/// A type-erased Codable value wrapper.
///
/// Supports String, Int, Double, Bool, and nested dictionaries/arrays.
struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encode(String(describing: value))
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }

    // MARK: - Convenience accessors

    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }
    var doubleValue: Double? { value as? Double }
    var boolValue: Bool? { value as? Bool }
}
