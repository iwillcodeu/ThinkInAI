import Foundation

enum RepoRoot {
    /// Resolves the ThinkInAI checkout this app should launch.
    ///
    /// Order: `DSH_REPO_ROOT`, the path written at build time, then
    /// `<app>/../../` when the bundle still lives in `mac-ui/`.
    static func resolve() -> URL? {
        if let env = ProcessInfo.processInfo.environment["DSH_REPO_ROOT"], !env.isEmpty {
            return existingRepo(at: URL(fileURLWithPath: env))
        }

        if let baked = Bundle.main.url(forResource: "repo-root", withExtension: "txt"),
           let text = try? String(contentsOf: baked, encoding: .utf8)
        {
            let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let repo = existingRepo(at: URL(fileURLWithPath: path)) {
                return repo
            }
        }

        let sibling = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return existingRepo(at: sibling)
    }

    static func existingRepo(at url: URL) -> URL? {
        let package = url.appendingPathComponent("package.json")
        let cli = url.appendingPathComponent("apps/cli")
        guard FileManager.default.fileExists(atPath: package.path),
              FileManager.default.fileExists(atPath: cli.path)
        else {
            return nil
        }
        return url
    }
}
