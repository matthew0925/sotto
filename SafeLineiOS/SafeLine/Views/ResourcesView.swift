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
                    Text("一人で抱え込まなくていい場所です。\n年齢・性別を問わず相談できます。あなたは悪くありません。")
                        .font(.system(size: 14.5, design: .rounded))
                        .foregroundColor(.safeTextDim)

                    ForEach(resources) { resource in
                        Button {
                            if let url = resource.actionURL {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(resource.title)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.safeText)
                                Text(resource.desc)
                                    .font(.system(size: 14, design: .rounded))
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
                    }
                }
                .padding(20)
            }
        }
    }
}
