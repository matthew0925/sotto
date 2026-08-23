import SwiftUI
import WebKit

/// Shows the Cabinet Office's live directory instead of copying contact data
/// into the app bundle. This keeps office names, hours, phone numbers, email
/// addresses, and website links current between App Store releases.
struct SupportDirectoryView: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var loadState: LoadState = .loading
    @State private var retryToken = 0

    enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.safeInk.ignoresSafeArea()
                SupportDirectoryWebView(url: url, loadState: $loadState, retryToken: retryToken)
                    .opacity(loadState == .failed ? 0 : 1)

                if loadState == .loading {
                    ProgressView("読み込んでいます…")
                        .tint(.safeTeal)
                        .foregroundColor(.safeTextDim)
                }

                if loadState == .failed {
                    failureView
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    /// Never a dead end: offer both a retry and a way out to Safari, same
    /// spirit as SMSUnavailableView always offering a phone call fallback.
    private var failureView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 30))
                .foregroundColor(.safeCoral)
            Text("ページを読み込めませんでした")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(.safeText)
            Text("通信状況を確認して、もう一度お試しください。")
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(.safeTextDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                loadState = .loading
                retryToken += 1
            } label: {
                Text("もう一度読み込む")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.safeTeal)
                    .foregroundColor(.safeOnAccent)
                    .cornerRadius(12)
            }
            Button {
                UIApplication.shared.open(url)
            } label: {
                Text("Safariで開く")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundColor(.safeTeal)
            }
        }
        .padding(20)
    }
}

private struct SupportDirectoryWebView: UIViewRepresentable {
    let url: URL
    @Binding var loadState: SupportDirectoryView.LoadState
    /// Incrementing this from the parent triggers `updateUIView` to reload
    /// the existing WKWebView, rather than the retry button needing its own
    /// out-of-band signaling path back into a UIViewRepresentable.
    let retryToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(loadState: $loadState) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // The official page contains plain-text phone numbers and email
        // addresses. Data detection turns them into tel:/mailto: links while
        // preserving the site's own links to each center's website or form.
        configuration.dataDetectorTypes = [.link, .phoneNumber]
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        context.coordinator.lastRetryToken = retryToken
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard retryToken != context.coordinator.lastRetryToken else { return }
        context.coordinator.lastRetryToken = retryToken
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var loadState: SupportDirectoryView.LoadState
        var lastRetryToken = 0

        init(loadState: Binding<SupportDirectoryView.LoadState>) {
            _loadState = loadState
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if url.scheme == "tel" || url.scheme == "mailto" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loadState = .loaded
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            loadState = .failed
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            loadState = .failed
        }

        // Official sites sometimes use target="_blank". Load those links in
        // the same sheet instead of dropping the tap or leaving the app.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}
