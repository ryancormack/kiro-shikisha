import Foundation

/// Codec for encoding and decoding JSON-RPC messages over newline-delimited streams
public struct ACPMessageCodec: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    public init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }
    
    /// Encode a message to JSON data with a trailing newline (for stream protocol)
    /// - Parameter message: The Encodable message to encode
    /// - Returns: JSON data followed by a newline byte
    public func encode<T: Encodable>(_ message: T) throws -> Data {
        var data = try encoder.encode(message)
        data.append(contentsOf: [UInt8(ascii: "\n")])
        return data
    }
    
    /// Decode a message from JSON data
    /// - Parameter data: The JSON data to decode
    /// - Returns: The decoded message
    public func decode<T: Decodable>(_ data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
    
    /// Parse newline-delimited JSON from a data buffer, returning complete messages and remaining data
    /// - Parameter buffer: The accumulated data buffer
    /// - Returns: Tuple of (complete messages as Data arrays, remaining incomplete data)
    public func parseMessages(from buffer: Data) -> (messages: [Data], remaining: Data) {
        var messages: [Data] = []
        var remaining = buffer
        
        while let newlineIndex = remaining.firstIndex(of: UInt8(ascii: "\n")) {
            let messageData = remaining[remaining.startIndex..<newlineIndex]
            // Skip empty lines
            if !messageData.isEmpty {
                messages.append(Data(messageData))
            }
            remaining = Data(remaining[remaining.index(after: newlineIndex)...])
        }
        
        return (messages, remaining)
    }
}
