import Foundation
import SVNCore

let usage = """
Usage: svncli <command> [args]

Commands:
  which                     Print resolved svn executable
  info <path>               Show working copy info (read-only)
  status <wc-path>          List changed files (read-only)
  diff <wc-path> <file>     Show diff of a file relative to WC root (read-only)
  log <wc-path> [limit]     Show recent commits with changed paths (read-only)
  rdiff <wc-path> <rev> <path>  Diff of a path in a revision (read-only)
  ignore <dir> <pattern>    Add pattern to svn:ignore of a versioned directory
"""

let arguments = CommandLine.arguments

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard arguments.count >= 2 else {
    print(usage)
    exit(2)
}

switch arguments[1] {
case "which":
    print(SVN.executable)

case "info":
    guard arguments.count >= 3 else { fail("Missing <path>") }
    do {
        let info = try await SVN.info(at: arguments[2])
        print("Path:       \(info.path)")
        print("Name:       \(info.name)")
        print("URL:        \(info.url)")
        print("Root:       \(info.repositoryRoot)")
        print("Revision:   \(info.revision)")
        print("Branch:     \(info.branch)")
        print("LastChange: r\(info.lastChangedRevision) by \(info.lastChangedAuthor)")
        print("Kind:       \(info.kind)")
    } catch {
        fail("error: \(error.localizedDescription)")
    }

case "status":
    guard arguments.count >= 3 else { fail("Missing <wc-path>") }
    do {
        let entries = try await SVN.status(in: arguments[2])
        if entries.isEmpty { print("(clean)") }
        for entry in entries {
            let badge: String
            switch entry.item {
            case .modified, .replaced: badge = "M"
            case .added: badge = "A"
            case .deleted: badge = "D"
            case .unversioned: badge = "?"
            case .missing: badge = "!"
            case .conflicted: badge = "C"
            case .normal: badge = entry.props == "modified" ? "M" : " "
            default: badge = " "
            }
            let author = entry.author.isEmpty ? "-" : entry.author
            print("\(badge)  \(entry.path)  r\(entry.revision)  \(author)")
        }
        print("(\(entries.count) changed)")
    } catch {
        fail("error: \(error.localizedDescription)")
    }

case "diff":
    guard arguments.count >= 4 else { fail("Missing <wc-path> <file>") }
    do {
        let text = try await SVN.diffText(relativePath: arguments[3], in: arguments[2])
        let lines = SVN.parseDiff(text)
        if lines.isEmpty { print("(no diff)") }
        for line in lines {
            switch line.kind {
            case .add: print("+ \(line.text)")
            case .remove: print("- \(line.text)")
            case .context: print("  \(line.text)")
            case .hunk: print(line.text)
            case .note: print("! \(line.text)")
            }
        }
    } catch {
        fail("error: \(error.localizedDescription)")
    }

case "log":
    guard arguments.count >= 3 else { fail("Missing <wc-path>") }
    let limit = arguments.count >= 4 ? (Int(arguments[3]) ?? 10) : 10
    do {
        let entries = try await SVN.log(in: arguments[2], limit: limit)
        for entry in entries {
            print("r\(entry.revision)  \(entry.author.isEmpty ? "-" : entry.author)  \(entry.date.map(String.init(describing:)) ?? "")")
            print(entry.message.isEmpty ? "  (no message)" : entry.message.split(separator: "\n").map { "  \($0)" }.joined(separator: "\n"))
            for path in entry.paths {
                print("  \(path.action)  \(path.path)\(path.kind == "dir" ? "/" : "")")
            }
        }
        print("(\(entries.count) entries)")
    } catch {
        fail("error: \(error.localizedDescription)")
    }

case "rdiff":
    guard arguments.count >= 5 else { fail("Missing <wc-path> <revision> <path>") }
    guard let revision = Int(arguments[3]) else { fail("Invalid <revision>") }
    do {
        let text = try await SVN.diffRevision(relativePath: arguments[4], revision: revision, in: arguments[2])
        let lines = SVN.parseDiff(text)
        if lines.isEmpty { print("(no diff)") }
        for line in lines {
            switch line.kind {
            case .add: print("+ \(line.text)")
            case .remove: print("- \(line.text)")
            case .context: print("  \(line.text)")
            case .hunk: print(line.text)
            case .note: print("! \(line.text)")
            }
        }
    } catch {
        fail("error: \(error.localizedDescription)")
    }

case "ignore":
    guard arguments.count >= 4 else { fail("Missing <dir> <pattern>") }
    do {
        try await SVN.addIgnore(pattern: arguments[3], toDirectory: arguments[2])
        print("ignore added")
    } catch {
        fail("error: \(error.localizedDescription)")
    }

default:
    print(usage)
    exit(2)
}
