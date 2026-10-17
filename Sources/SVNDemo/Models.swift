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
