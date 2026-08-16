import XCTest
import UIKit
import CoreGraphics
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

    func testVeryLongEntrySpansMultiplePDFPagesWithoutBeingClipped() throws {
        let longText = String(repeating: "長い記録が途中で欠けないことを確認します。\n", count: 500)
        let entry = JournalEntry(
            id: UUID(), date: Date(), text: longText, createdAt: Date(), contentHash: "hash"
        )

        let data = JournalExporter.makePDF(entries: [entry])
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider) else {
            return XCTFail("Generated data must be a readable PDF")
        }
        XCTAssertGreaterThan(document.numberOfPages, 2)
    }
}
