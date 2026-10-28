import Foundation

/// 배우기 미션: 주어진 국면에서 조건을 만족하는 수를 찾는다.
/// 정답 판정은 엔진이 끝까지 읽어서 하므로 정답이 여러 개여도 된다.
struct Puzzle: Identifiable, Sendable {
    enum Goal: Sendable {
        /// 자기 줄을 완성하지 않는 칸이면 정답
        case avoidPoison
        /// 끝까지 읽었을 때 지지 않는 칸
        case avoidLoss
        /// 끝까지 읽었을 때 이기는 칸
        case forceWin
    }

    let id: Int
    /// 화면에 보일 문구의 현지화 키
    let title: String
    let prompt: String
    let position: Position
    let goal: Goal

    func accepts(_ cell: Int) -> Bool {
        guard position.isEmpty(cell) else { return false }
        if goal == .avoidPoison { return !position.isPoison(cell, for: position.toMove) }
        guard
              let analysis = Bot.analyze(position, maxDepth: 64, timeBudget: 5),
              let score = analysis.scores.first(where: { $0.cell == cell })?.score
        else { return false }
        switch goal {
        case .avoidPoison: return true
        case .avoidLoss: return score > -Search.win / 2
        case .forceWin: return score > Search.win / 2
        }
    }
}

enum Puzzles {
    static let all: [Puzzle] = [
        Puzzle(
            id: 1,
            title: "줄을 만들면 진다",
            prompt: "당신은 X입니다. 자기 말 3개가 한 줄이 되면 집니다. 줄이 완성되지 않는 칸에 두세요.",
            position: Position(variant: .classic, layout: "XX./O../..O"),
            goal: .avoidPoison
        ),
        Puzzle(
            id: 2,
            title: "숨은 함정",
            prompt: "당장은 안전해 보여도 두 수 뒤에 몰리는 칸이 있습니다. 끝까지 버틸 수 있는 단 하나의 칸을 찾으세요.",
            position: Position(variant: .classic, layout: ".../.OO/X.X"),
            goal: .avoidLoss
        ),
        Puzzle(
            id: 3,
            title: "몰아붙이기",
            prompt: "당신은 O입니다. 상대에게 둘 곳이 '지는 칸'뿐이도록 만드세요.",
            position: Position(variant: .classic, layout: "..X/XX./OO."),
            goal: .forceWin
        ),
        Puzzle(
            id: 4,
            title: "4×4 끝내기",
            prompt: "넓은 판에서도 원리는 같습니다. 당신은 O, 이기는 한 수를 찾으세요.",
            position: Position(variant: .square4, layout: "..OO/OOXX/XX../OX.X"),
            goal: .forceWin
        ),
    ]
}
