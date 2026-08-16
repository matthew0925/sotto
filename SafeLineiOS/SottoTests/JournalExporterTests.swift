import XCTest
import UIKit
@testable import Sotto

final class JournalExporterTests: XCTestCase {
    func testExportFilenameContainsTimestampAndNoEntryContent() {
        let filename = JournalExporter.exportFilename(generatedAt: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertTrue(filename.hasPrefix("そっと_記録_"))
        XCTAssertTrue(filename.hasSuffix(".pdf"))
        XCTAssertFalse(filename.contains("秘密の本文"))
    }

    func testPhotoExportProducesLargerPDFThanTextOnlyExport() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 180))
        let photoData = renderer.jpegData(withCompressionQuality: 0.9) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 240, height: 180))
        }
        let entry = JournalEntry(
            id: UUID(),
            date: Date(),
            text: "写真付きの記録",
            hasPhoto: true,
            createdAt: Date(),
            contentHash: "hash"
        )

        let textOnly = JournalExporter.makePDF(entries: [entry])
        let withPhoto = JournalExporter.makePDF(
            entries: [entry],
            includePhotos: true,
            photoProvider: { _ in photoData }
        )

        XCTAssertGreaterThan(withPhoto.count, textOnly.count)
    }
}
