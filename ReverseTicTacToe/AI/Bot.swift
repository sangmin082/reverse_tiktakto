import Foundation

enum BotLevel: String, CaseIterable, Identifiable, Sendable {
    case easy, normal, hard

    var id: String { rawValue }

    /// 탐색 깊이 상한 (어려움은 시간이 허락하는 한 끝까지)
    var maxDepth: Int {
        switch self {
        case .easy: 2
        case .normal: 4
        case .hard: 64
        }
    }

    /// 한 수에 쓸 수 있는 생각 시간
    var timeBudget: TimeInterval {
        switch self {
        case .easy: 0.2
        case .normal: 0.4
        case .hard: 1.2
        }
    }

    /// 최선이 아닌 수를 고를 확률 (%)
    var blunderRate: Int {
        switch self {
        case .easy: 40
        case .normal: 12
        case .hard: 0
        }
    }
}

/// 리버스 틱택토 AI — 네가맥스 + 알파베타 + 치환표, 반복 심화.
/// 자기 줄을 완성하는 '독' 칸은 다른 수가 없을 때만 두므로 실제 분기 수가 크게 줄어든다.
enum Bot {

    static func chooseMove(
        in position: Position, level: BotLevel,
        using rng: inout some RandomNumberGenerator
    ) -> Int? {
        let analysis = analyze(position, maxDepth: level.maxDepth, timeBudget: level.timeBudget)
        guard var scored = analysis?.scores, !scored.isEmpty else { return nil }

        scored.shuffle(using: &rng)
        scored.sort { $0.score > $1.score }
        let best = scored[0].score

        // 어려움: 확실한 승리가 없으면 대칭 전략으로 절대 지지 않는 수를 둔다
        if level == .hard, best <= Search.win / 2, let mirror = Symmetry.move(in: position) {
            return mirror
        }

        if level.blunderRate > 0, scored.count > 1, Int.random(in: 0..<100, using: &rng) < level.blunderRate {
            // 쉬움은 아무 안전한 수나, 보통은 크게 손해 보지 않는 수 중에서 고른다.
            // 어느 쪽이든 자기 줄을 바로 완성하는 수(-win)는 고르지 않는다.
            let pool = level == .easy
                ? scored.filter { $0.score > -Search.win / 2 }
                : scored.filter { $0.score >= best - 40 && $0.score > -Search.win }
            if let pick = pool.randomElement(using: &rng) { return pick.cell }
        }

        // 동점인 최선 수 중 무작위 (shuffle 후 안정 정렬이므로 첫 원소가 곧 무작위 최선수)
        return scored[0].cell
    }

    static func chooseMove(in position: Position, level: BotLevel) -> Int? {
        var rng = SystemRandomNumberGenerator()
        return chooseMove(in: position, level: level, using: &rng)
    }

    struct Analysis {
        /// 둘 수 있는 각 칸의 점수 (둘 차례 기준, 클수록 좋음)
        var scores: [(cell: Int, score: Int)]
        /// 끝까지 읽어 결과가 확정되었는지
        var isSolved: Bool
        var depth: Int
    }

    /// 반복 심화로 루트의 모든 수를 평가한다. 시간이 다 되면 마지막으로 끝난 깊이의 결과를 쓴다.
    static func analyze(_ position: Position, maxDepth: Int, timeBudget: TimeInterval) -> Analysis? {
        let me = position.toMove
        let empties = position.emptyCells
        guard !empties.isEmpty else { return nil }

        let poison = position.poisonMask(for: me)
        let safe = empties.filter { poison & (1 << UInt32($0)) == 0 }
        // 안전한 칸이 없으면 어디에 두든 진다
        guard !safe.isEmpty else {
            return Analysis(scores: empties.map { ($0, -Search.win) }, isSolved: true, depth: 0)
        }

        var search = Search(deadline: Date().addingTimeInterval(timeBudget))
        var completed: Analysis?
        let limit = min(maxDepth, empties.count)

        for depth in 1...limit {
            var scores: [(cell: Int, score: Int)] = []
            do {
                for cell in safe {
                    let score = -(try search.negamax(
                        position.placing(cell), depth: depth - 1,
                        alpha: -Search.infinity, beta: Search.infinity, ply: 1
                    ))
                    scores.append((cell, score))
                }
            } catch {
                break // 시간 초과: 이전 깊이 결과 사용
            }
            // 끝까지 읽었거나 모든 수의 승패가 이미 확정되었으면 더 읽을 필요 없음
            let solved = depth >= empties.count || scores.allSatisfy { abs($0.score) > Search.win / 2 }
            completed = Analysis(scores: scores, isSolved: solved, depth: depth)
            if solved { break }
        }

        // 독 칸은 즉시 패배로 덧붙인다 (안전한 칸이 있으므로 선택되지 않음)
        if var result = completed {
            result.scores += empties.filter { poison & (1 << UInt32($0)) != 0 }.map { ($0, -Search.win) }
            return result
        }
        // 깊이 1조차 못 끝낸 경우: 안전한 칸 중 아무거나
        return Analysis(scores: safe.map { ($0, 0) }, isSolved: false, depth: 0)
    }
}

