import Foundation

// MARK: - Result

public struct SVNResult {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }

    public var succeeded: Bool { exitCode == 0 }

    public var errorText: String {
        let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !err.isEmpty { return err }
        let out = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !out.isEmpty { return out }
        return "svn exited with code \(exitCode)"
    }

    public var isAuthError: Bool {
        let hay = (stderr + "\n" + stdout).lowercased()
        return hay.contains("e170001")
            || hay.contains("e215004")
            || hay.contains("authentication failed")
            || hay.contains("authorization failed")
    }
}

// MARK: - Errors

public enum SVNError: Error {
    case notInstalled(String)
    case cancelled
    case failed(SVNResult)
    case xmlParseFailed(String)
}

extension SVNError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notInstalled(let path):
            return "svn executable not found (tried: \(path)). Install subversion or Xcode command line tools."
        case .cancelled:
            return "Operation cancelled."
        case .failed(let result):
            return result.errorText
        case .xmlParseFailed(let context):
            return "Could not parse svn XML output (\(context))."
        }
    }
}

// MARK: - Cancellable task handle

public final class SVNTask: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    public init() {}

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        let p = process
        lock.unlock()
        p?.terminate()
    }

    func attach(_ process: Process) {
        lock.lock()
        self.process = process
        let alreadyCancelled = cancelled
        lock.unlock()
        if alreadyCancelled { process.terminate() }
    }
}

// MARK: - Models

public struct SVNInfo: Sendable {
    public let path: String
    public let name: String
    public let url: String
    public let repositoryRoot: String
    public let repositoryUUID: String
    public let revision: Int
    public let kind: String
    public let lastChangedRevision: Int
    public let lastChangedAuthor: String
    public let lastChangedDate: Date?
    public let branch: String

    public init(path: String, name: String, url: String, repositoryRoot: String, repositoryUUID: String,
                revision: Int, kind: String, lastChangedRevision: Int, lastChangedAuthor: String,
                lastChangedDate: Date?, branch: String) {
        self.path = path
        self.name = name
        self.url = url
        self.repositoryRoot = repositoryRoot
        self.repositoryUUID = repositoryUUID
        self.revision = revision
        self.kind = kind
        self.lastChangedRevision = lastChangedRevision
        self.lastChangedAuthor = lastChangedAuthor
        self.lastChangedDate = lastChangedDate
        self.branch = branch
    }
}

public struct SVNStatusEntry: Sendable {
    public enum Item: String, Sendable {
        case modified, added, deleted, replaced, unversioned, missing, conflicted, normal, ignored, external, incomplete
    }

    public let path: String
    public let item: Item
    public let props: String
    public let revision: Int
    public let lastChangedRevision: Int
    public let author: String
    public let date: Date?

    public init(path: String, item: Item, props: String = "none", revision: Int,
                lastChangedRevision: Int, author: String, date: Date?) {
        self.path = path
        self.item = item
        self.props = props
        self.revision = revision
        self.lastChangedRevision = lastChangedRevision
        self.author = author
        self.date = date
    }

    public var isPropertyOnlyChange: Bool {
        item == .normal && props == "modified"
    }
}

public struct DiffLine: Identifiable, Sendable {
    public enum Kind: Sendable {
        case context
        case add
        case remove
        case hunk
        case note
    }

    public let id = UUID()
    public let kind: Kind
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

// MARK: - Stream collectors

private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var all = Data()
    private var pending = Data()
    private let onLine: (String) -> Void

    init(onLine: @escaping (String) -> Void) {
        self.onLine = onLine
    }

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        all.append(chunk)
        pending.append(chunk)
        var lines: [String] = []
        while let idx = pending.firstIndex(of: 0x0A) {
            let lineData = pending[pending.startIndex..<idx]
            lines.append(String(decoding: lineData, as: UTF8.self))
            pending.removeSubrange(pending.startIndex...idx)
        }
        lock.unlock()
        lines.forEach(onLine)
    }

    func finish() -> Data {
        lock.lock()
        if !pending.isEmpty {
            onLine(String(decoding: pending, as: UTF8.self))
            pending = Data()
        }
        let data = all
        all = Data()
        lock.unlock()
        return data
    }
}

// MARK: - SVN namespace

