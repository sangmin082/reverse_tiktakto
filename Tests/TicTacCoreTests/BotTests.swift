import XCTest
@testable import TicTacCore

final class BotTests: XCTestCase {

    /// 3×3 리버스 틱택토는 서로 최선을 다하면 무승부다.
    func testClassicIsDrawWithPerfectPlay() throws {
        let analysis = try XCTUnwrap(Bot.analyze(Position(variant: .classic), maxDepth: 64, timeBudget: 30))
        XCTAssertTrue(analysis.isSolved)
        XCTAssertEqual(analysis.scores.map(\.score).max(), 0)
    }

    /// 선공이 가운데에 두면 질 수 없다 (대칭 전략).
    func testCenterOpeningNeverLoses() throws {
        let analysis = try XCTUnwrap(Bot.analyze(Position(variant: .classic), maxDepth: 64, timeBudget: 30))
        let center = try XCTUnwrap(analysis.scores.first { $0.cell == 4 })
        XCTAssertEqual(center.score, 0)
    }

    func testBotNeverPlaysPoisonWhenSafeMoveExists() {
        // X 차례, 2는 X에게 독
        let position = Position(variant: .classic, layout: "XX./O../O..")
        for level in BotLevel.allCases {
            for _ in 0..<20 {
                XCTAssertNotEqual(Bot.chooseMove(in: position, level: level), 2)
            }
        }
    }

    func testBotPlaysPoisonOnlyWhenForced() {
        // X 차례, 남은 칸 8은 X의 독 → 어쩔 수 없이 둔다
        let position = Position(variant: .classic, layout: "XOO/XXO/OX.")
        XCTAssertEqual(position.toMove, .x)
        XCTAssertEqual(position.poisonMask(for: .x), position.emptyMask)
        XCTAssertEqual(Bot.chooseMove(in: position, level: .hard), 8)
    }

    /// 상대가 모두 독 칸만 남게 만드는 수를 찾는다.
    func testHardBotFindsForcedWin() throws {
        let puzzle = Puzzles.all.first { $0.goal == .forceWin }!
        let analysis = try XCTUnwrap(Bot.analyze(puzzle.position, maxDepth: 64, timeBudget: 10))
        let best = try XCTUnwrap(analysis.scores.max { $0.score < $1.score })
        XCTAssertGreaterThan(best.score, Search.win / 2)
        XCTAssertTrue(puzzle.accepts(best.cell))
    }

    /// 어려움 봇 끼리 3×3을 두면 항상 무승부
    func testHardSelfPlayDrawsOnClassic() {
        for _ in 0..<10 {
            var game = Game(variant: .classic)
            while !game.isOver {
                game.play(Bot.chooseMove(in: game.position, level: .hard)!)
            }
            XCTAssertEqual(game.result, .draw)
        }
    }

    /// 큰 판에서도 시간 예산 안에 수를 낸다.
    func testLargerBoardsRespectTimeBudget() {
        for variant in [Variant.square4, .square5] {
            let start = Date()
            let move = Bot.chooseMove(in: Position(variant: variant), level: .hard)
            XCTAssertNotNil(move)
            XCTAssertLessThan(Date().timeIntervalSince(start), BotLevel.hard.timeBudget + 1.0)
        }
    }

    /// 대칭 전략 쪽(4×4 후공, 5×5 선공)을 잡은 어려움 봇은 절대 지지 않는다.
    func testHardNeverLosesOnMirrorSide() {
        for (variant, hardSide) in [(Variant.square4, Player.o), (.square5, .x)] {
            for opponentLevel in [BotLevel.easy, .normal] {
                var game = Game(variant: variant)
                while !game.isOver {
                    let level = game.toMove == hardSide ? BotLevel.hard : opponentLevel
                    game.play(Bot.chooseMove(in: game.position, level: level)!)
                }
                XCTAssertNotEqual(game.result?.winner, hardSide.opponent, "\(variant) vs \(opponentLevel)")
            }
        }
    }

    /// 대칭 전략만으로 무작위 상대를 상대해도 지지 않는다 (탐색 없이 빠르게 여러 판 검증).
    func testMirrorStrategyNeverLoses() {
        var rng = SystemRandomNumberGenerator()
        for (variant, side) in [(Variant.square4, Player.o), (.square5, .x)] {
            for _ in 0..<300 {
                var game = Game(variant: variant)
                while !game.isOver {
                    if game.toMove == side {
                        let move = Symmetry.move(in: game.position)
                        XCTAssertNotNil(move)
                        game.play(move!)
                    } else {
                        let safe = Position.cells(in: game.position.emptyMask & ~game.position.poisonMask(for: game.toMove))
                        game.play((safe.isEmpty ? game.position.emptyCells : safe).randomElement(using: &rng)!)
                    }
                }
                XCTAssertNotEqual(game.result?.winner, side.opponent)
            }
        }
    }

    func testMirrorUnavailableOnClassicOrWrongSide() {
        XCTAssertNil(Symmetry.move(in: Position(variant: .classic)))
        XCTAssertNil(Symmetry.move(in: Position(variant: .square4)))           // 4×4 선공은 대칭 불가
        XCTAssertEqual(Symmetry.move(in: Position(variant: .square5)), 12)     // 5×5 선공은 가운데부터
        XCTAssertEqual(Symmetry.move(in: Position(variant: .square4).placing(0)), 15)
    }

    func testAllPuzzlesAreSoundAndUnique() throws {
        for puzzle in Puzzles.all {
            let analysis = try XCTUnwrap(Bot.analyze(puzzle.position, maxDepth: 64, timeBudget: 10))
            XCTAssertTrue(analysis.isSolved, puzzle.title)
            let accepted = analysis.scores.filter { puzzle.accepts($0.cell) }
            XCTAssertFalse(accepted.isEmpty, puzzle.title)
            XCTAssertLessThan(accepted.count, analysis.scores.count, "\(puzzle.title): 모든 수가 정답이면 퍼즐이 아니다")
        }
    }
}
