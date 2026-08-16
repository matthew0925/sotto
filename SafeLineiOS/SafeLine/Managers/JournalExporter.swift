import UIKit

/// Renders journal entries into a PDF the user can share. Photos are opt-in at
/// export time because the resulting PDF is no longer protected by the app's
/// on-device encryption.
enum JournalExporter {
    static func makePDF(
        entries: [JournalEntry],
        includePhotos: Bool = false,
        photoProvider: ((JournalEntry) -> Data?)? = nil,
        generatedAt: Date = Date()
    ) -> Data {
        let pageWidth: CGFloat = 612 // US Letter @ 72dpi
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let dateFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let bodyFont = UIFont.systemFont(ofSize: 13)
        let noteFont = UIFont.italicSystemFont(ofSize: 10)
        let hashFont = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin
            let contentWidth = pageWidth - margin * 2
            let pageBottom = pageHeight - margin

            func beginNewPage() {
                context.beginPage()
                y = margin
            }

            /// Draw every character, splitting very long entries across pages.
            /// A single Text.draw(rect:) silently clips when its measured height
            /// is taller than one PDF page.
            func drawPaginatedBody(_ text: String) {
                let source = text as NSString
                var offset = 0
                let attributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

                while offset < source.length {
                    if pageBottom - y < bodyFont.lineHeight {
                        beginNewPage()
                    }
                    let availableHeight = pageBottom - y
                    var low = 1
                    var high = source.length - offset
                    var fittingLength = 1

                    while low <= high {
                        let middle = (low + high) / 2
                        let candidateRange = source.rangeOfComposedCharacterSequences(
                            for: NSRange(location: offset, length: middle)
                        )
                        let candidate = source.substring(with: candidateRange) as NSString
                        let height = ceil(candidate.boundingRect(
                            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: attributes,
                            context: nil
                        ).height)
                        if height <= availableHeight {
                            fittingLength = candidateRange.length
                            low = middle + 1
                        } else {
                            high = middle - 1
                        }
                    }

                    let range = source.rangeOfComposedCharacterSequences(
                        for: NSRange(location: offset, length: fittingLength)
                    )
                    let chunk = source.substring(with: range) as NSString
                    let chunkHeight = ceil(chunk.boundingRect(
                        with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attributes,
                        context: nil
                    ).height)
                    chunk.draw(
                        with: CGRect(x: margin, y: y, width: contentWidth, height: chunkHeight),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attributes,
                        context: nil
                    )
                    y += chunkHeight
                    offset = NSMaxRange(range)
                    if offset < source.length { beginNewPage() }
                }
            }

            let title = "そっと — 記録のエクスポート"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: titleFont])
            y += 28

            let generated = "書き出し日時: \(DateFormatter.localizedString(from: generatedAt, dateStyle: .medium, timeStyle: .short))"
            generated.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: noteFont, .foregroundColor: UIColor.darkGray])
            y += 16

            let photoNote = includePhotos ? "添付写真を含みます。" : "写真は含まれません。"
            let note = "この端末に保存された記録のみを含みます。\(photoNote)各記録のハッシュ値は、\nその文章と添付写真から再計算できます（作成後に書き換えられていないことの目安です。\n法的な証明として保証するものではありません）。"
            note.draw(
                with: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 40),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: noteFont, .foregroundColor: UIColor.darkGray],
                context: nil
            )
            y += 44

            if entries.isEmpty {
                "記録はまだありません。".draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: bodyFont])
            }

            for entry in entries {
                let dateString = DateFormatter.localizedString(from: entry.date, dateStyle: .medium, timeStyle: .short)
                let bodySize = (entry.text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: bodyFont],
                    context: nil
                )
                let entryHeight = 16 + min(bodySize.height, pageBottom - margin) + 14 + 18

                if y + entryHeight > pageBottom {
                    beginNewPage()
                }

                dateString.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: dateFont, .foregroundColor: UIColor.darkGray])
                y += 16

                drawPaginatedBody(entry.text)
                y += 4

                if y + 18 > pageBottom { beginNewPage() }

                let createdString = DateFormatter.localizedString(from: entry.createdAt, dateStyle: .short, timeStyle: .medium)
                let hashLine = "作成: \(createdString)   SHA-256: \(entry.contentHash)"
                hashLine.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: hashFont, .foregroundColor: UIColor.gray])
                y += 18

                if includePhotos, entry.hasPhoto {
                    if let data = photoProvider?(entry), let image = UIImage(data: data) {
                        let maxPhotoWidth = pageWidth - margin * 2
                        let maxPhotoHeight: CGFloat = 300
                        let scale = min(maxPhotoWidth / image.size.width, maxPhotoHeight / image.size.height, 1)
                        let photoSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

                        if y + photoSize.height + 24 > pageBottom {
                            beginNewPage()
                        }

                        image.draw(in: CGRect(x: margin, y: y, width: photoSize.width, height: photoSize.height))
                        y += photoSize.height + 24
                    } else {
                        "添付写真を読み込めませんでした。".draw(
                            at: CGPoint(x: margin, y: y),
                            withAttributes: [.font: noteFont, .foregroundColor: UIColor.gray]
                        )
                        y += 30
                    }
                } else {
                    y += 14
                }
            }
        }
    }

    /// Creates a protected temporary file so the share sheet receives a URL
    /// (and therefore a meaningful filename) instead of anonymous PDF data.
    static func makePDFFile(
        entries: [JournalEntry],
        includePhotos: Bool,
        photoProvider: ((JournalEntry) -> Data?)? = nil,
        generatedAt: Date = Date()
    ) throws -> URL {
        let data = makePDF(
            entries: entries,
            includePhotos: includePhotos,
            photoProvider: photoProvider,
            generatedAt: generatedAt
        )
        let url = uniqueTemporaryURL(generatedAt: generatedAt)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static func exportFilename(generatedAt: Date, sequence: Int? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let suffix = sequence.map { "_\($0)" } ?? ""
        return "そっと_記録_\(formatter.string(from: generatedAt))\(suffix).pdf"
    }

    private static func uniqueTemporaryURL(generatedAt: Date) -> URL {
        let directory = FileManager.default.temporaryDirectory
        var sequence: Int?
        while true {
            let candidate = directory.appendingPathComponent(exportFilename(generatedAt: generatedAt, sequence: sequence))
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            sequence = (sequence ?? 1) + 1
        }
    }
}