public enum SVN {
    public static let executable: String = {
        let candidates = [
            "/opt/homebrew/bin/svn",
            "/usr/local/bin/svn",
            "/usr/bin/svn"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/usr/bin/svn"
    }()

    @discardableResult
    public static func run(_ arguments: [String],
                           workingDirectory: String? = nil,
                           task: SVNTask = SVNTask()) async throws -> SVNResult {
        try await runStreaming(arguments, workingDirectory: workingDirectory, task: task) { _ in }
    }

    @discardableResult
    public static func runStreaming(_ arguments: [String],
                                    workingDirectory: String? = nil,
                                    task: SVNTask = SVNTask(),
                                    onLine: @escaping (String) -> Void) async throws -> SVNResult {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw SVNError.notInstalled(executable)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        var environment = ProcessInfo.processInfo.environment
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        process.environment = environment

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let outCollector = LineCollector(onLine: onLine)
        let errCollector = LineCollector(onLine: onLine)

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let resume: (Result<SVNResult, Error>) -> Void = { result in
                guard !resumed else { return }
                resumed = true
                continuation.resume(with: result)
            }

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                outCollector.append(handle.availableData)
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                errCollector.append(handle.availableData)
            }

            process.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                if let tail = try? outPipe.fileHandleForReading.readToEnd() { outCollector.append(tail) }
                if let tail = try? errPipe.fileHandleForReading.readToEnd() { errCollector.append(tail) }
                let outData = outCollector.finish()
                let errData = errCollector.finish()
                let result = SVNResult(
                    stdout: String(decoding: outData, as: UTF8.self),
                    stderr: String(decoding: errData, as: UTF8.self),
                    exitCode: proc.terminationStatus
                )
                if task.isCancelled {
                    resume(.failure(SVNError.cancelled))
                } else if result.succeeded {
                    resume(.success(result))
                } else {
                    resume(.success(result))
                }
            }

            task.attach(process)

