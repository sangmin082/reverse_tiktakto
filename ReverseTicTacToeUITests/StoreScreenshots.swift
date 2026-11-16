import XCTest

/// App Store 제출용 스크린샷. 정해진 수순으로 두어 매번 같은 화면을 만든다.
/// store-screenshots 워크플로가 6.9" 시뮬레이터에서 이 클래스만 실행한다.
/// 언어는 TEST_RUNNER_STORE_LANG(ko/en)으로 고른다.
final class StoreScreenshots: XCTestCase {

    private var app: XCUIApplication!
    private let isEnglish = ProcessInfo.processInfo.environment["STORE_LANG"] == "en"

    /// 화면 문구 (한국어, 영어)
    private func t(_ ko: String, _ en: String) -> String { isEnglish ? en : ko }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        let language = isEnglish ? ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] : ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launchArguments = language + ["-showDangerHints", "YES"]
        app.launch()
    }

    private func shot(_ name: String) {
        sleep(1) // 말 그리기·줄 긋기 애니메이션이 끝난 뒤 찍는다
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapButton(_ text: String) {
        let element = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), "버튼 없음: \(text)")
        element.tap()
    }

    private func play(_ cells: [Int]) {
        for cell in cells {
            let button = app.buttons["cell-\(cell)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
        }
    }

    func test1_Home() {
        XCTAssertTrue(app.staticTexts[t("리버스 틱택토", "Reverse Tic-Tac-Toe")].waitForExistence(timeout: 5))
        shot("1 홈")
    }

    func test2_DangerHints() {
        tapButton(t("함께 하기", "Two Players"))
        // X 0·1·4, O 15·14·11 → X 차례, 2와 8이 X에게 위험한 칸
        play([0, 15, 1, 14, 4, 11])
        shot("2 위험한 칸")
    }

    func test3_LosingLine() {
        tapButton(t("함께 하기", "Two Players"))
        // O가 5·10·15 대각선을 완성해 패배
        play([0, 5, 3, 10, 12, 6, 9, 15])
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", t("한 판 더", "Play again"))).firstMatch.waitForExistence(timeout: 5))
        shot("3 줄을 만들면 패배")
    }

    func test4_Tutorial() {
        tapButton(t("배우기", "Learn"))
        tapButton(t("몰아붙이기", "Corner Them"))
        app.buttons["cell-2"].tap()
        XCTAssertTrue(app.staticTexts[t("정답! 이제 상대는 어디에 두든 줄이 완성됩니다.", "Correct! Now every move your opponent has completes a line.")].waitForExistence(timeout: 5))
        shot("4 배우기 미션")
    }

    func test5_Rules() {
        tapButton(t("규칙 한 장 보기", "The rules on one page"))
        XCTAssertTrue(app.staticTexts[t("규칙 한 장", "The Rules")].waitForExistence(timeout: 5))
        shot("5 규칙")
    }
}
