import Foundation

enum Mock {
    static let home = NSHomeDirectory()

    static let workingCopies: [WorkingCopy] = [
        WorkingCopy(
            name: "ExampleApp",
            path: home + "/Projects/ExampleApp",
            url: "http://svn.example.com/repos/example/ExampleApp",
            branch: "trunk",
            revision: 1523
        ),
        WorkingCopy(
            name: "ExampleApp_Docs",
            path: home + "/Projects/ExampleApp_Docs",
            url: "http://svn.example.com/repos/example/ExampleApp/branches/docs",
            branch: "branches/docs",
            revision: 1487
        )
    ]

    static let files: [FileItem] = [
        FileItem(name: "App", folder: "src", ext: "swift", status: .modified, revision: 1515, author: "an", date: "20:41 16/10"),
        FileItem(name: "Engine", folder: "src/Core", ext: "swift", status: .modified, revision: 1520, author: "an", date: "20:39 16/10"),
        FileItem(name: "ContentView", folder: "src/Views", ext: "swift", status: .modified, revision: 1518, author: "binh", date: "18:12 16/10"),
        FileItem(name: "MainWindow", folder: "src/Views", ext: "swift", status: .modified, revision: 1521, author: "an", date: "20:44 16/10"),
        FileItem(name: "logo", folder: "Resources", ext: "png", status: .modified, revision: 1519, author: "an", date: "19:55 16/10"),
        FileItem(name: "settings", folder: "Config", ext: "json", status: .modified, revision: 1522, author: "an", date: "20:47 16/10"),
        FileItem(name: "manifest", folder: "build", ext: "json", status: .modified, revision: 1523, author: "binh", date: "17:30 16/10"),
        FileItem(name: "Report", folder: "docs", ext: "xlsx", status: .modified, revision: 1510, author: "chi", date: "15:02 16/10"),
        FileItem(name: "guide", folder: "docs", ext: "md", status: .modified, revision: 1522, author: "an", date: "20:45 16/10"),
        FileItem(name: "theme", folder: "Resources", ext: "json", status: .modified, revision: 1513, author: "an", date: "20:30 16/10"),
        FileItem(name: "icon", folder: "Resources", ext: "png", status: .added, revision: 1523, author: "an", date: "20:50 16/10"),
        FileItem(name: "StringExt", folder: "src/Utils", ext: "swift", status: .added, revision: 1523, author: "an", date: "20:51 16/10"),
        FileItem(name: "output", folder: "generated", ext: "json", status: .added, revision: 1523, author: "an", date: "20:52 16/10"),
        FileItem(name: "backup", folder: "Config", ext: "json", status: .unversioned, revision: 0, author: "", date: "20:55 16/10"),
        FileItem(name: "old_icon", folder: "Resources", ext: "png", status: .unversioned, revision: 0, author: "", date: "20:56 16/10"),
        FileItem(name: "scratch", folder: "tmp", ext: "txt", status: .unversioned, revision: 0, author: "", date: "20:57 16/10"),
        FileItem(name: "build_log", folder: "logs", ext: "txt", status: .unversioned, revision: 0, author: "", date: "20:58 16/10"),
        FileItem(name: ".DS_Store", folder: ".", ext: "", status: .unversioned, revision: 0, author: "", date: "21:00 16/10"),
        FileItem(name: "legacy", folder: "Config", ext: "json", status: .missing, revision: 1499, author: "binh", date: "12:10 15/10"),
        FileItem(name: "LoginView", folder: "src/Views", ext: "swift", status: .conflicted, revision: 1523, author: "binh", date: "17:31 16/10")
    ]
}

extension FileItem {
    var displayName: String {
        ext.isEmpty ? name : "\(name).\(ext)"
    }

    private var isBinary: Bool {
        ["png", "xlsx"].contains(ext)
    }

    var mockDiff: [DiffLine] {
        switch status {
        case .normal:
            return []
        case .added, .unversioned:
            if isBinary {
                return [
                    DiffLine(kind: .hunk, text: "@@ -0,0 +1 @@"),
                    DiffLine(kind: .note, text: "Binary file '\(displayName)' added (preview not available)")
                ]
            }
            return [
                DiffLine(kind: .hunk, text: "@@ -0,0 +1,6 @@"),
                DiffLine(kind: .add, text: "// \(displayName) - new file"),
                DiffLine(kind: .add, text: "import Foundation"),
                DiffLine(kind: .add, text: ""),
                DiffLine(kind: .add, text: "struct \(name) {"),
                DiffLine(kind: .add, text: "    // TODO: implement"),
                DiffLine(kind: .add, text: "}")
            ]
        case .missing:
            return [
                DiffLine(kind: .hunk, text: "@@ -1,5 +0,0 @@"),
                DiffLine(kind: .remove, text: "// \(displayName)"),
                DiffLine(kind: .remove, text: "{ \"version\": 1 }"),
                DiffLine(kind: .note, text: "File is missing on disk (deleted locally?)")
            ]
        case .conflicted:
            return [
                DiffLine(kind: .hunk, text: "@@ -118,12 +118,18 @@"),
                DiffLine(kind: .context, text: "    let retryCount = 3"),
                DiffLine(kind: .remove, text: "<<<<<<< .mine"),
                DiffLine(kind: .remove, text: "    let timeout = 30"),
                DiffLine(kind: .add, text: "    let timeout = 60"),
                DiffLine(kind: .add, text: "======="),
                DiffLine(kind: .add, text: "    let timeout = 30"),
                DiffLine(kind: .add, text: ">>>>>>> .r1523"),
                DiffLine(kind: .context, text: "    let bufferSize = 4096"),
                DiffLine(kind: .note, text: "Conflict - resolve before committing")
            ]
        case .modified:
            if isBinary {
                return [
                    DiffLine(kind: .hunk, text: "@@ binary @@"),
                    DiffLine(kind: .note, text: "Binary file '\(displayName)' modified (preview not available)")
                ]
            }
            return [
                DiffLine(kind: .hunk, text: "@@ -12,7 +12,9 @@"),
                DiffLine(kind: .context, text: "    func process() {"),
                DiffLine(kind: .context, text: "        let chunk = readChunk()"),
                DiffLine(kind: .remove, text: "        queue.append(chunk)"),
                DiffLine(kind: .add, text: "        guard !chunk.isEmpty else { return }"),
                DiffLine(kind: .add, text: "        queue.append(chunk)"),
                DiffLine(kind: .context, text: "        if queue.count > limit {"),
                DiffLine(kind: .context, text: "            flush()"),
                DiffLine(kind: .context, text: "        }")
            ]
        }
    }
}
