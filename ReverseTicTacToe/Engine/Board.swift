import Foundation

/// 말 색: X가 항상 선공.
enum Player: Int, Sendable, Hashable, CaseIterable {
    case x, o

    var opponent: Player { self == .x ? .o : .x }
    var symbol: String { self == .x ? "X" : "O" }
}

/// 보드 규격: N×N 판에서 자기 말 K개가 한 줄(가로·세로·대각선)이 되면 패배.
enum Variant: String, Sendable, Hashable, CaseIterable, Identifiable {
    case classic   // 3×3, 3목 패배
    case square4   // 4×4, 3목 패배
    case square5   // 5×5, 4목 패배

    var id: String { rawValue }

    var size: Int {
        switch self {
        case .classic: 3
        case .square4: 4
        case .square5: 5
        }
    }

    var lineLength: Int {
        switch self {
        case .classic, .square4: 3
        case .square5: 4
        }
    }

    var cellCount: Int { size * size }

    /// 판에 존재하는 모든 K칸 직선 (비트마스크)
    var lines: [UInt32] { Geometry.of(self).lines }

    /// 각 칸을 지나는 직선들
    func lines(through cell: Int) -> [UInt32] { Geometry.of(self).linesThrough[cell] }
}

/// 규격별 직선 테이블 — 한 번만 계산해 둔다.
private struct Geometry: Sendable {
    let lines: [UInt32]
    let linesThrough: [[UInt32]]

    static let table: [Variant: Geometry] = Dictionary(
        uniqueKeysWithValues: Variant.allCases.map { ($0, Geometry(variant: $0)) }
    )

    static func of(_ variant: Variant) -> Geometry { table[variant]! }

    init(variant: Variant) {
        let n = variant.size, k = variant.lineLength
        var lines: [UInt32] = []
        let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]
        for row in 0..<n {
            for col in 0..<n {
                for (dr, dc) in directions {
                    let endRow = row + dr * (k - 1), endCol = col + dc * (k - 1)
                    guard (0..<n).contains(endRow), (0..<n).contains(endCol) else { continue }
                    var mask: UInt32 = 0
                    for step in 0..<k {
                        mask |= 1 << UInt32((row + dr * step) * n + col + dc * step)
                    }
                    lines.append(mask)
                }
            }
        }
        self.lines = lines
        self.linesThrough = (0..<n * n).map { cell in
            lines.filter { $0 & (1 << UInt32(cell)) != 0 }
        }
    }
}

/// 불변 국면. 비트마스크 두 개로 X/O 위치를 표현한다.
struct Position: Sendable, Hashable {
    let variant: Variant
    private(set) var xMask: UInt32 = 0
    private(set) var oMask: UInt32 = 0

    init(variant: Variant) {
        self.variant = variant
    }

    /// 테스트·튜토리얼용: "X.O/..X/O.." 처럼 행을 '/'로 구분한 문자열로 국면 생성
    init(variant: Variant, layout: String) {
        self.variant = variant
        let cells = layout.filter { $0 != "/" && $0 != " " }
        precondition(cells.count == variant.cellCount, "layout 칸 수가 맞지 않습니다")
        for (index, char) in cells.enumerated() {
            switch char {
            case "X", "x": xMask |= 1 << UInt32(index)
            case "O", "o": oMask |= 1 << UInt32(index)
            default: break
            }
        }
    }

    var occupied: UInt32 { xMask | oMask }
    var fullMask: UInt32 { variant.cellCount == 32 ? .max : (1 << UInt32(variant.cellCount)) - 1 }
    var emptyMask: UInt32 { fullMask & ~occupied }
    var isFull: Bool { emptyMask == 0 }
    var stoneCount: Int { occupied.nonzeroBitCount }

    /// 둘 차례: X가 선공이므로 돌 수로 결정된다.
    var toMove: Player { xMask.nonzeroBitCount == oMask.nonzeroBitCount ? .x : .o }

    func mask(of player: Player) -> UInt32 { player == .x ? xMask : oMask }

    func player(at cell: Int) -> Player? {
        let bit: UInt32 = 1 << UInt32(cell)
        if xMask & bit != 0 { return .x }
        if oMask & bit != 0 { return .o }
        return nil
    }

    func isEmpty(_ cell: Int) -> Bool { emptyMask & (1 << UInt32(cell)) != 0 }

    var emptyCells: [Int] { Self.cells(in: emptyMask) }

    func placing(_ cell: Int) -> Position {
        precondition(isEmpty(cell), "이미 말이 있는 칸입니다")
        var next = self
        if toMove == .x { next.xMask |= 1 << UInt32(cell) } else { next.oMask |= 1 << UInt32(cell) }
        return next
    }

    /// player가 cell에 두면 완성되는 직선 (없으면 nil) — 그 칸은 player에게 '독'이다.
    func completedLine(if player: Player, places cell: Int) -> UInt32? {
        let mine = mask(of: player) | (1 << UInt32(cell))
        return variant.lines(through: cell).first { $0 & mine == $0 }
    }

    func isPoison(_ cell: Int, for player: Player) -> Bool {
        completedLine(if: player, places: cell) != nil
    }

    /// player가 지금 두면 지는 빈칸 전체
    func poisonMask(for player: Player) -> UInt32 {
        var result: UInt32 = 0
        for cell in emptyCells where isPoison(cell, for: player) {
            result |= 1 << UInt32(cell)
        }
        return result
    }

    /// player의 말로 이미 완성된 직선
    func completedLine(of player: Player) -> UInt32? {
        let mine = mask(of: player)
        return variant.lines.first { $0 & mine == $0 }
    }

    static func cells(in mask: UInt32) -> [Int] {
        var cells: [Int] = []
        var rest = mask
        while rest != 0 {
            cells.append(rest.trailingZeroBitCount)
            rest &= rest - 1
        }
        return cells
    }
}
