import Foundation

#if os(macOS)
import SwiftUI

/// A dismissible error banner with optional retry action
public struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    @State private var isVisible: Bool = true
    
    /// Creates an error banner with a message and dismiss action
    /// - Parameters:
    ///   - message: The error message to display
    ///   - onDismiss: Closure called when the banner is dismissed
    ///   - onRetry: Optional closure called when the retry button is tapped
    public init(
        message: String,
        onDismiss: @escaping () -> Void,
        onRetry: (() -> Void)? = nil
    ) {
        self.message = message
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }
    
    public var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                // Error message
                Text(message)
                    .font(.callout)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    if let onRetry = onRetry {
                        Button {
                            onRetry()
                        } label: {
                            Text("Retry")
                                .font(.callout.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Dismiss button
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isVisible = false
                        }
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.9), Color.orange.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// A container view that displays error banners at the top
public struct ErrorBannerContainer<Content: View>: View {
    @Binding var errors: [ErrorItem]
    let content: Content
    
    public init(
        errors: Binding<[ErrorItem]>,
        @ViewBuilder content: () -> Content
    ) {
        self._errors = errors
        self.content = content()
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            content
            
            VStack(spacing: 8) {
                ForEach(errors) { error in
                    ErrorBanner(
                        message: error.message,
                        onDismiss: {
                            withAnimation {
                                errors.removeAll { $0.id == error.id }
                            }
                        },
                        onRetry: error.retryAction
                    )
                }
            }
            .padding()
        }
    }
}

#Preview("Error Banner") {
    VStack(spacing: 20) {
        ErrorBanner(
            message: "Failed to connect to kiro-cli",
            onDismiss: { print("Dismissed") },
            onRetry: { print("Retry") }
        )
        
        ErrorBanner(
            message: "Network connection lost",
            onDismiss: { print("Dismissed") }
        )
        
        ErrorBanner(
            message: "This is a longer error message that might wrap to multiple lines if the window is narrow enough",
            onDismiss: { print("Dismissed") },
            onRetry: { print("Retry") }
        )
    }
    .padding()
    .frame(width: 500)
}

#Preview("Error Banner Container") {
    struct PreviewContent: View {
        @State private var errors: [ErrorItem] = [
            ErrorItem(message: "Failed to connect to agent"),
            ErrorItem(message: "Session expired", retryAction: { print("Retry") })
        ]
        
        var body: some View {
            ErrorBannerContainer(errors: $errors) {
                VStack {
                    Text("Main Content")
                        .font(.title)
                    Text("Errors will appear at the top")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 500, height: 300)
        }
    }
    
    return PreviewContent()
}
#endif

/// Model for error items displayed in the banner container
public struct ErrorItem: Identifiable {
    public let id: UUID
    public let message: String
    public let retryAction: (() -> Void)?
    
    public init(
        id: UUID = UUID(),
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.id = id
        self.message = message
        self.retryAction = retryAction
    }
}
