import Foundation
import ACPModel
import ACP

/// Client implementation for KiroShikisha that conforms to the ACP SDK's Client protocol.
///
/// This client provides capabilities information and receives session updates
/// from the agent, which are then forwarded to the callback handler.
public final class KiroClient: Client, @unchecked Sendable {
    /// Callback invoked when a session update is received
    public var onSessionUpdateCallback: (@Sendable (SessionUpdate) async -> Void)?
    
    /// Callback invoked when connected to the agent
    public var onConnectedCallback: (@Sendable () async -> Void)?
    
    /// Callback invoked when disconnected from the agent
    public var onDisconnectedCallback: (@Sendable (Error?) async -> Void)?
    
    public init() {}
    
    // MARK: - Client Protocol
    
    public var capabilities: ClientCapabilities {
        ClientCapabilities(
            fs: FileSystemCapability(readTextFile: true, writeTextFile: true),
            terminal: true
        )
    }
    
    public var info: Implementation? {
        Implementation(name: "KiroShikisha", version: "1.0.0")
    }
    
    public func onSessionUpdate(_ update: SessionUpdate) async {
        await onSessionUpdateCallback?(update)
    }
    
    public func onConnected() async {
        await onConnectedCallback?()
    }
    
    public func onDisconnected(error: Error?) async {
        await onDisconnectedCallback?(error)
    }
}
