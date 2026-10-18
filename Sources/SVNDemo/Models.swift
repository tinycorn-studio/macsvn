import SwiftUI
import SVNCore

enum FileStatus: String, CaseIterable {
    case modified
    case added
    case unversioned
    case missing
    case conflicted
    case normal

    init?(from item: SVNStatusEntry.Item) {
        switch item {
        case .modified, .replaced: self = .modified
        case .added: self = .added
        case .unversioned: self = .unversioned
        case .missing, .deleted: self = .missing
        case .conflicted: self = .conflicted
        case .normal: self = .normal
        case .ignored, .external, .incomplete: return nil
        }
    }

    var badge: String {
        switch self {
        case .modified: return "M"
        case .added: return "A"
        case .unversioned: return "?"
        case .missing: return "!"
        case .conflicted: return "C"
        case .normal: return "v"
        }
    }

    var label: String {
        switch self {
        case .modified: return "Modified"
        case .added: return "Added"
        case .unversioned: return "Unversioned"
        case .missing: return "Missing"
        case .conflicted: return "Conflicted"
        case .normal: return "Normal"
        }
    }

    var color: Color {
        switch self {
        case .modified: return .orange
        case .added: return .green
        case .unversioned: return .blue
        case .missing: return .red
        case .conflicted: return .yellow
        case .normal: return .gray
        }
    }

    var isChanged: Bool { self != .normal }
}

struct FileItem: Identifiable {
    var id: String { relativePath }
    var name: String
    var ext: String
    var folder: String
    var relativePath: String
    var absPath: String
    var status: FileStatus
    var revision: Int
    var author: String
    var date: String
    var mtimeKey: String
    var isChecked: Bool = true

    var displayName: String {
        ext.isEmpty ? name : "\(name).\(ext)"
    }

    init?(entry: SVNStatusEntry, wcPath: String) {
        guard let base = FileStatus(from: entry.item) else { return nil }
        let path = entry.path
        let nsPath = path as NSString
        let last = nsPath.lastPathComponent
        let stem = (last as NSString).deletingPathExtension
        let ext = (last as NSString).pathExtension.lowercased()
        let dir = nsPath.deletingLastPathComponent
        let absolute = (wcPath as NSString).appendingPathComponent(path)

        self.name = stem.isEmpty ? last : stem
        self.ext = ext
        self.folder = dir.isEmpty ? "." : dir
        self.relativePath = path
        self.absPath = absolute
        if base == .normal && entry.props == "modified" {
            self.status = .modified
        } else {
            self.status = base
        }
        self.revision = entry.revision > 0 ? entry.revision : entry.lastChangedRevision
        self.author = entry.author
        self.date = FileItem.formatDate(entry.date)
        self.mtimeKey = FileItem.modificationKey(forAbsPath: absolute)
        self.isChecked = true
    }

    private static func modificationKey(forAbsPath path: String) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attributes[.modificationDate] as? Date else { return "none" }
        return String(date.timeIntervalSince1970)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd/MM"
        return formatter
    }()

    static func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return dateFormatter.string(from: date)
    }
}

struct WorkingCopy: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var url: String
    var branch: String
    var revision: Int

    init(info: SVNInfo) {
        self.name = info.name
        self.path = info.path
        self.url = info.url
        self.branch = info.branch
        self.revision = info.revision
    }

    init(name: String, path: String, url: String, branch: String, revision: Int) {
        self.name = name
        self.path = path
        self.url = url
        self.branch = branch
        self.revision = revision
    }
}

struct DiffDisplayLine: Identifiable {
    let id: Int
    let kind: DiffLine.Kind
    let text: String
    let oldNumber: Int?
    let newNumber: Int?
}

enum DiffNumbering {
    private static let hunkRegex = try? NSRegularExpression(pattern: #"@@ -(\d+)(?:,\d+)? \+(\d+)"#)

    static func parseHunk(_ text: String) -> (old: Int, new: Int)? {
        guard let regex = hunkRegex else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 3,
              let oldStart = Int(ns.substring(with: match.range(at: 1))),
              let newStart = Int(ns.substring(with: match.range(at: 2))) else { return nil }
        return (oldStart, newStart)
    }

    static func build(_ lines: [DiffLine]) -> [DiffDisplayLine] {
        var oldLine = 0
        var newLine = 0
        var rows: [DiffDisplayLine] = []
        rows.reserveCapacity(lines.count)
        for (index, line) in lines.enumerated() {
            switch line.kind {
            case .hunk:
                if let start = parseHunk(line.text) {
                    oldLine = start.old
                    newLine = start.new
                }
                rows.append(DiffDisplayLine(id: index, kind: .hunk, text: line.text, oldNumber: nil, newNumber: nil))
            case .context:
                rows.append(DiffDisplayLine(id: index, kind: .context, text: line.text, oldNumber: oldLine, newNumber: newLine))
                oldLine += 1
                newLine += 1
            case .remove:
                rows.append(DiffDisplayLine(id: index, kind: .remove, text: line.text, oldNumber: oldLine, newNumber: nil))
                oldLine += 1
            case .add:
                rows.append(DiffDisplayLine(id: index, kind: .add, text: line.text, oldNumber: nil, newNumber: newLine))
                newLine += 1
            case .note:
                rows.append(DiffDisplayLine(id: index, kind: .note, text: line.text, oldNumber: nil, newNumber: nil))
            }
        }
        return rows
    }
}

enum ChangeViewMode: String {
    case files
    case folders
}

enum GroupCheck {
    case on
    case off
    case mixed
}

struct FolderGroup: Identifiable {
    let key: String
    let files: [FileItem]

    var id: String { key }
    var label: String { key.isEmpty ? "Root files" : key }
    var count: Int { files.count }
    var summary: String { StatusSummary.text(of: files) }

    var checkState: GroupCheck {
        let checked = files.filter(\.isChecked).count
        if checked == 0 { return .off }
        if checked == files.count { return .on }
        return .mixed
    }
}

enum StatusSummary {
    static func counts(of files: [FileItem]) -> (modified: Int, added: Int, unversioned: Int, missing: Int, conflicted: Int) {
        var modified = 0, added = 0, unversioned = 0, missing = 0, conflicted = 0
        for file in files {
            switch file.status {
            case .modified: modified += 1
            case .added: added += 1
            case .unversioned: unversioned += 1
            case .missing: missing += 1
            case .conflicted: conflicted += 1
            case .normal: break
            }
        }
        return (modified, added, unversioned, missing, conflicted)
    }

    static func text(of files: [FileItem]) -> String {
        let c = counts(of: files)
        return "\(c.modified)M \(c.added)A \(c.unversioned)? \(c.missing)! \(c.conflicted)C"
    }
}

enum StatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case modified = "Modified"
    case added = "Added"
    case unversioned = "Unversioned"
    case missing = "Missing"
    case conflicted = "Conflicted"

    var id: String { rawValue }

    func matches(_ status: FileStatus) -> Bool {
        switch self {
        case .all: return true
        case .modified: return status == .modified
        case .added: return status == .added
        case .unversioned: return status == .unversioned
        case .missing: return status == .missing
        case .conflicted: return status == .conflicted
        }
    }
}
