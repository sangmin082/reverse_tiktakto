import XCTest
@testable import TicTacCore

final class EngineTests: XCTestCase {

    func testLineCount() {
        // 4×4 3목: 가로8 + 세로8 + 대각4 + 반대각4
        XCTAssertEqual(Variant.square4.lines.count, 24)
    }

    func testCompletingOwnLineLoses() {
        var game = Game(variant: .square4)
        // X: 0,1 / O: 4,5 → X가 2에 두면 첫 줄 0·1·2 완성으로 패배
        for cell in [0, 4, 1, 5] { game.play(cell) }
        XCTAssertNil(game.result)
        game.play(2)
        XCTAssertEqual(game.result, .lost(.x, line: 0b111))
        XCTAssertEqual(game.result?.winner, .o)
        XCTAssertEqual(game.result?.losingLine, [0, 1, 2])
        // 끝난 판에는 더 둘 수 없다
        XCTAssertFalse(game.canPlay(9))
    }

    func testFullBoardWithoutLineIsDraw() {
        // XXOO / OOXX / XXOO / OOXX: 어느 쪽도 3목이 없다
        let target = Position(variant: .square4, layout: "XXOO/OOXX/XXOO/OOXX")
        XCTAssertNil(target.completedLine(of: .x))
        XCTAssertNil(target.completedLine(of: .o))

        var game = Game(variant: .square4)
        let xs = Position.cells(in: target.xMask), os = Position.cells(in: target.oMask)
        for (x, o) in zip(xs, os) {
            game.play(x)
            game.play(o)
        }
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
        let start = Position(variant: .square4, layout: "X.../.O../..../....")
        var game = Game(position: start)
        game.play(15)
        game.undo()
        XCTAssertEqual(game.position, start)
    }

    func testPoisonCells() {
        let position = Position(variant: .square4, layout: "XX../O.../..O./....")
        // X는 2에 두면 첫 줄 0·1·2 완성. O는 아직 3목 직전인 줄이 없다
        XCTAssertEqual(position.toMove, .x)
        XCTAssertEqual(Position.cells(in: position.poisonMask(for: .x)), [2])
        XCTAssertEqual(position.poisonMask(for: .o), 0)
    }

    func testLayoutParsing() {
        let position = Position(variant: .square4, layout: "X.../.O../..../...X")
        XCTAssertEqual(position.player(at: 0), .x)
        XCTAssertEqual(position.player(at: 5), .o)
        XCTAssertEqual(position.player(at: 15), .x)
        XCTAssertEqual(position.stoneCount, 3)
        XCTAssertEqual(position.toMove, .o)
    }
}
