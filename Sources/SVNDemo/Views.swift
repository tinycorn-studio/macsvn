import SwiftUI
import AppKit
import SVNCore

enum ForkTheme {
    private static func dyn(_ dark: NSColor, _ light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        })
    }

    private static func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
    }

    static let bg = dyn(c(0.121, 0.125, 0.137), c(0.965, 0.965, 0.973))
    static let panel = dyn(c(0.145, 0.149, 0.165), c(0.937, 0.937, 0.945))
    static let sidebar = dyn(c(0.106, 0.110, 0.122), c(0.918, 0.918, 0.929))
    static let rowSelected = dyn(c(0.223, 0.333, 0.588), c(0.251, 0.451, 0.902))
    static let accent = dyn(c(0.357, 0.565, 1.0), c(0.196, 0.416, 0.929))
    static let textPrimary = dyn(c(0.93, 0.93, 0.93), c(0.13, 0.13, 0.14))
    static let textSecondary = dyn(c(0.58, 0.58, 0.58), c(0.44, 0.44, 0.47))
    static let addBG = dyn(c(0.157, 0.408, 0.239), c(0.839, 0.953, 0.867))
    static let addText = dyn(c(0.596, 0.910, 0.659), c(0.063, 0.396, 0.153))
    static let delBG = dyn(c(0.463, 0.180, 0.200), c(0.988, 0.867, 0.878))
    static let delText = dyn(c(0.969, 0.616, 0.624), c(0.667, 0.106, 0.153))
    static let hunkText = dyn(c(0.573, 0.478, 0.965), c(0.416, 0.278, 0.851))
    static let border = dyn(c(0.24, 0.24, 0.24), c(0.796, 0.796, 0.827))
    static let buttonTint = dyn(c(0.30, 0.30, 0.32), c(0.855, 0.855, 0.878))
}

struct ContentView: View {
    private static let wcPathsKey = "wcPaths"
    private static let recentMessagesKey = "recentMessages"

    @State private var workingCopies: [WorkingCopy] = []
    @State private var selectedWCID: String?
    @State private var files: [FileItem] = []
    @State private var filter: StatusFilter = .all
    @State private var search = ""
    @State private var selectedFileID: String?
    @AppStorage("changesViewMode") private var changeViewMode: ChangeViewMode = .files
    @State private var openedFolder: String?

    @State private var activeTab: MainTab = .changes
    @State private var logEntries: [LogEntry] = []
    @State private var isLoadingLog = false
    @State private var logTask: Task<Void, Never>?
    @State private var logLimit = 100
    @State private var logSearch = ""
    @State private var selectedRevision: Int?
    @State private var historyScope: String?
    @State private var revisionSelectedPath: LogPath?
    @State private var revisionDiffRows: [DiffDisplayLine] = []
    @State private var isLoadingRevisionDiff = false
    @State private var revisionDiffTask: Task<Void, Never>?

    @State private var diffLines: [DiffLine] = []
    @State private var diffRows: [DiffDisplayLine] = []
    @State private var isLoadingDiff = false
    @State private var diffTask: Task<Void, Never>?
    @State private var prefetchTask: Task<Void, Never>?
    @State private var diffCache: [String: [DiffLine]] = [:]

    @State private var showCommit = false
    @State private var showCheckout = false
    @State private var showRevertConfirm = false
    @State private var toast: String?
    @State private var draftMessage = ""
    @State private var recentMessages: [String] = []
    @State private var isRefreshing = false
    @State private var appError: String?
    @StateObject private var operation = OperationController()
    @AppStorage("backupBeforeRevert") private var backupBeforeRevert = true

    private var activeWC: WorkingCopy? {
        workingCopies.first { $0.path == selectedWCID } ?? workingCopies.first
    }

    private var visibleFiles: [FileItem] {
        files.filter { item in
            item.status.isChanged
                && filter.matches(item.status)
                && (search.isEmpty
                    || item.name.localizedCaseInsensitiveContains(search)
                    || item.folder.localizedCaseInsensitiveContains(search))
        }
    }

    private var checkedFiles: [FileItem] {
        files.filter { $0.isChecked && $0.status.isChanged }
    }

    private var isFolderListView: Bool {
        changeViewMode == .folders && openedFolder == nil
    }

    private var isFolderDrillView: Bool {
        changeViewMode == .folders && openedFolder != nil
    }

    private var scopedFiles: [FileItem] {
        guard changeViewMode == .folders, let opened = openedFolder else { return visibleFiles }
        if opened.isEmpty {
            return visibleFiles.filter { !$0.relativePath.contains("/") }
        }
        return visibleFiles.filter { $0.relativePath == opened || $0.relativePath.hasPrefix(opened + "/") }
    }

    private var folderGroups: [FolderGroup] {
        var map: [String: [FileItem]] = [:]
        for item in visibleFiles {
            map[topFolder(of: item), default: []].append(item)
        }
        let keys = map.keys.sorted { a, b in
            if a.isEmpty != b.isEmpty { return !a.isEmpty }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
        return keys.map { FolderGroup(key: $0, files: map[$0] ?? []) }
    }

    private func topFolder(of item: FileItem) -> String {
        guard let index = item.relativePath.firstIndex(of: "/") else { return "" }
        return String(item.relativePath[..<index])
    }

    private var focusedFile: FileItem? {
        if isFolderListView { return nil }
        if let selectedFileID, let item = scopedFiles.first(where: { $0.id == selectedFileID }) {
            return item
        }
        return scopedFiles.first
    }

    private func count(of status: FileStatus) -> Int {
        files.filter { $0.status == status }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            hr
            Group {
                if workingCopies.isEmpty {
                    WelcomeView(
                        onAdd: { addExistingWorkingCopy() },
                        onCheckout: { showCheckout = true }
                    )
                } else {
                    HSplitView {
                        sidebarPanel
                            .frame(minWidth: 160, idealWidth: 210, maxWidth: 320)
                        if activeTab == .changes {
                            changesPanel
                                .frame(minWidth: 240, idealWidth: 320, maxWidth: 460)
                            diffPanel
                                .frame(minWidth: 280, maxWidth: .infinity)
                        } else {
                            historyPanel
                                .frame(minWidth: 240, idealWidth: 320, maxWidth: 460)
                            revisionDetailPanel
                                .frame(minWidth: 280, maxWidth: .infinity)
                        }
                    }
                }
            }
            if activeWC != nil && activeTab == .changes {
                hr
                commitBar
            }
        }
        .background(ForkTheme.bg)
        .sheet(isPresented: $showCommit) {
            if let wc = activeWC {
                CommitSheet(wc: wc, files: $files, recentMessages: recentMessages) { items, message, keepLocks in
                    performCommit(items: items, message: message, keepLocks: keepLocks)
                }
            }
        }
        .sheet(isPresented: $showCheckout) {
            CheckoutSheet { url, destination, revision, depth in
                performCheckout(url: url, destination: destination, revision: revision, depth: depth)
            }
        }
        .sheet(isPresented: $operation.isPresented) {
            OperationProgressSheet(operation: operation)
        }
        .alert("Revert \(checkedFiles.count) file(s)?", isPresented: $showRevertConfirm) {
            Button("Revert", role: .destructive) { performRevert() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(revertAlertMessage)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.callout)
                    .foregroundStyle(ForkTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ForkTheme.panel, in: Capsule())
                    .overlay(Capsule().stroke(ForkTheme.border))
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            loadRecentMessages()
            await loadWorkingCopies()
        }
        .task(id: selectedWCID) {
            openedFolder = nil
            resetHistory()
            await refreshStatus()
            if activeTab == .history {
                reloadLog()
            }
        }
        .task(id: activeTab) {
            if activeTab == .history && logEntries.isEmpty && !isLoadingLog {
                reloadLog()
            }
        }
        .onChange(of: focusedFile?.id) { _, _ in
            loadDiff()
        }
        .frame(minWidth: 760, minHeight: 560)
    }

