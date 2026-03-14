import Foundation

/// Kind of session event in kiro-cli JSONL logs
public enum SessionEventKind: String, Codable, Sendable {
    case prompt = "Prompt"
    case assistantMessage = "AssistantMessage"
    case toolUse = "ToolUse"
    case toolResults = "ToolResults"
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = SessionEventKind(rawValue: rawValue) ?? .unknown
    }
}

/// Data payload for a session event content item
/// Can be a simple string (for text content) or a complex object (for tool use/results)
public enum SessionEventContentData: Codable, Sendable {
    case text(String)
    case object([String: AnyCodableValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Try decoding as a simple string first
        if let stringValue = try? container.decode(String.self) {
            self = .text(stringValue)
            return
        }
        // Otherwise decode as a dictionary
        if let dictValue = try? container.decode([String: AnyCodableValue].self) {
            self = .object(dictValue)
            return
        }
        throw DecodingError.typeMismatch(
            SessionEventContentData.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected String or Dictionary for SessionEventContentData"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

/// A lightweight type-erased JSON value for encoding/decoding arbitrary JSON structures
public enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dict([String: AnyCodableValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
            return
        }
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
            return
        }
        if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
            return
        }
        if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
            return
        }
        if let arrayVal = try? container.decode([AnyCodableValue].self) {
            self = .array(arrayVal)
            return
        }
        if let dictVal = try? container.decode([String: AnyCodableValue].self) {
            self = .dict(dictVal)
            return
        }
        throw DecodingError.typeMismatch(
            AnyCodableValue.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Cannot decode AnyCodableValue"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let val): try container.encode(val)
        case .int(let val): try container.encode(val)
        case .double(let val): try container.encode(val)
        case .bool(let val): try container.encode(val)
        case .array(let val): try container.encode(val)
        case .dict(let val): try container.encode(val)
        case .null: try container.encodeNil()
        }
    }

    /// Extract string value if this is a .string case
    public var stringValue: String? {
        if case .string(let val) = self { return val }
        return nil
    }
}

/// A content item within a session event's data
public struct SessionEventContent: Codable, Sendable {
    /// The kind of content: "text", "toolUse", "toolResult", etc.
    public let kind: String
    /// The data payload - either a simple string or a complex object
    public let data: SessionEventContentData?

    public init(kind: String, data: SessionEventContentData?) {
        self.kind = kind
        self.data = data
    }
}

/// Data payload of a session event
public struct SessionEventData: Codable, Sendable {
    /// Message identifier
    public let messageId: String?
    /// Content items in this event
    public let content: [SessionEventContent]?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case content
    }

    public init(messageId: String? = nil, content: [SessionEventContent]? = nil) {
        self.messageId = messageId
        self.content = content
    }

    /// Extract all text content from this event data
    /// Iterates content items where kind == "text", extracts the string from data, and joins them
    public func extractTextContent() -> String {
        guard let content = content else { return "" }
        return content.compactMap { item -> String? in
            guard item.kind == "text" else { return nil }
            guard let data = item.data else { return nil }
            switch data {
            case .text(let str):
                return str
            case .object(_):
                return nil
            }
        }.joined()
    }
}

/// A session event parsed from kiro-cli JSONL event logs
public struct SessionEvent: Codable, Sendable {
    /// Version of the event format
    public let version: String
    /// Kind of event
    public let kind: SessionEventKind
    /// Event data payload
    public let data: SessionEventData

    public init(version: String, kind: SessionEventKind, data: SessionEventData) {
        self.version = version
        self.kind = kind
        self.data = data
    }
}
