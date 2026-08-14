import SwiftUI

struct ContentView: View {
    @ObservedObject var server: ServerManager

    var body: some View {
        ZStack {
            switch server.phase {
            case .ready:
                WebView(url: server.url)
            case .failed(let message):
                StatusPane(
                    title: "启动失败",
                    detail: message,
                    showsProgress: false,
                    retry: { server.start() }
                )
            case .idle, .starting:
                StatusPane(
                    title: "正在启动 DeepSeek Harness",
                    detail: "正在连接 http://127.0.0.1:3080 …",
                    showsProgress: true,
                    retry: nil
                )
            }
        }
        .onAppear { server.start() }
    }
}

private struct StatusPane: View {
    let title: String
    let detail: String
    let showsProgress: Bool
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            if showsProgress {
                ProgressView()
                    .controlSize(.large)
            }
            Text(title)
                .font(.title2.weight(.semibold))
            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
            if let retry {
                Button("重试", action: retry)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
