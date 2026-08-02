import Foundation

/// Wire format for /coach/turn.
///
/// The app keeps two parallel histories: `ChatMessage` for the bubbles the user
/// sees, and `WireMessage` for what the API needs — which includes tool_use and
/// tool_result blocks that never appear on screen. Claude rejects a request
/// where a tool_use isn't answered by a matching tool_result, so the wire
/// history can't be reconstructed from the display history.

// MARK: - Minimal JSON value

/// Just enough to round-trip a tool's `input` object back to the API unchanged.
enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let dictionary) = self { return dictionary[key] }
        return nil
    }
}

// MARK: - Messages

struct WireBlock: Codable, Hashable {
    let type: String
    var text: String?
    var id: String?
    var name: String?
    var input: JSONValue?
    var toolUseID: String?
    var content: String?

    /// The API uses snake_case on the wire; Swift keeps camelCase.
    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, content
        case toolUseID = "tool_use_id"
    }

    static func text(_ value: String) -> WireBlock {
        WireBlock(type: "text", text: value)
    }

    static func toolUse(id: String, name: String, input: JSONValue) -> WireBlock {
        WireBlock(type: "tool_use", id: id, name: name, input: input)
    }

    static func toolResult(id: String, content: String) -> WireBlock {
        WireBlock(type: "tool_result", toolUseID: id, content: content)
    }
}

struct WireMessage: Codable, Hashable {
    let role: String
    var content: [WireBlock]

    static func user(_ text: String) -> WireMessage {
        WireMessage(role: "user", content: [.text(text)])
    }
}

// MARK: - Request

struct CoachContext: Codable, Hashable {
    let phase: String
    let exercise: String
    let prescription: String
    var setNumber: Int?
    var totalSets: Int?
    var venue: String?
    var elapsedMinutes: Int?
    var targetMinutes: Int?
    /// Only high-confidence equipment from the most recently recognized gym photo.
    /// It is context for the next coach turn, never a training plan by itself.
    var availableEquipment: [String]?
}

struct CoachTurnRequest: Codable {
    let style: String
    let state: CoachContext
    let memories: [String]
    let messages: [WireMessage]
}

// MARK: - Streamed events

/// One action the coach wants the app to perform. The app executes it and
/// returns a short confirmation as the tool result.
enum CoachAction: Hashable {
    case adjustWeight(kg: Double, reason: String)
    case swapExercise(replacement: String, reason: String)
    case remember(category: MemoryCategory, text: String)

    init?(name: String, input: JSONValue) {
        switch name {
        case "adjust_weight":
            guard let kg = input["weight_kg"]?.doubleValue else { return nil }
            self = .adjustWeight(kg: kg, reason: input["reason"]?.stringValue ?? "")
        case "swap_exercise":
            guard let replacement = input["replacement"]?.stringValue else { return nil }
            self = .swapExercise(
                replacement: replacement, reason: input["reason"]?.stringValue ?? "")
        case "remember":
            guard let text = input["text"]?.stringValue else { return nil }
            let raw = input["category"]?.stringValue ?? "preference"
            self = .remember(category: MemoryCategory(rawValue: raw) ?? .preference, text: text)
        default:
            return nil
        }
    }
}

enum CoachEvent {
    /// Incremental assistant text.
    case text(String)
    /// A tool call, with the id needed to answer it.
    case action(id: String, name: String, input: JSONValue, action: CoachAction?)
    /// Safety classifiers declined; no usable reply.
    case refusal(category: String?)
    case done
}

enum CoachAPIError: LocalizedError {
    case notConfigured
    case http(status: Int)
    case upstream(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "教练服务未配置"
        case .http(let status): return "服务返回 \(status)"
        case .upstream(let reason): return "上游错误：\(reason)"
        }
    }
}
