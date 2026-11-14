import XCTest
@testable import TicTacCore

final class BotTests: XCTestCase {

    /// 4×4는 서로 최선을 다하면 후공(O)이 이긴다. 빠른 확인을 위해 두 수 둔 국면부터 읽는다.
    func testSecondPlayerWinsAfterMirroredOpening() throws {
        let position = Position(variant: .square4).placing(5).placing(10)
        let analysis = try XCTUnwrap(Bot.analyze(position, maxDepth: 64, timeBudget: 60))
        XCTAssertTrue(analysis.isSolved)
        XCTAssertTrue(analysis.scores.allSatisfy { $0.score < -Search.win / 2 }, "X의 모든 수가 져야 한다")
    }

    func testBotNeverPlaysPoisonWhenSafeMoveExists() {
        // X 차례, 2는 X에게 독
        let position = Position(variant: .square4, layout: "XX../O.../..O./....")
        for level in BotLevel.allCases {
            for _ in 0..<5 {
                XCTAssertNotEqual(Bot.chooseMove(in: position, level: level), 2)
            }
        }
    }

    func testBotPlaysPoisonOnlyWhenForced() {
        // X 차례, 남은 칸 0·1 모두 X의 독 → 어쩔 수 없이 둔다
        let position = Position(variant: .square4, layout: "..OX/OXOX/OXXO/XOXO")
        XCTAssertEqual(position.toMove, .x)
        XCTAssertEqual(position.poisonMask(for: .x), position.emptyMask)
        XCTAssertTrue([0, 1].contains(Bot.chooseMove(in: position, level: .hard)))
    }

    /// 상대가 모두 독 칸만 남게 만드는 수를 찾는다.
    func testHardBotFindsForcedWin() throws {
        let puzzle = Puzzles.all.first { $0.goal == .forceWin }!
        let analysis = try XCTUnwrap(Bot.analyze(puzzle.position, maxDepth: 64, timeBudget: 10))
        let best = try XCTUnwrap(analysis.scores.max { $0.score < $1.score })
        XCTAssertGreaterThan(best.score, Search.win / 2)
        XCTAssertTrue(puzzle.accepts(best.cell))
    }

    /// 빈 판에서도 시간 예산 안에 수를 낸다.
    func testHardRespectsTimeBudget() {
        let start = Date()
        XCTAssertNotNil(Bot.chooseMove(in: Position(variant: .square4), level: .hard))
        XCTAssertLessThan(Date().timeIntervalSince(start), BotLevel.hard.timeBudget + 1.0)
    }

    /// 후공을 잡은 어려움 봇은 절대 지지 않는다.
    func testHardNeverLosesAsSecondPlayer() {
        for opponentLevel in [BotLevel.easy, .normal, .hard] {
            var game = Game(variant: .square4)
            while !game.isOver {
                let level = game.toMove == .o ? BotLevel.hard : opponentLevel
                game.play(Bot.chooseMove(in: game.position, level: level)!)
            }
            XCTAssertNotEqual(game.result?.winner, .x, "vs \(opponentLevel)")
        }
    }

    /// 대칭 전략만으로 무작위 상대를 상대해도 지지 않는다 (탐색 없이 빠르게 여러 판 검증).
    func testMirrorStrategyNeverLoses() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<300 {
                var game = Game(variant: .square4)
                while !game.isOver {
                    if game.toMove == .o {
                        let move = Symmetry.move(in: game.position)
                        XCTAssertNotNil(move)
                        game.play(move!)
                    } else {
                        let safe = Position.cells(in: game.position.emptyMask & ~game.position.poisonMask(for: game.toMove))
                        game.play((safe.isEmpty ? game.position.emptyCells : safe).randomElement(using: &rng)!)
                    }
                }
                XCTAssertNotEqual(game.result?.winner, .x)
        }
    }

    func testMirrorOnlyForSecondPlayer() {
        XCTAssertNil(Symmetry.move(in: Position(variant: .square4)))           // 선공은 대칭 불가
        XCTAssertEqual(Symmetry.move(in: Position(variant: .square4).placing(0)), 15)
        XCTAssertEqual(Symmetry.move(in: Position(variant: .square4).placing(0).placing(15).placing(6)), 9)
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
