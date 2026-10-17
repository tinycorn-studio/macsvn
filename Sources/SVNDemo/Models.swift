import SwiftUI

enum FileStatus: String, CaseIterable {
    case modified
    case added
    case unversioned
    case missing
    case conflicted
    case normal

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
    let id = UUID()
    var name: String
    var folder: String
    var ext: String
    var status: FileStatus
    var revision: Int
    var author: String
    var date: String
    var isChecked: Bool = true
}

struct WorkingCopy: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var path: String
    var url: String
    var branch: String
    var revision: Int
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

struct DiffLine: Identifiable {
    enum Kind {
        case context
        case add
        case remove
        case hunk
        case note
    }

    let id = UUID()
    let kind: Kind
    let text: String
}
