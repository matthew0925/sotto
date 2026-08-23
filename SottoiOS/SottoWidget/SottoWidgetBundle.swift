import WidgetKit
import SwiftUI

@main
struct SottoWidgetBundle: WidgetBundle {
    var body: some Widget {
        SottoSOSWidget()
        SottoCheckinWidget()
    }
}

/// The SOS widget stays fully static (there's nothing to show but the
/// button itself). The check-in widget reads the App Group container
/// CheckInManager writes to (see CheckInManager.sharedDefaults) for a live
/// countdown via `Text(timerInterval:)`, which updates on its own without
/// repeated timeline reloads. Tapping either widget opens the main app
/// (via the `sotto://` URL scheme) to the right tab — neither one calls or
/// sends anything by itself, same as every other alert path in this app.
private let checkinAppGroupID = "group.com.takashi.sotto"
/// Must stay in sync with CheckInManager's private activeKey/endDateKey —
/// duplicated here because the widget extension is a separate module that
/// can't see the main app target's private constants.
private let checkinActiveKey = "sotto.checkin.active"
private let checkinEndDateKey = "sotto.checkin.endDate"
private let ink = Color(red: 0x12/255, green: 0x17/255, blue: 0x2B/255)
private let teal = Color(red: 0x2E/255, green: 0xC4/255, blue: 0xB6/255)
private let coral = Color(red: 0xFF/255, green: 0x6B/255, blue: 0x5B/255)

private extension View {
    /// `.containerBackground(_:for:)` is iOS 17+ only; this target's
    /// deployment minimum is iOS 16, so fall back to a plain `.background`
    /// there. Pre-17 widgets rendering their own background this way is the
    /// standard, Apple-documented approach for that OS range.
    @ViewBuilder
    func sottoWidgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(color, for: .widget)
        } else {
            self.background(color)
        }
    }
}

struct SottoTimelineEntry: TimelineEntry {
    let date: Date
    var checkinActive: Bool = false
    var checkinEndDate: Date?
}

struct SottoTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SottoTimelineEntry { SottoTimelineEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (SottoTimelineEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SottoTimelineEntry>) -> Void) {
        let entry = currentEntry()
        // The app calls WidgetCenter.reloadTimelines(ofKind:) the moment a
        // check-in starts or ends, so this policy only needs to cover the
        // in-between case: once the deadline itself passes, ask for a fresh
        // entry so the widget stops showing a countdown that's hit zero.
        let policy: TimelineReloadPolicy = entry.checkinEndDate.map { .after($0) } ?? .never
        completion(Timeline(entries: [entry], policy: policy))
    }

    private func currentEntry() -> SottoTimelineEntry {
        let defaults = UserDefaults(suiteName: checkinAppGroupID)
        let active = defaults?.bool(forKey: checkinActiveKey) ?? false
        let endDate = defaults?.object(forKey: checkinEndDateKey) as? Date
        return SottoTimelineEntry(date: Date(), checkinActive: active && endDate != nil, checkinEndDate: endDate)
    }
}

struct SottoSOSWidget: Widget {
    let kind = "SottoSOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SottoTimelineProvider()) { _ in
            SOSWidgetView()
                .sottoWidgetBackground(ink)
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
        StaticConfiguration(kind: kind, provider: SottoTimelineProvider()) { entry in
            CheckinWidgetView(entry: entry)
                .sottoWidgetBackground(ink)
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
    let entry: SottoTimelineEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "clock.fill").foregroundColor(teal)
                if entry.checkinActive, let endDate = entry.checkinEndDate, endDate > entry.date {
                    Text(timerInterval: entry.date...endDate, countsDown: true)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                } else {
                    Text("見守りを開く")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
            }
        default:
            VStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 30))
                    .foregroundColor(teal)
                if entry.checkinActive, let endDate = entry.checkinEndDate, endDate > entry.date {
                    Text(timerInterval: entry.date...endDate, countsDown: true)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                    Text("見守り中")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("見守り\nチェックイン")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
