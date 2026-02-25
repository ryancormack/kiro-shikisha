import Foundation

/// JSON-RPC 2.0 protocol message types for ACP communication

/// Protocol for all JSON-RPC messages
public protocol JSONRPCMessage: Codable, Sendable {}

/// JSON-RPC 2.0 Request
public struct JSONRPCRequest<Params: Codable & Sendable>: JSONRPCMessage {
    public let jsonrpc: String = "2.0"
    public let id: Int
    public let method: String
    public let params: Params?
    
    public init(id: Int, method: String, params: Params? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
    
    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        method = try container.decode(String.self, forKey: .method)
        params = try container.decodeIfPresent(Params.self, forKey: .params)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        if let params = params {
            try container.encode(params, forKey: .params)
        }
    }
}

/// JSON-RPC 2.0 Response
public struct JSONRPCResponse<Result: Codable & Sendable>: JSONRPCMessage {
    public let jsonrpc: String
    public let id: Int?
    public let result: Result?
    public let error: JSONRPCError?
    
    public init(id: Int?, result: Result?, error: JSONRPCError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }
    
    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, result, error
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        result = try container.decodeIfPresent(Result.self, forKey: .result)
        error = try container.decodeIfPresent(JSONRPCError.self, forKey: .error)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encodeIfPresent(id, forKey: .id)
        if let result = result {
            try container.encode(result, forKey: .result)
        }
        if let error = error {
            try container.encode(error, forKey: .error)
        }
    }
}

/// JSON-RPC 2.0 Notification (no id field)
public struct JSONRPCNotification<Params: Codable & Sendable>: JSONRPCMessage {
    public let jsonrpc: String
    public let method: String
    public let params: Params?
    
    public init(method: String, params: Params? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }
    
    enum CodingKeys: String, CodingKey {
        case jsonrpc, method, params
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        method = try container.decode(String.self, forKey: .method)
        params = try container.decodeIfPresent(Params.self, forKey: .params)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(method, forKey: .method)
        if let params = params {
            try container.encode(params, forKey: .params)
        }
    }
}

/// JSON-RPC 2.0 Error object
public struct JSONRPCError: Codable, Sendable, Error {
    public let code: Int
    public let message: String
    public let data: JSONValue?
    
    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
    
    // Standard JSON-RPC error codes
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603
}

/// Type-safe JSON value wrapper for arbitrary JSON data
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: JSONValue].self) {
            self = .object(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSONValue")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}
