import Foundation

indirect enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Int.self) { self = .int(value); return }
        if let value = try? container.decode(Double.self) { self = .double(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

extension JSONValue {
    /// Stash's `findSavedFilters` returns `object_filter` in the web UI's
    /// internal shape rather than `SceneFilterType` input shape. Two common
    /// divergences for multi-id criteria:
    ///
    /// - Plain multi-criterion (performers, etc.):
    ///   `value: [{id, label}, …]` → `value: [id, …]`
    ///
    /// - Hierarchical multi-criterion (tags, studios, etc.):
    ///   `value: {depth, items: [{id, label}, …]}`
    ///   → `value: [id, …]` plus `depth` lifted to the criterion level.
    ///
    /// Other shapes (Int/String/Float/Date criteria) pass through unchanged.
    func normalizedForCriterionInput() -> JSONValue {
        switch self {
        case .object(let dict):
            return Self.normalizeObject(dict)
        case .array(let arr):
            return .array(arr.map { $0.normalizedForCriterionInput() })
        default:
            return self
        }
    }

    private static func normalizeObject(_ dict: [String: JSONValue]) -> JSONValue {
        var out: [String: JSONValue] = [:]
        var liftedDepth: JSONValue?

        for (key, raw) in dict {
            let recursed = raw.normalizedForCriterionInput()
            if key == "value" || key == "excludes" {
                let (normalized, depth) = unwrapCriterionValue(recursed)
                out[key] = normalized
                if key == "value", let depth { liftedDepth = depth }
            } else {
                out[key] = recursed
            }
        }

        if let liftedDepth, out["depth"] == nil {
            out["depth"] = liftedDepth
        }
        return .object(out)
    }

    private static func unwrapCriterionValue(_ value: JSONValue) -> (JSONValue, depth: JSONValue?) {
        if case .object(let parts) = value,
           case .array(let items) = parts["items"] ?? .null {
            guard let ids = extractIDs(from: items) else { return (value, nil) }
            return (.array(ids), parts["depth"])
        }
        if case .array(let items) = value,
           let ids = extractIDs(from: items) {
            return (.array(ids), nil)
        }
        return (value, nil)
    }

    private static func extractIDs(from items: [JSONValue]) -> [JSONValue]? {
        guard !items.isEmpty else { return nil }
        var ids: [JSONValue] = []
        for item in items {
            guard case .object(let dict) = item, let id = dict["id"] else {
                return nil
            }
            ids.append(id)
        }
        return ids
    }
}
