import UIKit

/// Lightweight haptics helper to centralize feedback generation.
/// Matches existing usage in the codebase (Haptics.selection(), Haptics.notify(_:)).
enum Haptics {
    /// Triggers a subtle selection change haptic.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// Triggers a notification haptic with the given type (e.g., .success, .warning, .error).
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
