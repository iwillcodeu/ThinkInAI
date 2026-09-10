import Darwin
import Foundation

@MainActor
final class ServerManager: ObservableObject {
    static let shared = ServerManager()

    enum Phase: Equatable {
        case idle
        case starting
        case ready(owned: Bool)
        case failed(String)
    }

    enum Probe: Equatable {
        case dsh
        case other
        case down
        /// Port answers with the dsh web 401 that asks for the printed launch URL.
        case needsLaunchToken
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var logText = ""
    /// Browser URL. Starts as the bare origin; once `dsh web:` prints a process
    /// token, this becomes the authenticated launch URL WKWebView must open.
    @Published private(set) var url = URL(string: "http://127.0.0.1:3080/")!

    private var process: Process?
    private var ownsProcess = false
    private let log = LogBuffer()
    private let readyDeadline: TimeInterval = 45 * 60
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config)
    }()

    private init() {}

    func start() {
        switch phase {
        case .idle, .failed:
            phase = .starting
            Task { await boot() }
        case .starting, .ready:
            break
        }
    }

    func stopIfOwned() {
        guard ownsProcess, let process else { return }
        terminateTree(process)
        self.process = nil
        ownsProcess = false
    }

    private func boot() async {
        log.clear()
        logText = ""
        url = URL(string: "http://127.0.0.1:3080/")!
        guard let repo = RepoRoot.resolve() else {
            phase = .failed("找不到仓库根目录。请把 App 留在 mac-ui/ 下重新构建，或设置环境变量 DSH_REPO_ROOT。")
            return
        }

        switch await probe() {
        case .dsh:
            ownsProcess = false
            phase = .ready(owned: false)
            return
        case .needsLaunchToken:
            phase = .failed(
                "127.0.0.1:3080 上已有 dsh web，但本窗口没有它的启动 token。\n"
                    + "请先结束占用 3080 的进程，再重新打开 ThinkInAI。"
            )
            return
        case .other:
            phase = .failed("127.0.0.1:3080 已被其他程序占用，且不是 ThinkInAI。")
            return
        case .down:
            break
        }

        do {
            process = try launch(repo: repo)
            ownsProcess = true
        } catch {
            phase = .failed("无法启动 dsh web：\(error.localizedDescription)")
            return
        }

        let deadline = Date().addingTimeInterval(readyDeadline)
        while Date() < deadline {
            logText = log.snapshot()
            if let process, !process.isRunning {
                let tail = logText.trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = tail.isEmpty
                    ? "请确认本机有 Node 22 与 pnpm；首次打开会自动执行 pnpm install 与 pnpm run build。"
                    : tail
                phase = .failed("准备或启动 dsh web 失败，进程已退出。\n\n\(detail)")
                ownsProcess = false
                self.process = nil
                return
            }
            // `dsh web:` is printed only after Loader settlement, so the token
            // URL is the readiness signal. WKWebView performs token→cookie login.
            if let launchUrl = Self.parseLaunchUrl(from: logText) {
                url = launchUrl
                phase = .ready(owned: true)
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        logText = log.snapshot()
        phase = .failed("等待仓库准备或 dsh web 启动超时（45 分钟）。")
    }

    private func launch(repo: URL) throws -> Process {
        guard let script = Bundle.main.url(forResource: "launch-dsh-web", withExtension: "sh") else {
            throw NSError(
                domain: "ThinkInAI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "App 包内缺少 launch-dsh-web.sh"]
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [script.path]
        process.currentDirectoryURL = repo
        process.standardInput = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        environment["DSH_REPO_ROOT"] = repo.path
        environment["NVM_DIR"] = NSHomeDirectory() + "/.nvm"
        environment["HOME"] = NSHomeDirectory()
        environment["LANG"] = environment["LANG"] ?? "en_US.UTF-8"
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let buffer = log
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            buffer.append(chunk)
        }

        try process.run()
        _ = setpgid(process.processIdentifier, process.processIdentifier)
        return process
    }

    private func terminateTree(_ process: Process) {
        let pid = process.processIdentifier
        _ = kill(-pid, SIGTERM)
        process.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if process.isRunning {
                _ = kill(-pid, SIGKILL)
            }
        }
    }

    func probe() async -> Probe {
        var indexRequest = URLRequest(url: url)
        indexRequest.timeoutInterval = 1.5
        indexRequest.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await session.data(for: indexRequest)
            guard let http = response as? HTTPURLResponse else {
                return .down
            }
            let body = String(data: data, encoding: .utf8) ?? ""
            // Token exchange answers 303 then follows to `/` with a cookie.
            // A bare `/` without cookie or token answers this fixed 401.
            if http.statusCode == 401, body.contains("dsh web authentication required") {
                return .needsLaunchToken
            }
            // 303/empty (or any non-boot body) means "not ready for attach", not
            // "foreign service" — callers that launched dsh must keep waiting.
            if (300 ... 399).contains(http.statusCode) {
                return .down
            }
            guard (200 ... 499).contains(http.statusCode) else {
                return .down
            }
            guard body.contains("__DSH_BOOT__") else {
                if body.contains("dsh web") || body.contains("authentication required") {
                    return .needsLaunchToken
                }
                return .other
            }
            return await pluginBundleReady() ? .dsh : .down
        } catch {
            return .down
        }
    }

    private func pluginBundleReady() async -> Bool {
        // Plugin paths are unauthenticated; always resolve against the bare origin
        // so a `?token=` launch URL cannot skew the relative join.
        var origin = URLComponents()
        origin.scheme = url.scheme ?? "http"
        origin.host = url.host ?? "127.0.0.1"
        origin.port = url.port ?? 3080
        origin.path = "/"
        guard let base = origin.url,
              let plugin = URL(
                string: "plugins/@deepseek-ai/dsh-client-connection/client.js",
                relativeTo: base
              )
        else {
            return false
        }
        var request = URLRequest(url: plugin)
        request.timeoutInterval = 1.5
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            let type = http.value(forHTTPHeaderField: "Content-Type") ?? ""
            guard type.contains("javascript") else { return false }
            guard let body = String(data: data, encoding: .utf8) else { return false }
            return body.contains("__ModuleLoader__")
        } catch {
            return false
        }
    }

    /// First loopback launch URL printed by `dsh web:` (token required since auth).
    static func parseLaunchUrl(from log: String) -> URL? {
        // Strip CSI / OSC sequences so colored or titled terminal output still matches.
        let stripped = log.replacingOccurrences(
            of: #"\u{001B}\[[0-9;?]*[ -/]*[@-~]|\u{001B}\][^\u{0007}]*\u{0007}"#,
            with: "",
            options: .regularExpression
        )
        let patterns = [
            #"dsh web: (http://127\.0\.0\.1:\d+/\?token=[A-Za-z0-9_-]+)"#,
            #"(http://127\.0\.0\.1:\d+/\?token=[A-Za-z0-9_-]+)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let full = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
            guard let match = regex.firstMatch(in: stripped, range: full),
                  let urlRange = Range(match.range(at: 1), in: stripped),
                  let url = URL(string: String(stripped[urlRange]))
            else {
                continue
            }
            return url
        }
        return nil
    }
}
