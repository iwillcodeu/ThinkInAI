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
                    log: nil,
                    showsProgress: false,
                    retry: { server.start() }
                )
            case .idle, .starting:
                StatusPane(
                    title: "正在启动 ThinkInAI",
                    detail: startingDetail(server.logText),
                    log: server.logText,
                    showsProgress: true,
                    retry: nil
                )
            }
        }
        .onAppear { server.start() }
    }
}

private func startingDetail(_ log: String) -> String {
    if log.contains("正在执行 pnpm run build") {
        return "正在执行 pnpm run build（首次可能需要几分钟）…"
    }
    if log.contains("正在执行 pnpm install") {
        return "正在执行 pnpm install…"
    }
    if log.contains("正在启动 pnpm dsh web") {
        return "正在连接 http://127.0.0.1:3080 …"
    }
    return "若尚未安装依赖或构建产物，会先执行 nvm use 22、pnpm install、pnpm run build。"
}

private struct StatusPane: View {
    let title: String
    let detail: String
    let log: String?
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
            if let log, !log.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ScrollView {
                    Text(log)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: 720, maxHeight: 240)
            }
            if let retry {
                Button("重试", action: retry)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
