import UIKit

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func move() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func capture() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func failure() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
