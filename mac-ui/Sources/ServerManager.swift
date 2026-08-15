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
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var logText = ""
    let url = URL(string: "http://127.0.0.1:3080/")!

    private var process: Process?
    private var ownsProcess = false
    private let log = LogBuffer()
    private let readyDeadline: TimeInterval = 45 * 60

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
        guard let repo = RepoRoot.resolve() else {
            phase = .failed("找不到仓库根目录。请把 App 留在 mac-ui/ 下重新构建，或设置环境变量 DSH_REPO_ROOT。")
            return
        }

        switch await probe() {
        case .dsh:
            ownsProcess = false
            phase = .ready(owned: false)
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
            if await probe() == .dsh {
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
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
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
            let (data, response) = try await URLSession.shared.data(for: indexRequest)
            guard let http = response as? HTTPURLResponse, (200 ... 499).contains(http.statusCode) else {
                return .down
            }
            guard let body = String(data: data, encoding: .utf8), body.contains("__DSH_BOOT__") else {
                return .other
            }
            // Index HTML can appear before /plugins routes accept JS. Loading
            // the shell then leaves every entry pending on connection/typert.
            return await pluginBundleReady() ? .dsh : .down
        } catch {
            return .down
        }
    }

    private func pluginBundleReady() async -> Bool {
        guard let plugin = URL(
            string: "plugins/@deepseek-ai/dsh-client-connection/client.js",
            relativeTo: url
        ) else {
            return false
        }
        var request = URLRequest(url: plugin)
        request.timeoutInterval = 1.5
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
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
}
