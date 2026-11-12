//
//  Copyright 2026 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

/// A JSON value, as exchanged with the emulator over its control protocol.
///
/// The control protocol is schema-driven but open-ended: commands and events carry arbitrary nested
/// structures. Modelling them as a small recursive enum, instead of the untyped objects produced by
/// the Foundation serializer, keeps every message `Sendable`, so it can cross actor boundaries
/// without copying or unchecked annotations.
enum QMPValue: Sendable, Hashable, Codable {

    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([QMPValue])
    case object([String: QMPValue])

    // MARK: - Accessors

    /// The member stored under a key, if this value is an object that has it.
    subscript(key: String) -> QMPValue? {
        guard case .object(let members) = self else { return nil }
        return members[key]
    }

    /// The payload, if this value is a string.
    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    /// The payload, if this value is an integer.
    var integerValue: Int64? {
        guard case .integer(let value) = self else { return nil }
        return value
    }

    /// The payload, if this value is a boolean.
    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    // MARK: - Codable

    /// Decodes whichever JSON type is found.
    ///
    /// The order of the attempts matters: booleans and integers are tried before floating point
    /// numbers so that they keep their exact type.
    init(from decoder: any Decoder) throws {

        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([QMPValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: QMPValue].self))
        }
    }

    /// Encodes the payload as its native JSON type.
    func encode(to encoder: any Encoder) throws {

        var container = encoder.singleValueContainer()

        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
