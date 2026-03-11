import Foundation

/// Type of session event stored in JSONL logs
public enum SessionEventType: String, Codable, Sendable {
    case userMessage = "user_message"
    case agentMessage = "agent_message"
    case toolCall = "tool_call"
    case toolResult = "tool_result"
    case turnEnd = "turn_end"
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case error = "error"
    case unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = SessionEventType(rawValue: rawValue) ?? .unknown
    }
}

/// A session event parsed from JSONL event logs
/// Flexible structure to handle various event types stored by Kiro CLI
public struct SessionEvent: Codable, Sendable {
    /// Type of the event
    public let type: SessionEventType
    /// When this event occurred
    public let timestamp: Date?
    /// Text content (for user_message, agent_message)
    public let content: String?
    /// Tool call identifier (for tool_call, tool_result)
    public let toolCallId: String?
    /// Name of the tool (for tool_call)
    public let toolName: String?
    /// Tool call parameters as JSON string (for tool_call)
    public let toolParameters: String?
    /// Result of tool execution (for tool_result)
    public let toolOutput: String?
    /// Error message if applicable
    public let error: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case timestamp
        case content
        case toolCallId = "tool_call_id"
        case toolName = "tool_name"
        case toolParameters = "tool_parameters"
        case toolOutput = "tool_output"
        case error
    }
    
    public init(
        type: SessionEventType,
        timestamp: Date? = nil,
        content: String? = nil,
        toolCallId: String? = nil,
        toolName: String? = nil,
        toolParameters: String? = nil,
        toolOutput: String? = nil,
        error: String? = nil
    ) {
        self.type = type
        self.timestamp = timestamp
        self.content = content
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.toolParameters = toolParameters
        self.toolOutput = toolOutput
        self.error = error
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        type = try container.decode(SessionEventType.self, forKey: .type)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        toolCallId = try container.decodeIfPresent(String.self, forKey: .toolCallId)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        toolParameters = try container.decodeIfPresent(String.self, forKey: .toolParameters)
        toolOutput = try container.decodeIfPresent(String.self, forKey: .toolOutput)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        
        // Handle timestamp with flexibility for different formats
        if let timestampMs = try? container.decode(Double.self, forKey: .timestamp) {
            // Assume milliseconds if value is large
            if timestampMs > 1_000_000_000_000 {
                timestamp = Date(timeIntervalSince1970: timestampMs / 1000)
            } else {
                timestamp = Date(timeIntervalSince1970: timestampMs)
            }
        } else if let dateString = try? container.decode(String.self, forKey: .timestamp) {
            timestamp = ISO8601DateFormatter().date(from: dateString)
        } else {
            timestamp = nil
        }
    }
    
    /// Parse a Kiro CLI JSONL event (v1 envelope format) into SessionEvent(s).
    /// One JSONL line can produce multiple events (e.g., AssistantMessage with text + toolUse).
    public static func parseKiroEvent(from data: Data) -> [SessionEvent] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = json["kind"] as? String,
              let eventData = json["data"] as? [String: Any] else {
            return []
        }
        
        let contentItems = eventData["content"] as? [[String: Any]] ?? []
        
        switch kind {
        case "Prompt":
            let text = contentItems.compactMap { item -> String? in
                guard item["kind"] as? String == "text" else { return nil }
                return item["data"] as? String
            }.joined()
            return [SessionEvent(type: .userMessage, content: text)]
            
        case "AssistantMessage":
            var events: [SessionEvent] = []
            for item in contentItems {
                switch item["kind"] as? String {
                case "text":
                    if let text = item["data"] as? String {
                        events.append(SessionEvent(type: .agentMessage, content: text))
                    }
                case "toolUse":
                    if let toolData = item["data"] as? [String: Any] {
                        events.append(SessionEvent(
                            type: .toolCall,
                            toolCallId: toolData["toolUseId"] as? String,
                            toolName: toolData["name"] as? String
                        ))
                    }
                default:
                    break
                }
            }
            return events
            
        case "ToolResults":
            return contentItems.compactMap { item -> SessionEvent? in
                guard item["kind"] as? String == "toolResult",
                      let toolData = item["data"] as? [String: Any] else { return nil }
                return SessionEvent(type: .toolResult, toolCallId: toolData["toolUseId"] as? String)
            }
            
        case "TurnEnd":
            return [SessionEvent(type: .turnEnd)]
            
        case "SessionStart":
            return [SessionEvent(type: .sessionStart)]
            
        case "SessionEnd":
            return [SessionEvent(type: .sessionEnd)]
            
        case "Error":
            let msg = contentItems.compactMap { item -> String? in
                guard item["kind"] as? String == "text" else { return nil }
                return item["data"] as? String
            }.joined()
            return [SessionEvent(type: .error, error: msg.isEmpty ? nil : msg)]
            
        default:
            return [SessionEvent(type: .unknown)]
        }
    }
}
