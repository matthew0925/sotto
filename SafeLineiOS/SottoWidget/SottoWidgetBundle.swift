import WidgetKit
import SwiftUI

@main
struct SottoWidgetBundle: WidgetBundle {
    var body: some Widget {
        SottoSOSWidget()
        SottoCheckinWidget()
    }
}

/// Both widgets are fully static — there is nothing dynamic to show (no
/// check-in countdown, no live state) because WidgetKit extensions run in a
/// separate process/bundle from the main app and don't share its in-memory
/// state. A shared App Group could carry countdown data across, but that's
/// deliberately out of scope for v1: the widget's only job is "get to the
/// right screen one tap faster than opening the app fresh," not to mirror
/// live status. Tapping opens the main app (via the `sotto://` URL scheme)
/// to the right tab — it never calls or sends anything by itself, same as
/// every other alert path in this app.
private let ink = Color(red: 0x12/255, green: 0x17/255, blue: 0x2B/255)
private let teal = Color(red: 0x2E/255, green: 0xC4/255, blue: 0xB6/255)
private let coral = Color(red: 0xFF/255, green: 0x6B/255, blue: 0x5B/255)

struct SottoTimelineEntry: TimelineEntry {
    let date: Date
}

struct SottoTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SottoTimelineEntry { SottoTimelineEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (SottoTimelineEntry) -> Void) {
        completion(SottoTimelineEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SottoTimelineEntry>) -> Void) {
        completion(Timeline(entries: [SottoTimelineEntry(date: Date())], policy: .never))
    }
}

struct SottoSOSWidget: Widget {
    let kind = "SottoSOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SottoTimelineProvider()) { _ in
            SOSWidgetView()
                .containerBackground(ink, for: .widget)
                .widgetURL(URL(string: "sotto://sos"))
        }
        .configurationDisplayName("そっと SOS")
        .description("タップすると、そっとを開いてすぐSOSを押せる状態にします。")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct SottoCheckinWidget: Widget {
    let kind = "SottoCheckinWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SottoTimelineProvider()) { _ in
            CheckinWidgetView()
                .containerBackground(ink, for: .widget)
                .widgetURL(URL(string: "sotto://checkin"))
        }
        .configurationDisplayName("そっと 見守り")
        .description("タップすると、そっとの見守りチェックイン画面を開きます。")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

private struct SOSWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                Circle().fill(coral)
                Text("SOS")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Circle().fill(coral).frame(width: 10, height: 10)
                Text("そっと SOS")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
        default:
            VStack(spacing: 10) {
                Circle()
                    .fill(coral)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text("SOS")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    )
                Text("長押しでSOS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("タップして開く")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct CheckinWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "clock.fill").foregroundColor(teal)
                Text("見守りを開く")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
        default:
            VStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 30))
                    .foregroundColor(teal)
                Text("見守り\nチェックイン")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