    private var hr: some View {
        Rectangle().fill(ForkTheme.border).frame(height: 1)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(ForkTheme.accent)
            Text("MacSVN")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ForkTheme.textPrimary)
            Text(activeWC?.name ?? "No working copy")
                .font(.system(size: 12))
                .foregroundStyle(ForkTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            tabSwitcher

            Spacer(minLength: 8)

            if let wc = activeWC {
                HStack(spacing: 6) {
                    Text(wc.branch)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(ForkTheme.panel, in: Capsule())
                        .foregroundStyle(ForkTheme.textPrimary)
                    Text("r\(wc.revision)")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.22), in: Capsule())
                        .foregroundStyle(.green)
                }
            }

            Spacer(minLength: 8)

            toolbarIcon("square.and.arrow.down", "Checkout...") { showCheckout = true }
            toolbarIcon("arrow.uturn.backward", "Revert - discard changes...") { showRevertConfirm = true }
                .disabled(checkedFiles.isEmpty)
            toolbarIcon("arrow.clockwise", "Refresh status") {
                if activeTab == .history {
                    reloadLog()
                } else {
                    Task { await refreshStatus() }
                }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(activeWC == nil)

            HStack(spacing: 0) {
                Button {
                    runUpdate()
                } label: {
                    Label("Update", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.leading, 10)
                        .padding(.trailing, 6)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Update entire working copy")
                .disabled(activeWC == nil)

                Rectangle()
                    .fill(ForkTheme.border)
                    .frame(width: 1, height: 14)

                Menu {
                    Button("Update Entire Working Copy") { runUpdate() }
                    Button("Update Folder...") { chooseFolderAndUpdate() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Update options")
                .disabled(activeWC == nil)
            }
            .foregroundStyle(ForkTheme.textPrimary)
            .background(ForkTheme.buttonTint, in: RoundedRectangle(cornerRadius: 6))
            .opacity(activeWC == nil ? 0.5 : 1)

            Menu {
                Toggle("Backup files before Revert", isOn: $backupBeforeRevert)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ForkTheme.textPrimary)
                    .frame(width: 28, height: 24)
                    .background(ForkTheme.panel, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(ForkTheme.sidebar)
    }

    private func toolbarIcon(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ForkTheme.textPrimary)
                .frame(width: 28, height: 24)
                .background(ForkTheme.panel, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var tabSwitcher: some View {
        HStack(spacing: 2) {
            tabSegment(.changes, symbol: "list.bullet", title: "Changes")
            tabSegment(.history, symbol: "clock.arrow.circlepath", title: "History")
        }
        .padding(2)
        .background(ForkTheme.bg, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(ForkTheme.border))
    }

    private func tabSegment(_ tab: MainTab, symbol: String, title: String) -> some View {
        let active = activeTab == tab
        return Button {
            activeTab = tab
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(active ? .white : ForkTheme.textSecondary)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(active ? ForkTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab == .changes ? "Working copy changes" : "Commit history (svn log)")
    }

    private var sidebarPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REPOSITORIES")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ForkTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(workingCopies) { wc in
                        wcRow(wc)
                    }
                }
                .padding(.horizontal, 6)
            }

            hr

            Menu {
                Button("Add Existing Working Copy...") { addExistingWorkingCopy() }
                Button("Checkout New Working Copy...") { showCheckout = true }
            } label: {
                Label("Add working copy...", systemImage: "plus.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(ForkTheme.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .padding(12)
        }
        .background(ForkTheme.sidebar)
    }

    private func wcRow(_ wc: WorkingCopy) -> some View {
        let selected = wc.path == selectedWCID
        return HStack(spacing: 8) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 12))
                .foregroundStyle(selected ? .white : ForkTheme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(wc.name)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .white : ForkTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(wc.branch) - r\(wc.revision)")
                    .font(.system(size: 10))
                    .foregroundStyle(selected ? Color.white.opacity(0.75) : ForkTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(selected ? ForkTheme.rowSelected : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { selectedWCID = wc.path }
        .contextMenu {
            Button("Update Working Copy") { runUpdate(for: wc) }
            Button("Update Folder...") { chooseFolderAndUpdate(for: wc) }
            Divider()
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: wc.path)])
            }
            Divider()
            Button("Remove from List") { removeWorkingCopy(wc) }
        }
    }

    private var changesPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Changes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ForkTheme.textPrimary)
                Text("\(scopedFiles.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ForkTheme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(ForkTheme.accent.opacity(0.16), in: Capsule())
                if isFolderListView {
                    Text("in \(folderGroups.count) folder\(folderGroups.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(ForkTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                viewModeToggle
                Menu {
                    ForEach(StatusFilter.allCases) { f in
                        Button("\(f.rawValue) (\(filterCount(f)))") { filter = f }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(filter.rawValue)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(ForkTheme.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(ForkTheme.textSecondary)
                TextField("Filter files", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(ForkTheme.textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ForkTheme.bg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            if let appError {
                errorBanner(appError)
            }

            if isFolderDrillView {
                hr
                folderBreadcrumb
            }

            hr

            ZStack {
                if visibleFiles.isEmpty {
                    emptyStateView
                } else if isFolderListView {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(folderGroups) { group in
                                folderRow(group)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else if scopedFiles.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(scopedFiles) { item in
                                changeRow(item)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .focusable()
                    .focusEffectDisabled()
                    .onKeyPress(.downArrow) {
                        moveFocus(1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        moveFocus(-1)
                        return .handled
                    }
                    .onKeyPress(.space) {
                        toggleFocused()
                        return .handled
                    }
                    .help("Keys: up/down navigate, Space toggle, Cmd+Return commit")
                }

                if isRefreshing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking for modifications...")
                            .font(.system(size: 11))
                            .foregroundStyle(ForkTheme.textSecondary)
                    }
                    .padding(16)
                    .background(ForkTheme.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ForkTheme.border))
                }
            }

            hr

            HStack(spacing: 8) {
                Button("Check all") {
                    let ids = Set(scopedFiles.map(\.id))
                    for i in files.indices where ids.contains(files[i].id) {
                        files[i].isChecked = true
                    }
                }
                .fixedSize()
                Button("Uncheck all") {
                    let ids = Set(scopedFiles.map(\.id))
                    for i in files.indices where ids.contains(files[i].id) {
                        files[i].isChecked = false
                    }
                }
                .fixedSize()
                Spacer(minLength: 4)
                Text(summaryText)
                    .font(.system(size: 10))
                    .foregroundStyle(ForkTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(ForkTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .background(ForkTheme.panel)
    }

    private func filterCount(_ f: StatusFilter) -> Int {
        switch f {
        case .all: return files.filter { $0.status.isChanged }.count
        case .modified: return count(of: .modified)
        case .added: return count(of: .added)
        case .unversioned: return count(of: .unversioned)
        case .missing: return count(of: .missing)
        case .conflicted: return count(of: .conflicted)
        }
    }

    private var summaryText: String {
        StatusSummary.text(of: scopedFiles)
    }

    private var viewModeToggle: some View {
        HStack(spacing: 2) {
            viewModeSegment(.files, symbol: "list.bullet", title: "Files")
            viewModeSegment(.folders, symbol: "folder", title: "Folders")
        }
        .padding(2)
        .background(ForkTheme.bg, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(ForkTheme.border))
    }

    private func viewModeSegment(_ mode: ChangeViewMode, symbol: String, title: String) -> some View {
        let active = changeViewMode == mode
        return Button {
            changeViewMode = mode
            if mode == .files {
                openedFolder = nil
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .medium))
                if active {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundStyle(active ? .white : ForkTheme.textSecondary)
            .padding(.horizontal, active ? 6 : 5)
            .frame(height: 20)
            .background(active ? ForkTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(mode == .files ? "View as flat file list" : "View grouped by top-level folder")
    }

    private var folderBreadcrumb: some View {
        HStack(spacing: 6) {
            Button {
                openedFolder = nil
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Folders")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ForkTheme.accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("/")
                .font(.system(size: 11))
                .foregroundStyle(ForkTheme.textSecondary)
            Image(systemName: "folder.fill")
                .font(.system(size: 10))
                .foregroundStyle(ForkTheme.accent)
            Text(openedFolder?.isEmpty == true ? "Root files" : (openedFolder ?? ""))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ForkTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Text("\(scopedFiles.filter(\.isChecked).count) of \(scopedFiles.count) checked")
                .font(.system(size: 10))
                .foregroundStyle(ForkTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func folderRow(_ group: FolderGroup) -> some View {
        HStack(spacing: 9) {
            Button {
                toggleGroup(group)
            } label: {
                Image(systemName: group.checkState == .on
                      ? "checkmark.circle.fill"
                      : group.checkState == .off ? "circle" : "minus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(group.checkState == .on ? ForkTheme.accent : ForkTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Check or uncheck all files in this folder")

            Image(systemName: "folder.fill")
                .font(.system(size: 13))
                .foregroundStyle(ForkTheme.accent)

            Text(group.label)
                .font(.system(size: 12))
                .foregroundStyle(ForkTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            Text(group.summary)
                .font(.system(size: 10))
                .foregroundStyle(ForkTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("\(group.count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ForkTheme.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(ForkTheme.accent.opacity(0.16), in: Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ForkTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { openedFolder = group.key }
        .contextMenu { folderMenu(group) }
    }

    @ViewBuilder
    private func folderMenu(_ group: FolderGroup) -> some View {
        Button("Open \"\(group.label)\"") { openedFolder = group.key }
        if !group.key.isEmpty {
            Button("Update Folder \"\(group.label)\"") {
                runUpdate(relativePaths: [group.key], label: group.label)
            }
            Button("Show History") { showHistory(for: group.key) }
        }
        Divider()
        Button("Check all") { setGroup(group, checked: true) }
        Button("Uncheck all") { setGroup(group, checked: false) }
        Divider()
        Button("Commit...") {
            setGroup(group, checked: true)
            showCommit = true
        }
        Button("Revert (discard changes)...") {
            setGroup(group, checked: true)
            showRevertConfirm = true
        }
        Divider()
        Button("Open in Finder") {
            guard let wc = activeWC else { return }
            let abs = group.key.isEmpty ? wc.path : (wc.path as NSString).appendingPathComponent(group.key)
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: abs)])
        }
    }

    private func setGroup(_ group: FolderGroup, checked: Bool) {
        let ids = Set(group.files.map(\.id))
        for i in files.indices where ids.contains(files[i].id) {
            files[i].isChecked = checked
        }
    }

    private func toggleGroup(_ group: FolderGroup) {
        setGroup(group, checked: group.checkState != .on)
    }

    private func rowSubpath(_ item: FileItem) -> String? {
        if changeViewMode == .folders, let opened = openedFolder {
            if opened.isEmpty { return nil }
            if item.relativePath.hasPrefix(opened + "/") {
                let dir = (item.relativePath as NSString).deletingLastPathComponent
                let relative = dir == opened ? "" : String(dir.dropFirst(opened.count + 1))
                return relative.isEmpty ? nil : relative
            }
        }
        return item.folder
    }

    private func changeRow(_ item: FileItem) -> some View {
        let selected = item.id == focusedFile?.id
        return HStack(spacing: 9) {
            Button {
                if let idx = files.firstIndex(where: { $0.id == item.id }) {
                    files[idx].isChecked.toggle()
                }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(item.isChecked ? ForkTheme.accent : ForkTheme.textSecondary)
            }
            .buttonStyle(.plain)

            Text(item.status.badge)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(item.status.color)
                .frame(width: 15)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(ForkTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let subpath = rowSubpath(item) {
                    Text(subpath)
                        .font(.system(size: 10))
                        .foregroundStyle(ForkTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(selected ? ForkTheme.rowSelected.opacity(0.45) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectedFileID = item.id }
        .contextMenu { rowMenu(item) }
    }

    @ViewBuilder
    private func rowMenu(_ item: FileItem) -> some View {
        Menu("Update") {
            Button("Update \"\(item.displayName)\"") {
                runUpdate(relativePaths: [item.relativePath], label: item.displayName)
            }
            if item.folder != "." {
                Button("Update Folder \"\(item.folder)\"") {
                    runUpdate(relativePaths: [item.folder], label: item.folder)
                }
            }
            Divider()
            Button("Update Folder...") { chooseFolderAndUpdate() }
            Button("Update Entire Working Copy") { runUpdate() }
        }
        Button("Commit...") {
            if let idx = files.firstIndex(where: { $0.id == item.id }) {
                files[idx].isChecked = true
            }
            selectedFileID = item.id
            showCommit = true
        }
        Button("Revert (discard changes)...") {
            if let idx = files.firstIndex(where: { $0.id == item.id }) {
                files[idx].isChecked = true
            }
            showRevertConfirm = true
        }
        if item.status == .unversioned {
            Divider()
            Menu("Ignore") {
                Button("Ignore \"\(item.displayName)\"") { ignore(item, mode: .file) }
                if !item.ext.isEmpty {
                    Button("Ignore all *.\(item.ext) files") { ignore(item, mode: .extension) }
                }
                if item.folder != "." {
                    Button("Ignore folder \"\(item.folder)\"") { ignore(item, mode: .folder) }
                }
            }
        }
        Divider()
        Button("Show History") { showHistory(for: item.relativePath) }
        Button("Open in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.absPath)])
        }
    }

    private var diffPanel: some View {
        VStack(spacing: 0) {
            if let file = focusedFile {
                HStack(spacing: 8) {
                    StatusBadge(status: file.status)
                    Text(file.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ForkTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(1)
                    Text(file.folder)
                        .font(.system(size: 11))
                        .foregroundStyle(ForkTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer(minLength: 8)
                    if isLoadingDiff {
                        ProgressView()
                            .controlSize(.small)
                    }
                    if file.revision > 0 {
                        Text("base r\(file.revision)")
                            .font(.system(size: 10))
                            .foregroundStyle(ForkTheme.textSecondary)
                            .fixedSize()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                hr

                if isLoadingDiff && diffLines.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading diff...")
                            .font(.system(size: 11))
                            .foregroundStyle(ForkTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isBinaryPreview {
                    binaryPreviewCard
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(diffRows) { row in
                                diffRow(row)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundStyle(ForkTheme.textSecondary)
                    Text("Select a file to view changes")
                        .font(.system(size: 12))
                        .foregroundStyle(ForkTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(ForkTheme.bg)
    }

    private var isBinaryPreview: Bool {
        !diffLines.isEmpty
            && diffLines.allSatisfy { $0.kind == .note || $0.kind == .hunk }
            && diffLines.contains { $0.text.localizedCaseInsensitiveContains("binary") }
    }

    private var binaryPreviewCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 32))
                .foregroundStyle(ForkTheme.textSecondary)
            Text("Binary file")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ForkTheme.textPrimary)
            Text("svn does not show content changes for binary files.\nOpen it in Finder, or use the file's history in the repository.")
                .font(.system(size: 11))
                .foregroundStyle(ForkTheme.textSecondary)
                .multilineTextAlignment(.center)
            if let file = focusedFile {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.absPath)])
                } label: {
                    Label("Open in Finder", systemImage: "folder")
                        .font(.system(size: 11))
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    @ViewBuilder
    private func diffRow(_ row: DiffDisplayLine) -> some View {
        let prefix: String = {
            switch row.kind {
            case .add: return "+ "
            case .remove: return "- "
            case .context: return "  "
            case .hunk: return ""
            case .note: return "* "
            }
        }()
        HStack(spacing: 0) {
            Rectangle()
                .fill(diffBarColor(row.kind))
                .frame(width: 3)
            Text(row.oldNumber.map(String.init) ?? "")
                .frame(width: 36, alignment: .trailing)
                .foregroundStyle(ForkTheme.textSecondary.opacity(0.6))
            Text(row.newNumber.map(String.init) ?? "")
                .frame(width: 40, alignment: .trailing)
                .foregroundStyle(ForkTheme.textSecondary.opacity(0.6))
                .padding(.trailing, 9)
            Text(prefix + row.text)
                .foregroundStyle(diffTextColor(row.kind))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 12)
                .textSelection(.enabled)
        }
        .font(.system(size: 11.5, design: .monospaced))
        .padding(.vertical, 1)
        .background(diffBG(row.kind))
    }

    private func diffBarColor(_ kind: DiffLine.Kind) -> Color {
        switch kind {
        case .add: return ForkTheme.addText
        case .remove: return ForkTheme.delText
        default: return .clear
        }
    }

    private func diffTextColor(_ kind: DiffLine.Kind) -> Color {
        switch kind {
        case .add: return ForkTheme.addText
        case .remove: return ForkTheme.delText
        case .context: return ForkTheme.textPrimary.opacity(0.85)
        case .hunk: return ForkTheme.hunkText
        case .note: return ForkTheme.textSecondary
        }
    }

    private func diffBG(_ kind: DiffLine.Kind) -> Color {
        switch kind {
        case .add: return ForkTheme.addBG
        case .remove: return ForkTheme.delBG
        case .hunk: return ForkTheme.panel.opacity(0.7)
        default: return .clear
        }
    }

    private var commitBar: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("Message")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ForkTheme.textSecondary)
                    if !recentMessages.isEmpty {
                        Menu {
                            ForEach(recentMessages, id: \.self) { message in
                                Button(message) { draftMessage = message }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Recent")
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(ForkTheme.textSecondary)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }

                TextEditor(text: $draftMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(ForkTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(height: 58)
                    .background(ForkTheme.bg, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    showCommit = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Commit \(checkedFiles.count) File\(checkedFiles.count == 1 ? "" : "s")")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(ForkTheme.accent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(checkedFiles.isEmpty)

                Text("\(checkedFiles.count) of \(files.filter { $0.status.isChanged }.count) selected")
                    .font(.system(size: 10))
                    .foregroundStyle(ForkTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ForkTheme.sidebar)
    }

    // MARK: - History

    private var filteredLog: [LogEntry] {
        guard !logSearch.isEmpty else { return logEntries }
        return logEntries.filter { entry in
            entry.message.localizedCaseInsensitiveContains(logSearch)
                || entry.author.localizedCaseInsensitiveContains(logSearch)
                || "r\(entry.revision)".localizedCaseInsensitiveContains(logSearch)
        }
    }

    private var selectedLogEntry: LogEntry? {
        guard let selectedRevision else { return nil }
        return logEntries.first { $0.revision == selectedRevision }
    }

    private var historyPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("History")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ForkTheme.textPrimary)
                Text("\(logEntries.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ForkTheme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(ForkTheme.accent.opacity(0.16), in: Capsule())
                Spacer(minLength: 4)
                if let scope = historyScope {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                        Text((scope as NSString).lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button {
                            historyScope = nil
                            selectedRevision = nil
                            reloadLog()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(ForkTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ForkTheme.panel, in: Capsule())
                    .overlay(Capsule().stroke(ForkTheme.border))
                    .help("Showing history for \"\(scope)\". Click the x to show the whole working copy.")
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox")
                        Text("Working copy")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(ForkTheme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(ForkTheme.textSecondary)
                TextField("Filter log", text: $logSearch)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(ForkTheme.textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ForkTheme.bg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            if let appError {
                errorBanner(appError)
            }

            hr

            ZStack {
                if isLoadingLog && logEntries.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading log...")
                            .font(.system(size: 11))
                            .foregroundStyle(ForkTheme.textSecondary)
                    }
                } else if filteredLog.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 26))
                            .foregroundStyle(ForkTheme.textSecondary)
                        Text(logEntries.isEmpty ? "No history found" : "No revisions match the filter")
                            .font(.system(size: 12))
                            .foregroundStyle(ForkTheme.textSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredLog) { entry in
                                revisionRow(entry)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            hr

            HStack(spacing: 8) {
                Button("Load 100 more...") {
                    logLimit += 100
                    reloadLog()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(ForkTheme.accent)
                .disabled(isLoadingLog)
                .opacity(isLoadingLog ? 0.5 : 1)
                Spacer(minLength: 4)
                if isLoadingLog {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("\(logEntries.count) revisions")
                    .font(.system(size: 10))
                    .foregroundStyle(ForkTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .background(ForkTheme.panel)
    }

    private func revisionRow(_ entry: LogEntry) -> some View {
        let selected = entry.revision == selectedRevision
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("r\(entry.revision)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(ForkTheme.accent)
                Text(entry.author)
                    .font(.system(size: 10))
                    .foregroundStyle(ForkTheme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(entry.dateText)
                    .font(.system(size: 10))
                    .foregroundStyle(ForkTheme.textSecondary)
            }
            Text(entry.shortMessage)
                .font(.system(size: 11))
                .foregroundStyle(ForkTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("\(entry.paths.count) path\(entry.paths.count == 1 ? "" : "s") changed")
                .font(.system(size: 9))
                .foregroundStyle(ForkTheme.textSecondary.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(selected ? ForkTheme.rowSelected.opacity(0.45) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectRevision(entry) }
        .contextMenu {
            Button("Copy Revision Number") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("r\(entry.revision)", forType: .string)
            }
            if !entry.message.isEmpty {
                Button("Copy Message") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.message, forType: .string)
                }
            }
        }
    }

    private var revisionDetailPanel: some View {
        VStack(spacing: 0) {
            if let entry = selectedLogEntry {
                HStack(spacing: 8) {
                    Text("r\(entry.revision)")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.22), in: Capsule())
                        .foregroundStyle(.green)
                    Text(entry.author)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ForkTheme.textPrimary)
                    Text(entry.dateText)
                        .font(.system(size: 11))
                        .foregroundStyle(ForkTheme.textSecondary)
                    Spacer(minLength: 8)
                    Text("\(entry.paths.count) changed path\(entry.paths.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(ForkTheme.textSecondary)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.message, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(ForkTheme.textPrimary)
                            .frame(width: 24, height: 20)
                            .background(ForkTheme.panel, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(ForkTheme.border))
                    }
                    .buttonStyle(.plain)
                    .help("Copy commit message")
                    .disabled(entry.message.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                hr

                Text(entry.message.isEmpty ? "(no commit message)" : entry.message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(entry.message.isEmpty ? ForkTheme.textSecondary : ForkTheme.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ForkTheme.panel, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                HStack {
                    Text("CHANGED PATHS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ForkTheme.textSecondary)
                    Spacer(minLength: 4)
                    if !entry.paths.isEmpty {
                        Text("click a path to view its diff")
                            .font(.system(size: 9))
                            .foregroundStyle(ForkTheme.textSecondary.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

                if entry.paths.isEmpty {
                    Text("No changed paths reported")
                        .font(.system(size: 11))
                        .foregroundStyle(ForkTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(entry.paths) { path in
                                logPathRow(path)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 140)
                }

                hr

                if let path = revisionSelectedPath {
                    HStack(spacing: 8) {
                        Text((path.displayPath as NSString).lastPathComponent)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ForkTheme.textPrimary)
                            .lineLimit(1)
                        Text("@ r\(entry.revision)")
                            .font(.system(size: 10))
                            .foregroundStyle(ForkTheme.textSecondary)
                            .fixedSize()
                        Spacer(minLength: 8)
                        if isLoadingRevisionDiff {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("diff -c r\(entry.revision)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(ForkTheme.textSecondary.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    hr

                    if isLoadingRevisionDiff && revisionDiffRows.isEmpty {
                        VStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading diff...")
                                .font(.system(size: 11))
                                .foregroundStyle(ForkTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(revisionDiffRows) { row in
                                    diffRow(row)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                } else {
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 30))
                        .foregroundStyle(ForkTheme.textSecondary)
                    Text("Select a revision to view details")
                        .font(.system(size: 12))
                        .foregroundStyle(ForkTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(ForkTheme.bg)
    }

    private func logPathRow(_ path: LogPath) -> some View {
        let selected = path.id == revisionSelectedPath?.id
        return HStack(spacing: 9) {
            Text(path.action)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(path.color)
                .frame(width: 15)
            Image(systemName: path.kind == "dir" ? "folder" : "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(ForkTheme.textSecondary)
            Text(path.displayPath)
                .font(.system(size: 11))
                .foregroundStyle(ForkTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(selected ? ForkTheme.rowSelected.opacity(0.45) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectRevisionPath(path) }
    }

    private func resetHistory() {
        logTask?.cancel()
        revisionDiffTask?.cancel()
        logEntries = []
        selectedRevision = nil
        historyScope = nil
        revisionSelectedPath = nil
        revisionDiffRows = []
        logLimit = 100
        logSearch = ""
        isLoadingLog = false
        isLoadingRevisionDiff = false
    }

    private func reloadLog() {
        logTask?.cancel()
        guard let wc = activeWC else {
            logEntries = []
            return
        }
        let scope = historyScope
        let limit = logLimit
        isLoadingLog = true
        logTask = Task {
            do {
                let entries = try await SVN.log(in: wc.path, limit: limit, relativePath: scope)
                guard !Task.isCancelled else { return }
                logEntries = entries.map { LogEntry(entry: $0, repoPrefix: wc.repositoryPrefix) }
                isLoadingLog = false
                if let selected = selectedRevision, let entry = logEntries.first(where: { $0.revision == selected }) {
                    selectRevision(entry)
                } else if let first = logEntries.first {
                    selectRevision(first)
                } else {
                    selectedRevision = nil
                    revisionSelectedPath = nil
                    revisionDiffRows = []
                }
            } catch {
                guard !Task.isCancelled else { return }
                isLoadingLog = false
                showError(error.localizedDescription)
            }
        }
    }

    private func selectRevision(_ entry: LogEntry) {
        selectedRevision = entry.revision
        if let first = entry.paths.first {
            selectRevisionPath(first)
        } else {
            revisionDiffTask?.cancel()
            revisionSelectedPath = nil
            revisionDiffRows = []
            isLoadingRevisionDiff = false
        }
    }

    private func selectRevisionPath(_ path: LogPath) {
        revisionSelectedPath = path
        revisionDiffTask?.cancel()
        guard let wc = activeWC, let revision = selectedRevision else { return }
        isLoadingRevisionDiff = true
        revisionDiffRows = []
        let relative = path.displayPath.hasSuffix("/") ? String(path.displayPath.dropLast()) : path.displayPath
        revisionDiffTask = Task {
            do {
                let text: String
                do {
                    text = try await SVN.diffRevision(relativePath: relative, revision: revision, in: wc.path)
                } catch {
                    guard !wc.url.isEmpty else { throw error }
                    let encoded = relative.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relative
                    text = try await SVN.diffRevision(url: wc.url + "/" + encoded, revision: revision)
                }
                guard !Task.isCancelled else { return }
                let lines = SVN.parseDiff(text)
                revisionDiffRows = DiffNumbering.build(lines.isEmpty
                    ? [DiffLine(kind: .note, text: "No differences in this path for this revision.")]
                    : lines)
                isLoadingRevisionDiff = false
            } catch {
                guard !Task.isCancelled else { return }
                revisionDiffRows = DiffNumbering.build([DiffLine(kind: .note, text: error.localizedDescription)])
                isLoadingRevisionDiff = false
            }
        }
    }

    private func showHistory(for relativePath: String?) {
        activeTab = .history
        if let relativePath {
            historyScope = relativePath
            selectedRevision = nil
            revisionSelectedPath = nil
            revisionDiffRows = []
            logLimit = 100
        }
        reloadLog()
    }

    // MARK: - Loading

    private func loadRecentMessages() {
        recentMessages = UserDefaults.standard.stringArray(forKey: Self.recentMessagesKey) ?? []
    }

    private func recordMessage(_ message: String) {
        var list = recentMessages.filter { $0 != message }
        list.insert(message, at: 0)
        recentMessages = Array(list.prefix(5))
        UserDefaults.standard.set(recentMessages, forKey: Self.recentMessagesKey)
    }

    private func loadWorkingCopies() async {
        let paths = UserDefaults.standard.stringArray(forKey: Self.wcPathsKey) ?? []
        var result: [WorkingCopy] = []
        for path in paths {
            if let info = try? await SVN.info(at: path) {
                result.append(WorkingCopy(info: info))
            }
        }
        workingCopies = result
        persistPaths()
        if selectedWCID == nil || !result.contains(where: { $0.path == selectedWCID }) {
            selectedWCID = result.first?.path
        }
    }

    private func persistPaths() {
        UserDefaults.standard.set(workingCopies.map(\.path), forKey: Self.wcPathsKey)
    }

    private func refreshStatus() async {
        prefetchTask?.cancel()
        guard let wc = activeWC else {
            files = []
            setDisplayDiff([])
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let previousChecked = Dictionary(files.map { ($0.id, $0.isChecked) }, uniquingKeysWith: { first, _ in first })
        do {
            let entries = try await SVN.status(in: wc.path)
            var items: [FileItem] = []
            for entry in entries {
                guard var item = FileItem(entry: entry, wcPath: wc.path) else { continue }
                if let wasChecked = previousChecked[item.id] {
                    item.isChecked = wasChecked
                }
                items.append(item)
            }
            files = items
        } catch {
            files = []
            showError(error.localizedDescription)
        }
        loadDiff()
    }

    private func refreshInfo(for wcPath: String? = nil) async {
        let target = wcPath.flatMap { path in workingCopies.first { $0.path == path } } ?? activeWC
        guard let wc = target, let info = try? await SVN.info(at: wc.path) else { return }
        if let idx = workingCopies.firstIndex(where: { $0.path == wc.path }) {
            workingCopies[idx].revision = info.revision
            workingCopies[idx].url = info.url
            workingCopies[idx].branch = info.branch
            workingCopies[idx].name = info.name
        }
    }

    private func loadDiff() {
        diffTask?.cancel()
        guard let wc = activeWC, let file = focusedFile else {
            setDisplayDiff([])
            isLoadingDiff = false
            return
        }
        let key = diffKey(for: file)
        if let cached = diffCache[key] {
            setDisplayDiff(cached)
            isLoadingDiff = false
            prefetchAround(file)
            return
        }
        isLoadingDiff = true
        setDisplayDiff([])
        diffTask = Task {
            let lines = await loadDiffLines(for: file, wc: wc)
            guard !Task.isCancelled else { return }
            storeDiff(lines, for: key)
            if focusedFile?.id == file.id {
                setDisplayDiff(lines)
                isLoadingDiff = false
                prefetchAround(file)
            }
        }
    }

    private func setDisplayDiff(_ lines: [DiffLine]) {
        diffLines = lines
        diffRows = DiffNumbering.build(lines)
    }

    private func loadDiffLines(for file: FileItem, wc: WorkingCopy) async -> [DiffLine] {
        var lines: [DiffLine]
        if file.status == .unversioned {
            lines = await SVN.unversionedDiff(atAbsolutePath: file.absPath)
        } else if file.status == .missing {
            lines = await SVN.missingFileDiff(relativePath: file.relativePath, in: wc.path)
        } else {
            do {
                let text = try await SVN.diffText(relativePath: file.relativePath, in: wc.path)
                lines = SVN.parseDiff(text)
            } catch {
                lines = [DiffLine(kind: .note, text: "Could not load diff: \(error.localizedDescription)")]
            }
        }
        if lines.isEmpty {
            if file.status == .modified {
                lines = [DiffLine(kind: .note, text: "No content differences - the change may be in file properties or line endings.")]
            } else {
                lines = [DiffLine(kind: .note, text: "No differences.")]
            }
        }
        return lines
    }

    private func diffKey(for file: FileItem) -> String {
        "\(file.id)|\(file.mtimeKey)|\(file.status.rawValue)"
    }

    private func storeDiff(_ lines: [DiffLine], for key: String) {
        diffCache[key] = lines
        if diffCache.count > 120 {
            diffCache.removeAll()
        }
    }

    private func prefetchAround(_ file: FileItem) {
        guard let wc = activeWC,
              let index = scopedFiles.firstIndex(where: { $0.id == file.id }) else { return }
        let upcoming = Array(scopedFiles.dropFirst(index + 1).prefix(2))
        guard !upcoming.isEmpty else { return }
        prefetchTask?.cancel()
        prefetchTask = Task(priority: .utility) {
            for next in upcoming {
                if Task.isCancelled { return }
                let key = diffKey(for: next)
                guard diffCache[key] == nil else { continue }
                let lines = await loadDiffLines(for: next, wc: wc)
                if Task.isCancelled { return }
                storeDiff(lines, for: key)
            }
        }
    }

    // MARK: - Working copy management

    private func addExistingWorkingCopy() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Choose an existing working copy folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            do {
                let info = try await SVN.info(at: url.path)
                if let existing = workingCopies.first(where: { $0.path == info.path }) {
                    selectedWCID = existing.path
                    return
                }
                let wc = WorkingCopy(info: info)
                workingCopies.append(wc)
                persistPaths()
                selectedWCID = wc.path
                showToast("Added \(wc.name)")
            } catch {
                showError("Not a working copy: \(error.localizedDescription)")
            }
        }
    }

    private func removeWorkingCopy(_ wc: WorkingCopy) {
        workingCopies.removeAll { $0.path == wc.path }
        persistPaths()
        if selectedWCID == wc.path {
            selectedWCID = workingCopies.first?.path
        }
        if activeWC == nil {
            files = []
            setDisplayDiff([])
        }
    }

    // MARK: - Operations

    private func runUpdate(for wc: WorkingCopy? = nil, relativePaths: [String] = [], label: String? = nil) {
        guard let wc = wc ?? activeWC else { return }
        let target = label ?? wc.name
        operation.begin("Update - \(target)")
        let task = SVNTask()
        operation.attach(task)
        Task {
            do {
                let result = try await SVN.update(relativePaths: relativePaths, wcPath: wc.path, task: task) { line in
                    Task { @MainActor in operation.append(line) }
                }
                operation.finish()
                await refreshInfo(for: wc.path)
                await refreshStatus()
                if result.succeeded {
                    if let revision = updatedRevision(from: result.stdout) {
                        showToast("Updated \(target) to r\(revision)")
                    } else {
                        showToast("Updated \(target)")
                    }
                } else {
                    showError(result.errorText)
                }
            } catch {
                operation.finish()
                if !task.isCancelled { showError(error.localizedDescription) }
            }
        }
    }

    private func updatedRevision(from stdout: String) -> String? {
        guard let range = stdout.range(of: #"Updated to revision (\d+)"#, options: .regularExpression) else {
            return nil
        }
        return String(stdout[range]).split(separator: " ").last.map(String.init)
    }

    private func chooseFolderAndUpdate(for wc: WorkingCopy? = nil) {
        guard let wc = wc ?? activeWC else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: wc.path)
        panel.prompt = "Update"
        panel.message = "Choose a folder inside \"\(wc.name)\" to update"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let wcPath = wc.path.hasSuffix("/") ? wc.path : wc.path + "/"
        guard url.path == wc.path || url.path.hasPrefix(wcPath) else {
            showError("Choose a folder inside \"\(wc.name)\".")
            return
        }
        if url.path == wc.path {
            runUpdate(for: wc)
            return
        }
        let relative = String(url.path.dropFirst(wcPath.count))
        runUpdate(for: wc, relativePaths: [relative], label: relative)
    }

    private func performCheckout(url: String, destination: String, revision: String?, depth: String) {
        let name = (destination as NSString).lastPathComponent
        operation.begin("Checkout - \(name)")
        let task = SVNTask()
        operation.attach(task)
        Task {
            do {
                let result = try await SVN.checkout(url: url, destination: destination, revision: revision, depth: depth, task: task) { line in
                    Task { @MainActor in operation.append(line) }
                }
                operation.finish()
                if result.succeeded {
                    if let info = try? await SVN.info(at: destination) {
                        let wc = WorkingCopy(info: info)
                        if !workingCopies.contains(where: { $0.path == wc.path }) {
                            workingCopies.append(wc)
                        }
                        persistPaths()
                        selectedWCID = wc.path
                        showToast("Checked out \(wc.name) at r\(wc.revision)")
                    } else {
                        showToast("Checkout finished")
                    }
                } else {
                    showError(result.errorText)
                }
            } catch {
                operation.finish()
                if !task.isCancelled { showError(error.localizedDescription) }
            }
        }
    }

    private func performCommit(items: [FileItem], message: String, keepLocks: Bool) {
        guard let wc = activeWC else { return }
        let unversioned = items.filter { $0.status == .unversioned }
        let missing = items.filter { $0.status == .missing }
        let rest = items.filter { $0.status != .unversioned && $0.status != .missing }
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        operation.begin("Commit - \(wc.name)")
        let task = SVNTask()
        operation.attach(task)
        Task {
            do {
                if !unversioned.isEmpty {
                    operation.append("Adding \(unversioned.count) new file(s)...")
                    _ = try await SVN.add(paths: unversioned.map(\.relativePath), wcPath: wc.path)
                }
                if !missing.isEmpty {
                    operation.append("Scheduling \(missing.count) missing file(s) for deletion...")
                    _ = try await SVN.scheduleDelete(paths: missing.map(\.relativePath), wcPath: wc.path)
                }
                let paths = (unversioned + missing).map(\.relativePath) + rest.map(\.relativePath)
                let result = try await SVN.commit(paths: paths, message: trimmedMessage, keepLocks: keepLocks, wcPath: wc.path, task: task) { line in
                    Task { @MainActor in operation.append(line) }
                }
                operation.finish()
                if result.succeeded {
                    draftMessage = trimmedMessage
                    recordMessage(trimmedMessage)
                    await refreshInfo()
                    await refreshStatus()
                    if let revision = committedRevision(from: result.stdout) {
                        showToast("Committed r\(revision)")
                    } else {
                        showToast("Committed \(items.count) file(s)")
                    }
                } else {
                    showError(result.errorText)
                    await refreshStatus()
                }
            } catch {
                operation.finish()
                if !task.isCancelled { showError(error.localizedDescription) }
                await refreshStatus()
            }
        }
    }

    private func performRevert() {
        guard let wc = activeWC else { return }
        let checked = checkedFiles
        guard !checked.isEmpty else { return }
        let versioned = checked.filter { $0.status != .unversioned }
        let unversioned = checked.filter { $0.status == .unversioned }

        operation.begin("Revert \(checked.count) file(s)")
        let task = SVNTask()
        operation.attach(task)
        let trashDirectory = backupBeforeRevert ? backupDirectory() : nil

        Task {
            if let trashDirectory {
                var backedUp = 0
                for item in checked where FileManager.default.fileExists(atPath: item.absPath) {
                    let target = (trashDirectory as NSString).appendingPathComponent(item.relativePath)
                    let targetDir = (target as NSString).deletingLastPathComponent
                    try? FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
                    if (try? FileManager.default.copyItem(atPath: item.absPath, toPath: target)) != nil {
                        backedUp += 1
                    }
                }
                operation.append("Backed up \(backedUp) file(s) to ~/.MacSVN/trash")
            }
            for item in unversioned {
                try? FileManager.default.removeItem(atPath: item.absPath)
                operation.append("Removed unversioned '\(item.relativePath)'")
            }
            do {
                if !versioned.isEmpty {
                    let result = try await SVN.revert(paths: versioned.map(\.relativePath), wcPath: wc.path)
                    operation.appendLines(result.stdout)
                }
                operation.finish()
                await refreshInfo()
                await refreshStatus()
                showToast(trashDirectory != nil
                          ? "Reverted \(checked.count) file(s) - backup saved to ~/.MacSVN/trash"
                          : "Reverted \(checked.count) file(s)")
            } catch {
                operation.finish()
                if !task.isCancelled { showError(error.localizedDescription) }
                await refreshStatus()
            }
        }
    }

    private func backupDirectory() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return NSHomeDirectory() + "/.MacSVN/trash/" + formatter.string(from: Date())
    }

    private func committedRevision(from stdout: String) -> String? {
        guard let range = stdout.range(of: #"Committed revision (\d+)"#, options: .regularExpression) else {
            return nil
        }
        return String(stdout[range]).split(separator: " ").last.map(String.init)
    }

    private func ignore(_ item: FileItem, mode: IgnoreMode) {
        guard let wc = activeWC else { return }
        Task {
            do {
                let folderAbsolute = (wc.path as NSString).appendingPathComponent(item.folder)
                switch mode {
                case .file:
                    try await SVN.addIgnore(pattern: item.displayName, toDirectory: folderAbsolute)
                    showToast("Ignoring \"\(item.displayName)\"")
                case .extension:
                    try await SVN.addIgnore(pattern: "*.\(item.ext)", toDirectory: folderAbsolute)
                    showToast("Ignoring \"*.\(item.ext)\"")
                case .folder:
                    let parentRelative = (item.folder as NSString).deletingLastPathComponent
                    let parentAbsolute = parentRelative.isEmpty
                        ? wc.path
                        : (wc.path as NSString).appendingPathComponent(parentRelative)
                    let folderName = (item.folder as NSString).lastPathComponent
                    try await SVN.addIgnore(pattern: folderName, toDirectory: parentAbsolute)
                    showToast("Ignoring folder \"\(item.folder)\"")
                }
                await refreshStatus()
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    // MARK: - UI helpers

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { toast = nil }
        }
    }

    private func showError(_ message: String) {
        withAnimation { appError = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            if appError == message {
                withAnimation { appError = nil }
            }
        }
    }

    private func moveFocus(_ delta: Int) {
        guard !isFolderListView, !scopedFiles.isEmpty else { return }
        let current = scopedFiles.firstIndex { $0.id == focusedFile?.id } ?? -1
        let next = max(0, min(scopedFiles.count - 1, current + delta))
        selectedFileID = scopedFiles[next].id
    }

    private func toggleFocused() {
        guard let item = focusedFile,
              let idx = files.firstIndex(where: { $0.id == item.id }) else { return }
        files[idx].isChecked.toggle()
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 26))
                .foregroundStyle(ForkTheme.textSecondary)
            Text(files.contains { $0.status.isChanged }
                 ? "No files match the current filter"
                 : "Working copy is clean - no changes")
                .font(.system(size: 12))
                .foregroundStyle(ForkTheme.textSecondary)
            if !search.isEmpty || filter != .all {
                Button("Clear filter") {
                    search = ""
                    filter = .all
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(ForkTheme.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(ForkTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation { appError = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ForkTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.red.opacity(0.14))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.red.opacity(0.35)).frame(height: 1)
        }
    }

    private var revertAlertMessage: String {
        if backupBeforeRevert {
            return "Local changes will be discarded. A backup copy of each file will be saved to ~/.MacSVN/trash so you can restore manually if needed."
        }
        return "All local modifications will be permanently lost (discard changes). This cannot be undone."
    }
}

enum IgnoreMode {
    case file
    case `extension`
    case folder
}

struct StatusBadge: View {
    let status: FileStatus

    var body: some View {
        Text(status.badge)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 18, height: 16)
            .background(status.color.gradient, in: RoundedRectangle(cornerRadius: 4))
            .help(status.label)
    }
}

struct WelcomeView: View {
    var onAdd: () -> Void
    var onCheckout: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44))
                .foregroundStyle(ForkTheme.textSecondary)
            Text("No working copies yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ForkTheme.textPrimary)
            Text("Add an existing working copy on this Mac, or check out a new one from a repository URL.")
                .font(.system(size: 12))
                .foregroundStyle(ForkTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            HStack(spacing: 10) {
                Button {
                    onAdd()
                } label: {
                    Label("Add Existing...", systemImage: "folder.badge.plus")
                }
                Button {
                    onCheckout()
                } label: {
                    Label("Checkout...", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .tint(ForkTheme.accent)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ForkTheme.bg)
    }
}

struct CommitSheet: View {
    let wc: WorkingCopy
    @Binding var files: [FileItem]
    let recentMessages: [String]
    let onCommit: ([FileItem], String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var keepLocks = false

    private var commitable: [FileItem] {
        files.filter { $0.status.isChanged }
    }

    private var checkedItems: [FileItem] {
        files.filter { $0.isChecked && $0.status.isChanged }
    }

    private func binding(for item: FileItem) -> Binding<Bool> {
        Binding(
            get: { files.first { $0.id == item.id }?.isChecked ?? false },
            set: { value in
                if let idx = files.firstIndex(where: { $0.id == item.id }) {
                    files[idx].isChecked = value
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(ForkTheme.accent)
                Text("Commit to \(wc.name)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ForkTheme.textPrimary)
                Spacer()
                Text("r\(wc.revision)")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.22), in: Capsule())
                    .foregroundStyle(.green)
            }

            Text(wc.url)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ForkTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(commitable) { item in
                        HStack(spacing: 9) {
                            Toggle("", isOn: binding(for: item))
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            Text(item.status.badge)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(item.status.color)
                                .frame(width: 15)
                            Text(item.displayName)
                                .font(.system(size: 12))
                                .foregroundStyle(ForkTheme.textPrimary)
                                .frame(width: 190, alignment: .leading)
                                .lineLimit(1)
                            Text(item.folder)
                                .font(.system(size: 11))
                                .foregroundStyle(ForkTheme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            if item.status == .unversioned {
                                Text("will be added")
                                    .font(.system(size: 10))
                                    .foregroundStyle(ForkTheme.textSecondary)
                            } else if item.status == .missing {
                                Text("will be deleted")
                                    .font(.system(size: 10))
                                    .foregroundStyle(ForkTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(height: 200)
            .background(ForkTheme.bg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))

            HStack(spacing: 10) {
                Text("Message")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ForkTheme.textSecondary)
                if !recentMessages.isEmpty {
                    Menu {
                        ForEach(recentMessages, id: \.self) { recent in
                            Button(recent) { message = recent }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Recent")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(ForkTheme.textSecondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            TextEditor(text: $message)
                .font(.system(size: 12))
                .foregroundStyle(ForkTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(height: 80)
                .background(ForkTheme.bg, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))

            HStack {
                Toggle("Keep locks", isOn: $keepLocks)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundStyle(ForkTheme.textSecondary)
                Spacer()
                Text("\(checkedItems.count) file(s)")
                    .font(.system(size: 11))
                    .foregroundStyle(ForkTheme.textSecondary)
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    onCommit(checkedItems, message, keepLocks)
                    dismiss()
                } label: {
                    Label("Commit", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(ForkTheme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || checkedItems.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 640)
        .background(ForkTheme.sidebar)
    }
}

struct CheckoutSheet: View {
    var onCheckout: (String, String, String?, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var parentDirectory = NSHomeDirectory()
    @State private var revision = "HEAD"
    @State private var depth = "infinity"
    @State private var name = ""
    @State private var userEditedName = false

    private var destination: String {
        (parentDirectory as NSString).appendingPathComponent(name)
    }

    private var canCheckout: Bool {
        !url.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && FileManager.default.fileExists(atPath: parentDirectory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down.fill")
                    .foregroundStyle(ForkTheme.accent)
                Text("Checkout")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ForkTheme.textPrimary)
            }

            Text("URL of repository")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ForkTheme.textSecondary)
            TextField("http://... or svn://...", text: $url)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .onChange(of: url) { _, newValue in
                    if !userEditedName { deriveName(from: newValue) }
                }

            Text("Checkout directory")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ForkTheme.textSecondary)
            HStack {
                TextField("Parent folder", text: $parentDirectory)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                Button("Choose...") { chooseDirectory() }
            }

            Text("Folder name")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ForkTheme.textSecondary)
            TextField("Folder name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onChange(of: name) { _, _ in userEditedName = true }

            Text(destination)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(ForkTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Revision")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ForkTheme.textSecondary)
                    TextField("HEAD", text: $revision)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .frame(width: 110)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Checkout depth")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ForkTheme.textSecondary)
                    Picker("", selection: $depth) {
                        Text("Fully recursive").tag("infinity")
                        Text("Immediate children").tag("immediates")
                        Text("Files only").tag("files")
                        Text("Only this item").tag("empty")
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                Spacer()
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Checkout") {
                    onCheckout(
                        url.trimmingCharacters(in: .whitespaces),
                        destination,
                        revision.trimmingCharacters(in: .whitespaces),
                        depth
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(ForkTheme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCheckout)
            }
        }
        .padding(18)
        .frame(width: 620)
        .background(ForkTheme.sidebar)
    }

    private func deriveName(from value: String) {
        var cleaned = value.trimmingCharacters(in: .whitespaces)
        while cleaned.hasSuffix("/") { cleaned.removeLast() }
        if let last = cleaned.split(separator: "/").last {
            name = String(last)
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose parent folder for the new working copy"
        if panel.runModal() == .OK, let url = panel.url {
            parentDirectory = url.path
        }
    }
}

struct OperationProgressSheet: View {
    @ObservedObject var operation: OperationController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(ForkTheme.accent)
                Text(operation.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ForkTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if operation.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(operation.lines.enumerated()), id: \.offset) { index, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(color(for: line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: operation.lines.count) { _, count in
                    guard count > 0 else { return }
                    withAnimation {
                        proxy.scrollTo(count - 1, anchor: .bottom)
                    }
                }
            }
            .frame(height: 220)
            .padding(8)
            .background(ForkTheme.bg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))

            HStack {
                if operation.isRunning {
                    Button("Cancel") { operation.cancel() }
                }
                Spacer()
                Button("Close") { operation.isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .disabled(operation.isRunning)
            }
        }
        .padding(18)
        .frame(width: 640)
        .background(ForkTheme.sidebar)
    }

    private func color(for line: String) -> Color {
        if line.hasPrefix("U ") || line.hasPrefix("A ") || line.hasPrefix("G ") {
            return ForkTheme.addText
        }
        if line.hasPrefix("D ") {
            return ForkTheme.delText
        }
        if line.hasPrefix("C ") {
            return .yellow
        }
        return ForkTheme.textSecondary
    }
}