            do {
                try process.run()
            } catch {
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                resume(.failure(SVNError.failed(SVNResult(
                    stdout: "",
                    stderr: "Failed to launch \(executable): \(error.localizedDescription)",
                    exitCode: -1
                ))))
            }
        }
    }

    // MARK: Info

    public static func info(at path: String) async throws -> SVNInfo {
        let result = try await run(["info", "--xml", path])
        guard result.succeeded else { throw SVNError.failed(result) }
        return try parseInfo(result.stdout, fallbackPath: path)
    }

    public static func parseInfo(_ xml: String, fallbackPath: String = "") throws -> SVNInfo {
        guard let data = xml.data(using: .utf8), let doc = try? XMLDocument(data: data, options: []) else {
            throw SVNError.xmlParseFailed("svn info")
        }
        func firstString(_ xpath: String) -> String? {
            (try? doc.nodes(forXPath: xpath))?.first?.stringValue
        }
        guard let entry = (try? doc.nodes(forXPath: "//entry"))?.first as? XMLElement else {
            throw SVNError.xmlParseFailed("svn info: no <entry>")
        }
        let path = entry.attribute(forName: "path")?.stringValue ?? fallbackPath
        let url = firstString("//entry/url") ?? ""
        let root = firstString("//entry/repository/root") ?? ""
        let uuid = firstString("//entry/repository/uuid") ?? ""
        let revision = Int(entry.attribute(forName: "revision")?.stringValue ?? "") ?? 0
        let kind = entry.attribute(forName: "kind")?.stringValue ?? "dir"
        var lastRev = revision
        var author = ""
        var date: Date?
        if let commit = (try? doc.nodes(forXPath: "//entry/commit"))?.first as? XMLElement {
            lastRev = Int(commit.attribute(forName: "revision")?.stringValue ?? "") ?? revision
            author = commit.elements(forName: "author").first?.stringValue ?? ""
            date = parseISODate(commit.elements(forName: "date").first?.stringValue)
        }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return SVNInfo(
            path: path,
            name: name,
            url: url,
            repositoryRoot: root,
            repositoryUUID: uuid,
            revision: revision,
            kind: kind,
            lastChangedRevision: lastRev,
            lastChangedAuthor: author,
            lastChangedDate: date,
            branch: branchName(url: url, root: root)
        )
    }

    public static func branchName(url: String, root: String) -> String {
        var relative = url
        if !root.isEmpty, relative.hasPrefix(root) {
            relative = String(relative.dropFirst(root.count))
        }
        relative = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if relative.isEmpty { return "trunk" }
        let components = relative.split(separator: "/").map(String.init)
        if components.first == "trunk" { return "trunk" }
        if components.count >= 2, components[0] == "branches" || components[0] == "tags" {
            return "\(components[0])/\(components[1])"
        }
        return components.last ?? "trunk"
    }

    // MARK: Status

    public static func status(in wcPath: String) async throws -> [SVNStatusEntry] {
        let result = try await run(["status", "--xml", "--depth", "infinity"], workingDirectory: wcPath)
        guard result.succeeded else { throw SVNError.failed(result) }
        return try parseStatus(result.stdout, wcRoot: wcPath)
    }

    public static func parseStatus(_ xml: String, wcRoot: String) throws -> [SVNStatusEntry] {
        guard let data = xml.data(using: .utf8), let doc = try? XMLDocument(data: data, options: []) else {
            throw SVNError.xmlParseFailed("svn status")
        }
        let nodes = (try? doc.nodes(forXPath: "//entry")) ?? []
        var entries: [SVNStatusEntry] = []
        for node in nodes {
            guard let element = node as? XMLElement else { continue }
            let path = element.attribute(forName: "path")?.stringValue ?? ""
            guard !path.isEmpty else { continue }
            guard let wcStatus = element.elements(forName: "wc-status").first else { continue }
            let itemRaw = wcStatus.attribute(forName: "item")?.stringValue ?? ""
            guard let item = SVNStatusEntry.Item(rawValue: itemRaw) else { continue }
            if item == .ignored || item == .external { continue }

            let absolute = URL(fileURLWithPath: wcRoot).appendingPathComponent(path)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: absolute.path, isDirectory: &isDirectory), isDirectory.boolValue {
                continue
            }

            let props = wcStatus.attribute(forName: "props")?.stringValue ?? "none"
            let revision = Int(wcStatus.attribute(forName: "revision")?.stringValue ?? "") ?? 0
            var lastRevision = revision
            var author = ""
            var date: Date?
            if let commit = wcStatus.elements(forName: "commit").first {
                lastRevision = Int(commit.attribute(forName: "revision")?.stringValue ?? "") ?? revision
                author = commit.elements(forName: "author").first?.stringValue ?? ""
                date = parseISODate(commit.elements(forName: "date").first?.stringValue)
            }
            entries.append(SVNStatusEntry(
                path: path,
                item: item,
                props: props,
                revision: revision,
                lastChangedRevision: lastRevision,
                author: author,
                date: date
            ))
        }
        return entries
    }

    // MARK: Diff

    public static func diffText(relativePath: String, in wcPath: String) async throws -> String {
        let result = try await run(["diff", "--non-interactive", relativePath], workingDirectory: wcPath)
        guard result.succeeded else { throw SVNError.failed(result) }
        return result.stdout
    }

    public static func parseDiff(_ text: String, maxLines: Int = 20_000) -> [DiffLine] {
        var lines: [DiffLine] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if lines.count >= maxLines {
                lines.append(DiffLine(kind: .note, text: "Diff truncated (too many lines to display)."))
                break
            }
            let line = String(raw)
            if line.hasPrefix("@@") || line.hasPrefix("## ") || line.hasPrefix("## -") {
                lines.append(DiffLine(kind: .hunk, text: line))
            } else if line.hasPrefix("+++") || line.hasPrefix("---")
                        || line.hasPrefix("Index:") || line.hasPrefix("===")
                        || line.hasPrefix("\\") || line.contains("Cannot display")
                        || line.hasPrefix("Property changes on:") {
                lines.append(DiffLine(kind: .note, text: line))
            } else if line.hasPrefix("+") {
                lines.append(DiffLine(kind: .add, text: String(line.dropFirst())))
            } else if line.hasPrefix("-") {
                lines.append(DiffLine(kind: .remove, text: String(line.dropFirst())))
            } else if line.hasPrefix(" ") {
                lines.append(DiffLine(kind: .context, text: String(line.dropFirst())))
            } else if line.isEmpty {
                lines.append(DiffLine(kind: .context, text: ""))
            } else {
                lines.append(DiffLine(kind: .note, text: line))
            }
        }
        if lines.last?.kind == .context, lines.last?.text == "" {
            lines.removeLast()
        }
        return lines
    }

    public static func missingFileDiff(relativePath: String, in wcPath: String) async -> [DiffLine] {
        do {
            let result = try await run(["cat", "-r", "BASE", relativePath], workingDirectory: wcPath)
            guard result.succeeded else {
                return [DiffLine(kind: .note, text: result.errorText)]
            }
            var contentLines = result.stdout.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if contentLines.last == "" { contentLines.removeLast() }
            var lines: [DiffLine] = [
                DiffLine(kind: .hunk, text: "@@ -1,\(max(contentLines.count, 1)) +0,0 @@")
            ]
            lines.append(contentsOf: contentLines.map { DiffLine(kind: .remove, text: $0) })
            lines.append(DiffLine(kind: .note, text: "File is missing on disk (deleted locally?)"))
            return lines
        } catch {
            return [DiffLine(kind: .note, text: error.localizedDescription)]
        }
    }

    public static func unversionedDiff(atAbsolutePath path: String, maxBytes: Int64 = 3_000_000) async -> [DiffLine] {
        await Task.detached(priority: .userInitiated) {
            let name = URL(fileURLWithPath: path).lastPathComponent
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let size = (attributes[.size] as? NSNumber)?.int64Value else {
                return [DiffLine(kind: .note, text: "File not found on disk: \(path)")]
            }
            if size > maxBytes {
                let formatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                return [
                    DiffLine(kind: .hunk, text: "@@ large file @@"),
                    DiffLine(kind: .note, text: "File too large to preview (\(formatted)). Open it in Finder instead.")
                ]
            }
            guard let data = FileManager.default.contents(atPath: path) else {
                return [DiffLine(kind: .note, text: "File not found on disk: \(path)")]
            }
            let looksBinary = data.contains(0) || String(data: data, encoding: .utf8) == nil
            if looksBinary {
                return [
                    DiffLine(kind: .hunk, text: "@@ binary @@"),
                    DiffLine(kind: .note, text: "Binary file '\(name)' (preview not available)")
                ]
            }
            let text = String(decoding: data, as: UTF8.self)
            var contentLines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if contentLines.last == "" { contentLines.removeLast() }
            var lines: [DiffLine] = [
                DiffLine(kind: .hunk, text: "@@ -0,0 +1,\(contentLines.count) @@")
            ]
            if contentLines.isEmpty {
                lines.append(DiffLine(kind: .note, text: "Empty file"))
            } else {
                lines.append(contentsOf: contentLines.prefix(20_000).map { DiffLine(kind: .add, text: $0) })
            }
            return lines
        }.value
    }

    // MARK: Mutations

    public static func add(paths: [String], wcPath: String) async throws -> SVNResult {
        let result = try await run(["add", "--parents"] + paths, workingDirectory: wcPath)
        guard result.succeeded else { throw SVNError.failed(result) }
        return result
    }

    public static func scheduleDelete(paths: [String], wcPath: String) async throws -> SVNResult {
        let result = try await run(["delete", "--force"] + paths, workingDirectory: wcPath)
        guard result.succeeded else { throw SVNError.failed(result) }
        return result
    }

    public static func revert(paths: [String], wcPath: String) async throws -> SVNResult {
        let result = try await run(["revert"] + paths, workingDirectory: wcPath)
        guard result.succeeded else { throw SVNError.failed(result) }
        return result
    }

    @discardableResult
    public static func update(wcPath: String,
                              task: SVNTask = SVNTask(),
                              onLine: @escaping (String) -> Void) async throws -> SVNResult {
        try await runStreaming(["update", "--non-interactive"], workingDirectory: wcPath, task: task, onLine: onLine)
    }

    @discardableResult
    public static func commit(paths: [String],
                              message: String,
                              keepLocks: Bool,
                              wcPath: String,
                              task: SVNTask = SVNTask(),
                              onLine: @escaping (String) -> Void) async throws -> SVNResult {
        var arguments = ["commit", "-m", message, "--non-interactive"]
        if keepLocks { arguments.append("--no-unlock") }
        arguments.append(contentsOf: paths)
        return try await runStreaming(arguments, workingDirectory: wcPath, task: task, onLine: onLine)
    }

    @discardableResult
    public static func checkout(url: String,
                                destination: String,
                                revision: String?,
                                depth: String,
                                task: SVNTask = SVNTask(),
                                onLine: @escaping (String) -> Void) async throws -> SVNResult {
        var arguments = ["checkout", url, destination, "--non-interactive", "--depth", depth]
        if let revision, !revision.isEmpty, revision.uppercased() != "HEAD" {
            arguments.append(contentsOf: ["--revision", revision])
        }
        return try await runStreaming(arguments, task: task, onLine: onLine)
    }

    // MARK: Ignore

    public static func addIgnore(pattern: String, toDirectory directory: String) async throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SVNError.failed(SVNResult(stdout: "", stderr: "Directory not found: \(directory)", exitCode: -1))
        }

        var patterns: [String] = []
        let getResult = try await run(["propget", "svn:ignore", directory])
        if getResult.succeeded {
            patterns = getResult.stdout.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        } else if !getResult.stderr.contains("W200017") {
            throw SVNError.failed(getResult)
        }

        guard !patterns.contains(pattern) else { return }
        patterns.append(pattern)

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("macsvn-ignore-\(UUID().uuidString).tmp")
        try patterns.joined(separator: "\n").appending("\n").write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }

        let setResult = try await run(["propset", "svn:ignore", "-F", temp.path, directory])
        guard setResult.succeeded else { throw SVNError.failed(setResult) }
    }

    // MARK: Helpers

    static func parseISODate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
