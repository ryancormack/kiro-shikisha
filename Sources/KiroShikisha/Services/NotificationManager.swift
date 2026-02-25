#if os(macOS)
@preconcurrency import UserNotifications
import Foundation

/// Service for managing macOS notifications for agent events
@MainActor
public final class NotificationManager {
    /// Shared singleton instance
    public static let shared = NotificationManager()
    
    /// Whether notification permission has been granted
    private var isAuthorized = false
    
    private init() {}
    
    // MARK: - Permission Management
    
    /// Request permission to send notifications
    /// - Returns: True if permission was granted
    @discardableResult
    public func requestPermission() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("NotificationManager: Failed to request permission: \(error)")
            return false
        }
    }
    
    /// Check current authorization status
    public func checkAuthorizationStatus() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        return isAuthorized
    }
    
    // MARK: - Sending Notifications
    
    /// Send a local notification
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body text
    ///   - identifier: Optional unique identifier (auto-generated if nil)
    public func sendNotification(title: String, body: String, identifier: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let requestId = identifier ?? UUID().uuidString
        let request = UNNotificationRequest(
            identifier: requestId,
            content: content,
            trigger: nil  // Deliver immediately
        )
        
        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error = error {
                print("NotificationManager: Failed to send notification: \(error)")
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Notify when an agent encounters an error
    /// - Parameters:
    ///   - agentName: Name of the agent
    ///   - error: Error description
    public func notifyAgentError(agentName: String, error: String) {
        sendNotification(
            title: "Agent Error: \(agentName)",
            body: error,
            identifier: "agent-error-\(agentName)-\(Date().timeIntervalSince1970)"
        )
    }
    
    /// Notify when an agent completes a task
    /// - Parameters:
    ///   - agentName: Name of the agent
    ///   - message: Completion message
    public func notifyAgentComplete(agentName: String, message: String) {
        sendNotification(
            title: "Agent Complete: \(agentName)",
            body: message,
            identifier: "agent-complete-\(agentName)-\(Date().timeIntervalSince1970)"
        )
    }
    
    /// Notify when an agent needs user input
    /// - Parameter agentName: Name of the agent
    public func notifyAgentNeedsInput(agentName: String) {
        sendNotification(
            title: "Agent Waiting: \(agentName)",
            body: "Agent is waiting for your input",
            identifier: "agent-needs-input-\(agentName)-\(Date().timeIntervalSince1970)"
        )
    }
    
    // MARK: - Notification Management
    
    /// Remove all pending notifications for a specific agent
    /// - Parameter agentName: Name of the agent
    public func removeNotifications(for agentName: String) {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { notifications in
            let identifiersToRemove = notifications
                .filter { $0.request.identifier.contains(agentName) }
                .map { $0.request.identifier }
            center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
        }
    }
    
    /// Remove all notifications from this app
    public func removeAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }
}
#endif
