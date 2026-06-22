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
            switch key {
            case "value", "excludes", "excluded":
                let (normalized, depth) = unwrapCriterionValue(raw)
                // Newer Stash nests an "excluded" list; SceneFilterType wants "excludes".
                out[key == "excluded" ? "excludes" : key] = normalized
                if let depth { liftedDepth = depth }
            default:
                out[key] = raw.normalizedForCriterionInput()
            }
        }

        if let liftedDepth, out["depth"] == nil {
            out["depth"] = liftedDepth
        }
        return .object(out)
    }

    /// Collapses a criterion `value`/`excludes` payload to an array of scalar IDs,
    /// lifting any `depth` out for the criterion level. Handles every shape Stash
    /// has shipped: a bare scalar/array of scalars, `[{id, label}, …]`,
    /// `{items: [{id, label}, …], depth}`, a single `{id, …}`, and an `id` that is
    /// itself wrapped in another object.
    private static func unwrapCriterionValue(_ value: JSONValue) -> (JSONValue, depth: JSONValue?) {
        switch value {
        case .object(let parts):
            if case .array(let items) = parts["items"] ?? .null {
                return (.array(collectIDs(from: items)), parts["depth"])
            }
            if parts["id"] != nil {
                return (.array(collectIDs(from: [value])), nil)
            }
            // Some scalar criteria carry an object value (e.g. ranges) — leave intact.
            return (value, nil)
        case .array(let items):
            return (.array(collectIDs(from: items)), nil)
        default:
            return (value, nil)
        }
    }

    private static func collectIDs(from items: [JSONValue]) -> [JSONValue] {
        var ids: [JSONValue] = []
        for item in items {
            switch item {
            case .string, .int:
                ids.append(item)
            case .object(let dict):
                if let id = dict["id"] {
                    ids.append(scalarID(id))
                } else if case .array(let nested) = dict["items"] ?? .null {
                    ids.append(contentsOf: collectIDs(from: nested))
                }
                // Objects with neither id nor nested items are dropped, not passed
                // through — the server rejects a map where an ID is expected.
            default:
                break
            }
        }
        return ids
    }

    /// An `id` is occasionally another `{id, label}` object; drill to the scalar.
    private static func scalarID(_ value: JSONValue) -> JSONValue {
        if case .object(let dict) = value, let inner = dict["id"] {
            return scalarID(inner)
        }
        return value
    }
}
