import SwiftUI

struct ResourcesView: View {
    @State private var resources: [SupportResource] = SupportResourceLoader.load()

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
                            Button {
                                if let url = resource.actionURL {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                resourceCardBody(resource)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private func resourceCardBody(_ resource: SupportResource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(resource.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.safeText)
            Text(resource.desc)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundColor(.safeTextDim)
            HStack(spacing: 6) {
                ForEach(resource.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 12.5, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 99).stroke(Color.safeBorder))
                        .foregroundColor(.safeTextFaint)
                }
            }
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
            Text(resource.desc)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundColor(.safeTextDim)
            if let url = resource.actionURL {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Text((resource.tags.first ?? "詳しく見る") + " →")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.safeCoral)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.safeCoral.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.safeCoral.opacity(0.25)))
        .cornerRadius(16)
    }
}
