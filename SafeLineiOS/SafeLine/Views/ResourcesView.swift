import SwiftUI

struct ResourcesView: View {
    @State private var resources: [SupportResource] = SupportResourceLoader.load()

    var body: some View {
        ZStack {
            Color.safeInk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("相談窓口")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("一人で抱え込まなくていい場所です。年齢・性別を問わず相談できます。あなたは悪くありません。")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))

                    ForEach(resources) { resource in
                        Button {
                            if let url = resource.actionURL {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(resource.title)
                                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(resource.desc)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.white.opacity(0.6))
                                HStack(spacing: 6) {
                                    ForEach(resource.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 10.5))
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .overlay(RoundedRectangle(cornerRadius: 99).stroke(Color.white.opacity(0.15)))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}
