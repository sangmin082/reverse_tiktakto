import XCTest
@testable import TicTacCore

final class EngineTests: XCTestCase {

    func testLineCounts() {
        // 3×3 3목: 가로3 + 세로3 + 대각2
        XCTAssertEqual(Variant.classic.lines.count, 8)
        // 4×4 3목: 가로8 + 세로8 + 대각4 + 반대각4
        XCTAssertEqual(Variant.square4.lines.count, 24)
        // 5×5 4목: 가로10 + 세로10 + 대각4 + 반대각4
        XCTAssertEqual(Variant.square5.lines.count, 28)
    }

    func testCompletingOwnLineLoses() {
        var game = Game(variant: .classic)
        // X: 0,1 / O: 3,4 → X가 2에 두면 첫 줄 완성으로 패배
        for cell in [0, 3, 1, 4] { game.play(cell) }
        XCTAssertNil(game.result)
        game.play(2)
        XCTAssertEqual(game.result, .lost(.x, line: 0b111))
        XCTAssertEqual(game.result?.winner, .o)
        XCTAssertEqual(game.result?.losingLine, [0, 1, 2])
        // 끝난 판에는 더 둘 수 없다
        XCTAssertFalse(game.canPlay(5))
    }

    func testFullBoardWithoutLineIsDraw() {
        // X O X / X O O / O X X 순으로 채우면 아무도 3목이 없다
        var game = Game(variant: .classic)
        for cell in [0, 1, 2, 4, 3, 5, 7, 6, 8] { game.play(cell) }
        XCTAssertEqual(game.result, .draw)
    }

    func testUndoRestoresPosition() {
        var game = Game(variant: .square4)
        game.play(5)
        game.play(6)
        let before = game.position
        game.play(9)
        game.undo()
        XCTAssertEqual(game.position, before)
        XCTAssertEqual(game.toMove, .x)
    }

    func testUndoKeepsCustomStartPosition() {
        let start = Position(variant: .classic, layout: "X../.O./...")
        var game = Game(position: start)
        game.play(8)
        game.undo()
        XCTAssertEqual(game.position, start)
    }

    func testPoisonCells() {
        let position = Position(variant: .classic, layout: "XX./O../O..")
        // X는 2에 두면 첫 줄 완성. O의 세로줄(0·3·6)은 0을 X가 막고 있다
        XCTAssertEqual(position.toMove, .x)
        XCTAssertEqual(Position.cells(in: position.poisonMask(for: .x)), [2])
        XCTAssertEqual(position.poisonMask(for: .o), 0)
    }

    func testLayoutParsing() {
        let position = Position(variant: .square5, layout: "X..../.O.../...../...../....X")
        XCTAssertEqual(position.player(at: 0), .x)
        XCTAssertEqual(position.player(at: 6), .o)
        XCTAssertEqual(position.player(at: 24), .x)
        XCTAssertEqual(position.stoneCount, 3)
        XCTAssertEqual(position.toMove, .o)
    }
}
