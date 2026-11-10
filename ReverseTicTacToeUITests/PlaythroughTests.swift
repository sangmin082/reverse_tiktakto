import XCTest

/// 시뮬레이터에서 실제로 앱을 눌러 보며 주요 흐름을 확인하고 스크린샷을 남긴다.
/// 스크린샷은 xcresult 첨부로 저장되어 ui-tests 워크플로가 아티팩트로 올린다.
final class PlaythroughTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
    }

    // MARK: - 도우미

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func tapButton(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = button(containing: text)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "버튼 없음: \(text)", file: file, line: line)
        element.tap()
    }

    private var status: XCUIElement { app.staticTexts["status"] }

    /// 지금 둘 수 있는 칸 (위험 표시가 없는 칸 우선)
    private func playableCell() -> XCUIElement? {
        let enabled = NSPredicate(format: "identifier BEGINSWITH 'cell-' AND isEnabled == true")
        let safe = NSPredicate(format: "NOT (label CONTAINS '위험') AND NOT (label CONTAINS 'danger')")
        let safeCell = app.buttons.matching(NSCompoundPredicate(andPredicateWithSubpredicates: [enabled, safe])).firstMatch
        if safeCell.exists { return safeCell }
        let anyCell = app.buttons.matching(enabled).firstMatch
        return anyCell.exists ? anyCell : nil
    }

    private var isGameOver: Bool { button(containing: "한 판 더").exists }

    /// 내 차례가 올 때까지 기다렸다가 한 수 둔다. 봇 응답 시간을 돌려준다.
    @discardableResult
    private func playOneMove(timeout: TimeInterval = 10) -> TimeInterval {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if isGameOver { return 0 }
            if let cell = playableCell() {
                let waited = Date().timeIntervalSince(start)
                cell.tap()
                return waited
            }
            usleep(200_000)
        }
        XCTFail("\(timeout)초 동안 둘 수 있는 칸이 없었습니다")
        return timeout
    }

    private func playUntilOver(maxMoves: Int = 30) {
        for _ in 0..<maxMoves where !isGameOver {
            playOneMove()
        }
        XCTAssertTrue(button(containing: "한 판 더").waitForExistence(timeout: 10), "판이 끝나지 않았습니다")
    }

    // MARK: - 시나리오

    func test1_HomeAndRules() {
        XCTAssertTrue(app.staticTexts["리버스 틱택토"].waitForExistence(timeout: 5))
        shot("01 홈")

        tapButton("규칙 한 장 보기")
        XCTAssertTrue(app.staticTexts["규칙 한 장"].waitForExistence(timeout: 5))
        shot("02 규칙")
    }

    func test2_VsComputerClassicHard() {
        tapButton("3×3")
        tapButton("어려움")
        tapButton("컴퓨터 대전")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        shot("03 3x3 시작")

        playOneMove()
        playOneMove()
        shot("04 3x3 중반 (위험 칸 표시)")

        playUntilOver()
        shot("05 3x3 결과: \(status.label)")

        // 두 번째 판은 선·후공이 바뀌어 컴퓨터가 먼저 둔다
        tapButton("한 판 더")
        let botMoved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-' AND label CONTAINS 'X'")).firstMatch
        XCTAssertTrue(botMoved.waitForExistence(timeout: 5), "컴퓨터가 먼저 두지 않았습니다")
        shot("06 한 판 더: 컴퓨터 선공")
        playUntilOver()
        shot("07 두 번째 판 결과: \(status.label)")
    }

    func test3_TwoPlayer4x4WithUndo() {
        tapButton("4×4")
        tapButton("함께 하기")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        for _ in 0..<6 { playOneMove() }
        shot("08 4x4 둘이서 6수")

        tapButton("무르기")
        let marks = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-' AND (label CONTAINS 'X' OR label CONTAINS 'O')"))
        XCTAssertEqual(marks.count, 5, "무르기 후 말이 5개여야 합니다")
        shot("09 4x4 무르기 후")

        playUntilOver(maxMoves: 20)
        shot("10 4x4 결과: \(status.label)")
    }

    func test4_VsComputer5x5HardResponseTime() {
        tapButton("5×5")
        tapButton("어려움")
        tapButton("컴퓨터 대전")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        var slowest: TimeInterval = 0
        for index in 0..<8 where !isGameOver {
            let waited = playOneMove(timeout: 15)
            if index > 0 { slowest = max(slowest, waited) }
        }
        shot("11 5x5 어려움 (최장 응답 \(String(format: "%.1f", slowest))초)")
        XCTAssertLessThan(slowest, 5, "컴퓨터 응답이 너무 느립니다")
    }

    func test5_Tutorial() {
        tapButton("배우기")
        XCTAssertTrue(button(containing: "줄을 만들면 진다").waitForExistence(timeout: 5))
        shot("12 배우기 목록")

        // 미션 1: 2번 칸은 X의 줄이 완성되는 칸 → 오답
        tapButton("줄을 만들면 진다")
        app.buttons["cell-2"].tap()
        XCTAssertTrue(app.staticTexts["그 칸에 두면 내 줄이 완성됩니다."].waitForExistence(timeout: 5))
        shot("13 미션1 오답")

        tapButton("다시 해보기")
        app.buttons["cell-4"].tap()
        XCTAssertTrue(app.staticTexts["좋아요! 줄을 피했습니다."].waitForExistence(timeout: 5))
        shot("14 미션1 정답")
        tapButton("목록으로")

        // 미션 3: 1번 칸이 유일한 승리 수
        tapButton("몰아붙이기")
        app.buttons["cell-1"].tap()
        XCTAssertTrue(app.staticTexts["정답! 이제 상대는 어디에 두든 줄이 완성됩니다."].waitForExistence(timeout: 5))
        shot("15 미션3 정답")
        tapButton("목록으로")
        shot("16 배우기 목록 (완료 표시)")
    }

    func test6_EnglishHome() {
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Reverse Tic-Tac-Toe"].waitForExistence(timeout: 5))
        shot("17 English home")
        tapButton("vs Computer")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        playOneMove()
        shot("18 English game")
    }
}
