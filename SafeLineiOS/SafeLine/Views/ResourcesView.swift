import SwiftUI

struct ResourcesView: View {
    @State private var resources: [SupportResource] = SupportResourceLoader.load()
    @State private var directoryURL: URL?

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("相談窓口")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.safeText)
                    Text("一人で抱え込まなくていい場所です。年齢・性別を問わず相談できます。あなたは悪くありません。")
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundColor(.safeTextDim)

                    ForEach(resources) { resource in
                        if resource.type == "info" {
                            noticeCard(resource)
                        } else {
                            resourceCardBody(resource)
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: Binding(
            get: { directoryURL != nil },
            set: { if !$0 { directoryURL = nil } }
        )) {
            if let directoryURL {
                SupportDirectoryView(url: directoryURL)
            }
        }
    }

    private func resourceCardBody(_ resource: SupportResource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(resource.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.safeText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            Text(resource.desc)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundColor(.safeTextDim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            actionButtons(for: resource)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.safeCardFill)
        .cornerRadius(16)
    }

    /// A notice — e.g. "緊急避妊について" — styled distinctly so it doesn't read as
    /// one more actionable contact in the list. If `value` carries a link (a
    /// government page that's kept current on its own, e.g. the monthly-updated
    /// pharmacy list), show it as a separate, clearly-labeled tap target below
    /// the notice text rather than making the whole card silently tappable.
    private func noticeCard(_ resource: SupportResource) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(resource.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.safeCoral)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            Text(resource.desc)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundColor(.safeTextDim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            actionButtons(for: resource)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.safeCoral.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.safeCoral.opacity(0.25)))
        .cornerRadius(16)
    }

    @ViewBuilder
    private func actionButtons(for resource: SupportResource) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(resource.actions) { action in
                Button {
                    perform(action)
                } label: {
                    Label(action.label, systemImage: iconName(for: action.type))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(resource.type == "info" ? Color.safeCoral.opacity(0.14) : Color.safeTeal.opacity(0.16))
                        .foregroundColor(resource.type == "info" ? .safeCoral : .safeTeal)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint(action.type == "tel" ? "電話アプリを開きます" : "リンクを開きます")
            }
        }
    }

    private func perform(_ action: SupportAction) {
        if action.type == "directory", let url = URL(string: action.value) {
            directoryURL = url
        } else if let url = action.actionURL {
            UIApplication.shared.open(url)
        }
    }

    private func iconName(for type: String) -> String {
        switch type {
        case "tel": return "phone.fill"
        case "directory": return "list.bullet"
        default: return "arrow.up.right.square"
        }
    }
}

/// A small wrapping layout keeps multiple contact methods readable on narrow
/// iPhones and at larger Dynamic Type sizes.
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: min(maxWidth, usedWidth), height: y + rowHeight), points)
    }
}
