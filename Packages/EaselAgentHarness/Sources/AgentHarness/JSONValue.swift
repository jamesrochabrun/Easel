import Foundation

/// A fully `Sendable` JSON value. Used for tool JSON schemas and tool arguments
/// so no `Any` ever crosses an actor boundary.
public enum JSONValue: Sendable, Codable, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case null
  case array([JSONValue])
  case object([String: JSONValue])

  // MARK: Codable

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
    } else if let number = try? container.decode(Double.self) {
      self = .number(number)
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let array = try? container.decode([JSONValue].self) {
      self = .array(array)
    } else if let object = try? container.decode([String: JSONValue].self) {
      self = .object(object)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Value is not representable as JSON"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .null: try container.encodeNil()
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }

  // MARK: Parsing / serialization

  /// Parses a raw JSON string (e.g. accumulated tool-call arguments).
  public init(parsing string: String) throws {
    let data = Data(string.utf8)
    self = try JSONDecoder().decode(JSONValue.self, from: data)
  }

  /// Serializes back to a JSON string. Keys are sorted for deterministic output.
  public func encodedString(prettyPrinted: Bool = false) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = prettyPrinted ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
    let data = try encoder.encode(self)
    return String(decoding: data, as: UTF8.self)
  }

  // MARK: Accessors

  public var stringValue: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  public var doubleValue: Double? {
    if case .number(let value) = self { return value }
    return nil
  }

  public var intValue: Int? {
    guard let double = doubleValue, double.truncatingRemainder(dividingBy: 1) == 0 else { return nil }
    return Int(double)
  }

  public var boolValue: Bool? {
    if case .bool(let value) = self { return value }
    return nil
  }

  public var arrayValue: [JSONValue]? {
    if case .array(let value) = self { return value }
    return nil
  }

  public var objectValue: [String: JSONValue]? {
    if case .object(let value) = self { return value }
    return nil
  }

  public subscript(key: String) -> JSONValue? {
    objectValue?[key]
  }

  public subscript(index: Int) -> JSONValue? {
    guard let array = arrayValue, array.indices.contains(index) else { return nil }
    return array[index]
  }
}

// MARK: - Literal conformances (ergonomic schema definitions)

extension JSONValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSONValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) { self = .number(value) }
}

extension JSONValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) { self = .null }
}

extension JSONValue: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, JSONValue)...) {
    self = .object(Dictionary(uniqueKeysWithValues: elements))
  }
}
