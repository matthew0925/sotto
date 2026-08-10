import UIKit

/// Renders journal entries into a plain PDF the user can share (e.g. to show
/// a support organization or keep outside the app). Deliberately text-only
/// for now — bundling decrypted photos into a PDF that then gets AirDropped
/// or emailed defeats a lot of the point of encrypting them on-device in the
/// first place, so that's left as a conscious gap rather than done casually.
enum JournalExporter {
    static func makePDF(entries: [JournalEntry]) -> Data {
        let pageWidth: CGFloat = 612 // US Letter @ 72dpi
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let dateFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let bodyFont = UIFont.systemFont(ofSize: 13)
        let noteFont = UIFont.italicSystemFont(ofSize: 10)

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            let title = "そっと — 記録のエクスポート"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: titleFont])
            y += 28

            let generated = "書き出し日時: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
            generated.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: noteFont, .foregroundColor: UIColor.darkGray])
            y += 16

            let note = "この端末に保存された記録のみを含みます。写真は含まれません。"
            note.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: noteFont, .foregroundColor: UIColor.darkGray])
            y += 24

            if entries.isEmpty {
                "記録はまだありません。".draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: bodyFont])
            }

            for entry in entries {
                let dateString = DateFormatter.localizedString(from: entry.date, dateStyle: .medium, timeStyle: .short)
                let bodyRect = CGRect(x: margin, y: 0, width: pageWidth - margin * 2, height: .greatestFiniteMagnitude)
                let bodySize = (entry.text as NSString).boundingRect(
                    with: bodyRect.size,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: bodyFont],
                    context: nil
                )
                let entryHeight = 16 + bodySize.height + 18

                if y + entryHeight > pageHeight - margin {
                    context.beginPage()
                    y = margin
                }

                dateString.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: dateFont, .foregroundColor: UIColor.darkGray])
                y += 16

                entry.text.draw(
                    with: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: bodySize.height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: bodyFont],
                    context: nil
                )
                y += bodySize.height + 18
            }
        }
    }
}
