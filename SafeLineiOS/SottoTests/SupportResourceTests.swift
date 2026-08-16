import XCTest
@testable import Sotto

final class SupportResourceTests: XCTestCase {
    func testEveryResourceHasAnExplicitContactAction() {
        let resources = SupportResourceLoader.load()

        XCTAssertFalse(resources.isEmpty)
        XCTAssertTrue(resources.allSatisfy { !$0.actions.isEmpty })
        XCTAssertTrue(resources.flatMap(\.actions).allSatisfy {
            ["tel", "url", "directory"].contains($0.type)
        })
    }

    func testGovernmentDirectoryUsesOnlyTheDirectoryAction() {
        let resource = SupportResourceLoader.load().first {
            $0.title == "内閣府 性犯罪・性暴力の相談窓口一覧"
        }

        XCTAssertEqual(resource?.actions.count, 1)
        XCTAssertEqual(resource?.actions.first?.label, "窓口一覧")
        XCTAssertEqual(resource?.actions.first?.type, "directory")
        XCTAssertEqual(resource?.actions.first?.value,
                       "https://www.gender.go.jp/policy/no_violence/seibouryoku/consult.html")
    }

    func testDVConsultationMethodsMatchCurrentOfficialChannels() {
        let resources = SupportResourceLoader.load()
        let navigation = resources.first { $0.title.contains("#8008") }
        let plus = resources.first { $0.title == "DV相談＋（プラス）" }

        XCTAssertEqual(navigation?.actions.map(\.type), ["tel"])
        XCTAssertEqual(navigation?.actions.first?.value, "8008")
        XCTAssertEqual(Set(plus?.actions.map(\.type) ?? []), Set(["tel", "url"]))
        XCTAssertFalse(plus?.actions.contains { $0.label.contains("メール") } ?? true,
                       "DV相談＋ ended email consultation in FY2025")
    }
}
