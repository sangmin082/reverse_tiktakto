import SwiftUI

/// 앱 전역 팔레트 — 페이퍼 & 잉크, 버밀리언 악센트 (리버스 체스와 같은 톤).
/// 다크모드 분기 없이 하나의 톤으로 고정한 보드게임 룩.
enum Theme {
    static let paper = Color(red: 0.957, green: 0.945, blue: 0.902)     // 배경
    static let ink = Color(red: 0.106, green: 0.118, blue: 0.149)       // 본문 / X
    static let inkSoft = Color(red: 0.106, green: 0.118, blue: 0.149).opacity(0.55)
    static let accent = Color(red: 0.776, green: 0.263, blue: 0.169)    // 버밀리언: 패배한 줄·위험 칸
    static let hairline = Color(red: 0.106, green: 0.118, blue: 0.149).opacity(0.18)
    static let sea = Color(red: 0.180, green: 0.400, blue: 0.443)       // O

    static let cellLastMove = Color(red: 0.84, green: 0.71, blue: 0.35).opacity(0.28)

    static func color(for player: Player) -> Color {
        player == .x ? ink : sea
    }
}

/// 본문 버튼: 잉크 테두리의 플랫 버튼
struct InkButtonStyle: ButtonStyle {
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .foregroundStyle(filled ? Theme.paper : Theme.ink)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(filled ? Theme.ink : .clear)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.ink, lineWidth: 1.5))
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// 엔진 타입의 화면 표기 (엔진은 UI·현지화와 분리되어 있음)
extension BotLevel {
    var label: LocalizedStringKey {
        switch self {
        case .easy: "쉬움"
        case .normal: "보통"
        case .hard: "어려움"
        }
    }
}

extension Variant {
    var sizeLabel: String { "\(size)×\(size)" }

    var ruleLabel: LocalizedStringKey {
        lineLength == 3 ? "3목이면 패배" : "4목이면 패배"
    }
}