/// 점대칭 전략.
/// 짝수 판에서는 후공이, 홀수 판에서는 가운데를 차지한 선공이 상대 수를 판 중심에 대해
/// 뒤집어 따라 두면 절대 먼저 줄을 완성하지 않는다: 내 줄이 생긴다면 그 거울상인
/// 상대 줄이 한 수 먼저 완성되었어야 하기 때문이다. 단, 거울상이 자기 자신인 줄
/// (홀수 판의 가운데를 지나는 줄)이 있으면 성립하지 않으므로 3×3에는 쓰지 않는다.
enum Symmetry {
    static func mirror(_ cell: Int, in variant: Variant) -> Int {
        variant.cellCount - 1 - cell
    }

    /// 대칭 전략을 이어갈 수 있으면 그 수를, 아니면 nil
    static func move(in position: Position) -> Int? {
        let variant = position.variant
        let me = position.toMove
        guard variant.size > 3 else { return nil }

        let isOdd = variant.size % 2 == 1
        // 대칭 전략을 쓸 수 있는 쪽: 짝수 판은 후공(O), 홀수 판은 선공(X)
        guard me == (isOdd ? .x : .o) else { return nil }

        let center = variant.cellCount / 2
        if isOdd {
            if position.isEmpty(center) { return position.stoneCount == 0 ? center : nil }
            guard position.player(at: center) == me else { return nil }
        }

        var reply: Int?
        for cell in 0..<variant.cellCount where !(isOdd && cell == center) {
            let mirrored = mirror(cell, in: variant)
            switch (position.player(at: cell), position.player(at: mirrored)) {
            case (me?, let other):
                guard other == me.opponent else { return nil }
            case (me.opponent?, nil):
                // 상대가 방금 둔 수: 거울 자리가 비어 있는 상대 돌은 정확히 하나여야 한다
                guard reply == nil || reply == mirrored else { return nil }
                reply = mirrored
            case (me.opponent?, me.opponent?):
                return nil
            default:
                break
            }
        }
        return reply
    }
}

/// 탐색 본체. 점수는 둘 차례 기준이며 승패 점수는 빠른 승리/느린 패배를 선호하도록 수 거리를 반영한다.
struct Search {
    static let win = 10_000
    static let infinity = 1_000_000

    struct Timeout: Error {}

    private enum Bound { case exact, lower, upper }
    private struct Entry { var depth: Int; var score: Int; var bound: Bound }

    let deadline: Date
    private var table: [UInt64: Entry] = [:]
    private var nodes = 0

    init(deadline: Date) {
        self.deadline = deadline
    }

    mutating func negamax(_ position: Position, depth: Int, alpha: Int, beta: Int, ply: Int) throws -> Int {
        nodes += 1
        if nodes & 1023 == 0, Date() >= deadline { throw Timeout() }

        let empty = position.emptyMask
        if empty == 0 { return 0 } // 판이 다 찼으면 무승부

        let me = position.toMove
        let poison = position.poisonMask(for: me)
        let safe = empty & ~poison
        // 둘 곳이 독뿐이면 다음 수에 패배
        if safe == 0 { return -(Search.win - ply - 1) }
        if depth <= 0 { return Self.evaluate(position, safe: safe) }

        let key = UInt64(position.xMask) | UInt64(position.oMask) << 32
        var alpha = alpha, beta = beta
        if let entry = table[key], entry.depth >= depth {
            let score = Self.fromTable(entry.score, ply: ply)
            switch entry.bound {
            case .exact: return score
            case .lower: alpha = max(alpha, score)
            case .upper: beta = min(beta, score)
            }
            if alpha >= beta { return score }
        }

        let originalAlpha = alpha
        var best = -Search.infinity
        for cell in Position.cells(in: safe) {
            let score = -(try negamax(
                position.placing(cell), depth: depth - 1,
                alpha: -beta, beta: -alpha, ply: ply + 1
            ))
            if score > best { best = score }
            if best > alpha { alpha = best }
            if alpha >= beta { break }
        }

        let bound: Bound = best <= originalAlpha ? .upper : (best >= beta ? .lower : .exact)
        table[key] = Entry(depth: depth, score: Self.toTable(best, ply: ply), bound: bound)
        return best
    }

    /// 수 거리 보정: 치환표에는 '현재 노드 기준' 승패 거리를 저장한다.
    private static func toTable(_ score: Int, ply: Int) -> Int {
        if score > win / 2 { return score + ply }
        if score < -win / 2 { return score - ply }
        return score
    }

    private static func fromTable(_ score: Int, ply: Int) -> Int {
        if score > win / 2 { return score - ply }
        if score < -win / 2 { return score + ply }
        return score
    }

    /// 정적 평가: 남은 '안전한 칸'을 누가 더 오래 쓸 수 있는가.
    /// 나만 쓸 수 있는 칸, 상대만 쓸 수 있는 칸, 둘 다 쓸 수 있는 칸을 세어
    /// 번갈아 둘 때 내가 먼저 바닥나는지 어림한다.
    static func evaluate(_ position: Position, safe: UInt32) -> Int {
        let theirPoison = position.poisonMask(for: position.toMove.opponent)
        let empty = position.emptyMask
        let theirSafe = empty & ~theirPoison

        let onlyMine = (safe & ~theirSafe).nonzeroBitCount
        let onlyTheirs = (theirSafe & ~safe).nonzeroBitCount
        let shared = (safe & theirSafe).nonzeroBitCount

        // 내가 먼저 두므로 공유 칸은 내가 반올림해서 가져간다
        let myMoves = onlyMine + (shared + 1) / 2
        let theirMoves = onlyTheirs + shared / 2
        // 둘 다 같은 수만큼 남으면 내가 먼저 바닥난다
        return (myMoves - theirMoves) * 30 - 15
    }
}
