import XCTest
@testable import Sotto

final class SupportResourceTests: XCTestCase {
    // `SupportResourceLoader.load()` prefers a previously-fetched remote cache
    // over the bundled JSON when one exists on disk (see its doc comment). In
    // an app-hosted test target that cache is the real app sandbox, so a prior
    // `refreshFromRemote()` call — from this same test run or a manual app
    // launch on the same simulator — could make these tests silently validate
    // a cached file instead of the resources.json actually shipped with the
    // app. Go straight to `loadBundled()` so these tests are deterministic and
    // genuinely cover what ships in the bundle.
    func testEveryResourceHasAnExplicitContactAction() {
        let resources = SupportResourceLoader.loadBundled()

        XCTAssertFalse(resources.isEmpty)
        XCTAssertTrue(resources.allSatisfy { !$0.actions.isEmpty })
        XCTAssertTrue(resources.flatMap(\.actions).allSatisfy {
            ["tel", "url", "directory"].contains($0.type)
        })
    }

    func testGovernmentDirectoryUsesOnlyTheDirectoryAction() {
        let resource = SupportResourceLoader.loadBundled().first {
            $0.title == "内閣府 性犯罪・性暴力の相談窓口一覧"
        }

        XCTAssertEqual(resource?.actions.count, 1)
        XCTAssertEqual(resource?.actions.first?.label, "全国の窓口一覧")
        XCTAssertEqual(resource?.actions.first?.type, "directory")
        XCTAssertEqual(resource?.actions.first?.value,
                       "https://www.gender.go.jp/policy/no_violence/seibouryoku/consult.html")
    }

    func testDVConsultationMethodsMatchCurrentOfficialChannels() {
        let resources = SupportResourceLoader.loadBundled()
        let navigation = resources.first { $0.title.contains("#8008") }
        let plus = resources.first { $0.title == "DV相談＋（プラス）" }

        XCTAssertEqual(navigation?.actions.map(\.type), ["tel"])
        XCTAssertEqual(navigation?.actions.first?.value, "#8008")
        XCTAssertEqual(navigation?.actions.first?.actionURL?.absoluteString, "tel:%238008")
        XCTAssertEqual(Set(plus?.actions.map(\.type) ?? []), Set(["tel", "url"]))
        XCTAssertFalse(plus?.actions.contains { $0.label.contains("メール") } ?? true,
                       "DV相談＋ ended email consultation in FY2025")
    }

    func testOfficialShortDialCodesKeepTheirHashWhenBuildingPhoneURLs() {
        let resources = SupportResourceLoader.loadBundled()
        let oneStop = resources.first { $0.title.contains("#8891") }
        XCTAssertEqual(oneStop?.actions.first?.value, "#8891")
        XCTAssertEqual(oneStop?.actions.first?.actionURL?.absoluteString, "tel:%238891")
    }
}
