import XCTest

final class SottoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-sotto.checkin.dailyReminder.enabled", "NO"]
        app.launch()
    }

    func testEmergencyCallExplainsOutcomeWithoutAlarmistSOSLabel() {
        let emergencyCall = app.buttons["home.emergencyCall"]
        XCTAssertTrue(emergencyCall.waitForExistence(timeout: 5))
        XCTAssertEqual(emergencyCall.label, "110番に電話")
        XCTAssertTrue(app.staticTexts["home.emergencyExplanation"].exists)
        XCTAssertFalse(app.staticTexts["長押しでSOS"].exists)
    }

    func testPrimaryTabsOpenTheirExpectedScreens() {
        app.tabBars.buttons["見守り"].tap()
        XCTAssertTrue(app.staticTexts["見守りチェックイン"].waitForExistence(timeout: 3))

        app.tabBars.buttons["相談窓口"].tap()
        XCTAssertTrue(app.staticTexts["相談窓口"].waitForExistence(timeout: 3))

        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 3))
    }

    func testSupportDirectoryHasSingleDirectoryAction() {
        app.tabBars.buttons["相談窓口"].tap()
        XCTAssertTrue(app.buttons["窓口一覧"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "窓口一覧").count, 1)
    }

    func testEmergencyCallRemainsReachableAtAccessibilityTextSize() {
        app.terminate()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()

        let emergencyCall = app.buttons["home.emergencyCall"]
        XCTAssertTrue(emergencyCall.waitForExistence(timeout: 5))
        XCTAssertTrue(emergencyCall.isHittable)
        XCTAssertTrue(app.tabBars.buttons["相談窓口"].isHittable)
    }

    func testAllFiveAppIconChoicesAreVisible() {
        app.tabBars.buttons["設定"].tap()
        app.staticTexts["アイコン"].tap()

        for name in ["デフォルト", "暖色", "寒色", "モノクロ", "シンプル"] {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3), "Missing icon choice: \(name)")
        }

        let buttons = ["デフォルト", "パステル 暖色", "パステル 寒色", "モノクロ", "シンプル"]
            .map { app.buttons[$0] }
        let firstRowTops = buttons.prefix(3).map { $0.frame.minY }
        let secondRowTops = buttons.suffix(2).map { $0.frame.minY }
        XCTAssertLessThanOrEqual((firstRowTops.max() ?? 0) - (firstRowTops.min() ?? 0), 1)
        XCTAssertLessThanOrEqual((secondRowTops.max() ?? 0) - (secondRowTops.min() ?? 0), 1)
        XCTAssertGreaterThan(secondRowTops.min() ?? 0, firstRowTops.max() ?? 0)
    }

    func testSettingsHelpAndPermissionSectionsAreAvailable() {
        app.tabBars.buttons["設定"].tap()

        XCTAssertTrue(app.staticTexts["権限と端末設定"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["iPhoneの設定を開く"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["そっとについて"].exists)

        app.tabBars.buttons["記録"].tap()
        XCTAssertTrue(app.buttons["journal.pdfGuide"].waitForExistence(timeout: 3))
        app.buttons["journal.pdfGuide"].tap()
        XCTAssertTrue(app.navigationBars["PDF書き出し"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["書き出したPDFは暗号化されません。共有先や保存場所を確認し、不要になったら削除してください。"].exists)
    }

    func testAboutScreenContainsPrivacyPolicyLink() {
        app.tabBars.buttons["設定"].tap()
        app.swipeUp()
        app.staticTexts["そっとについて"].tap()

        XCTAssertTrue(app.navigationBars["そっとについて"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["プライバシーポリシー"].exists)
        XCTAssertTrue(app.staticTexts["ショートカットとアクションボタン"].exists)
        app.staticTexts["ショートカットとアクションボタン"].tap()
        XCTAssertTrue(app.navigationBars["ショートカット"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["下のボタンから「そっと」の\nショートカット一覧を開けます。"].exists)
    }
}
