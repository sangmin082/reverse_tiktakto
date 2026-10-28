import Foundation

enum GameResult: Sendable, Equatable {
    /// loser가 자기 말로 line을 완성해 패배
    case lost(Player, line: UInt32)
    case draw

    var winner: Player? {
        if case .lost(let loser, _) = self { return loser.opponent }
        return nil
    }

    var losingLine: [Int] {
        if case .lost(_, let line) = self { return Position.cells(in: line) }
        return []
    }
}

/// 한 판의 진행 상태 (무르기용 기록 포함)
struct Game: Sendable {
    private let start: Position
    private(set) var position: Position
    private(set) var moves: [Int] = []
    private(set) var result: GameResult?

    init(variant: Variant) {
        self.init(position: Position(variant: variant))
    }

    init(position: Position) {
        start = position
        self.position = position
        result = Self.judge(position, lastMover: position.toMove.opponent)
    }

    var variant: Variant { position.variant }
    var toMove: Player { position.toMove }
    var isOver: Bool { result != nil }
    var lastMove: Int? { moves.last }

    func canPlay(_ cell: Int) -> Bool {
        !isOver && (0..<variant.cellCount).contains(cell) && position.isEmpty(cell)
    }

    mutating func play(_ cell: Int) {
        guard canPlay(cell) else { return }
        let mover = position.toMove
        position = position.placing(cell)
        moves.append(cell)
        result = Self.judge(position, lastMover: mover)
    }

    /// 마지막 수 무르기
    mutating func undo() {
        guard !moves.isEmpty else { return }
        moves.removeLast()
        var rebuilt = start
        for cell in moves { rebuilt = rebuilt.placing(cell) }
        position = rebuilt
        result = nil
    }

    private static func judge(_ position: Position, lastMover: Player) -> GameResult? {
        if let line = position.completedLine(of: lastMover) {
            return .lost(lastMover, line: line)
        }
        if let line = position.completedLine(of: lastMover.opponent) {
            return .lost(lastMover.opponent, line: line)
        }
        return position.isFull ? .draw : nil
    }
}
