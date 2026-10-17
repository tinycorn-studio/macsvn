import SwiftUI
import AppKit

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
    static let addBG = dyn(c(0.129, 0.286, 0.176), c(0.851, 0.957, 0.874))
    static let addText = dyn(c(0.588, 0.878, 0.639), c(0.086, 0.435, 0.196))
    static let delBG = dyn(c(0.337, 0.149, 0.161), c(0.988, 0.878, 0.886))
    static let delText = dyn(c(0.941, 0.588, 0.596), c(0.717, 0.145, 0.180))
    static let hunkText = dyn(c(0.573, 0.478, 0.965), c(0.416, 0.278, 0.851))
    static let border = dyn(c(0.24, 0.24, 0.24), c(0.796, 0.796, 0.827))
    static let buttonTint = dyn(c(0.30, 0.30, 0.32), c(0.855, 0.855, 0.878))
}

struct ContentView: View {
    @State private var workingCopies = Mock.workingCopies
    @State private var selectedWCID: UUID?
    @State private var files = Mock.files
    @State private var filter: StatusFilter = .all
    @State private var search = ""
    @State private var selectedFileID: UUID?

    @State private var showCommit = false
    @State private var showCheckout = false
    @State private var showRevertConfirm = false
    @State private var showUpdate = false
    @State private var toast: String?
    @State private var draftMessage = ""
    @State private var isRefreshing = false
    @State private var appError: String?
    @AppStorage("backupBeforeRevert") private var backupBeforeRevert = true

    private var activeWC: WorkingCopy {
        workingCopies.first { $0.id == selectedWCID } ?? workingCopies[0]
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

    private var focusedFile: FileItem? {
        files.first { $0.id == selectedFileID } ?? visibleFiles.first
    }

    private func count(of status: FileStatus) -> Int {
        files.filter { $0.status == status }.count
    }

    private func checkBinding(for item: FileItem) -> Binding<Bool> {
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
        VStack(spacing: 0) {
            topBar
            hr
            HSplitView {
                sidebarPanel
                    .frame(minWidth: 160, idealWidth: 210, maxWidth: 320)
                changesPanel
                    .frame(minWidth: 240, idealWidth: 320, maxWidth: 460)
                diffPanel
                    .frame(minWidth: 280, maxWidth: .infinity)
            }
            hr
            commitBar
        }
        .background(ForkTheme.bg)
        .sheet(isPresented: $showCommit) {
            CommitSheet(wc: activeWC, files: $files, draftMessage: $draftMessage) { count in
                showToast("Committed \(count) file(s) at r\(activeWC.revision + 1)")
                bumpRevision()
                let conflicts = files.filter { $0.status == .conflicted }.count
                if conflicts > 0 {
                    showError("svn: E155015: commit partially succeeded - \(conflicts) conflicted file(s) were skipped. Resolve conflicts before the next commit.")
                }
            }
        }
        .sheet(isPresented: $showCheckout) {
            CheckoutSheet { wc in
                workingCopies.append(wc)
                selectedWCID = wc.id
                showToast("Checked out \(wc.name) at r\(wc.revision)")
            }
        }
        .sheet(isPresented: $showUpdate) {
            UpdateProgressSheet(wc: activeWC) {
                bumpRevision()
                showToast("Updated \(activeWC.name) to r\(activeWC.revision + 1)")
            }
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
        .onAppear {
            if selectedWCID == nil { selectedWCID = workingCopies.first?.id }
        }
        .onChange(of: selectedWCID) { refreshStatus() }
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
            Text(activeWC.name)
                .font(.system(size: 12))
                .foregroundStyle(ForkTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Text(activeWC.branch)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(ForkTheme.panel, in: Capsule())
                    .foregroundStyle(ForkTheme.textPrimary)
                Text("r\(activeWC.revision)")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.22), in: Capsule())
                    .foregroundStyle(.green)
            }

            Spacer(minLength: 8)

            toolbarIcon("square.and.arrow.down", "Checkout...") { showCheckout = true }
            toolbarIcon("arrow.uturn.backward", "Revert - discard changes...") { showRevertConfirm = true }
                .disabled(checkedFiles.isEmpty)
            toolbarIcon("arrow.clockwise", "Refresh status") { refreshStatus() }
                .keyboardShortcut("r", modifiers: .command)

            Button {
                showUpdate = true
            } label: {
                Label("Update", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(ForkTheme.buttonTint)
            .foregroundStyle(ForkTheme.textPrimary)

            Menu {
                Toggle("Backup files before Revert", isOn: $backupBeforeRevert)
                Divider()
                Button("Preview error banner") {
                    showError("svn: E170001: Authentication failed for 'http://svn.example.com/repos/example/ExampleApp' - check username/password and try again.")
                }
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
            .help("Settings & demo options")
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

            Button {
                showCheckout = true
            } label: {
                Label("Add working copy...", systemImage: "plus.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(ForkTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(ForkTheme.sidebar)
    }

    private func wcRow(_ wc: WorkingCopy) -> some View {
        let selected = wc.id == activeWC.id
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
        .onTapGesture { selectedWCID = wc.id }
    }

    private var changesPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Changes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ForkTheme.textPrimary)
                Text("\(visibleFiles.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ForkTheme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(ForkTheme.accent.opacity(0.16), in: Capsule())
                Spacer()
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

            hr

            ZStack {
                if visibleFiles.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(visibleFiles) { item in
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
                    for i in files.indices where files[i].status.isChanged {
                        files[i].isChecked = true
                    }
                }
                .fixedSize()
                Button("Uncheck all") {
                    for i in files.indices {
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
        let m = count(of: .modified)
        let a = count(of: .added)
        let u = count(of: .unversioned)
        let x = count(of: .missing)
        let c = count(of: .conflicted)
        return "\(m)M \(a)A \(u)? \(x)! \(c)C"
    }

    private func changeRow(_ item: FileItem) -> some View {
        let selected = item.id == (focusedFile?.id ?? UUID())
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
                Text(item.folder)
                    .font(.system(size: 10))
                    .foregroundStyle(ForkTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.head)
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
        Button("Update") { showUpdate = true }
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
        Divider()
        Button("Open in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([
                URL(fileURLWithPath: activeWC.path).appendingPathComponent(item.folder)
            ])
        }
        Button("Diff...") {}
            .disabled(item.status != .modified)
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

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(file.mockDiff) { line in
                            diffRow(line)
                        }
                    }
                    .padding(.vertical, 6)
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

    @ViewBuilder
    private func diffRow(_ line: DiffLine) -> some View {
        let prefix: String = {
            switch line.kind {
            case .add: return "+ "
            case .remove: return "- "
            case .context: return "  "
            case .hunk: return ""
            case .note: return "* "
            }
        }()
        Text(prefix + line.text)
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(diffTextColor(line.kind))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 1)
            .background(diffBG(line.kind))
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
                    Menu {
                        Button("Update app layout and assets") { draftMessage = "Update app layout and assets" }
                        Button("Fix config parsing bug") { draftMessage = "Fix config parsing bug" }
                        Button("Add new icons and docs") { draftMessage = "Add new icons and docs" }
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

    private func bumpRevision() {
        guard let idx = workingCopies.firstIndex(where: { $0.id == activeWC.id }) else { return }
        workingCopies[idx].revision += 1
    }

    private func performRevert() {
        let checked = checkedFiles
        for item in checked {
            guard let idx = files.firstIndex(where: { $0.id == item.id }) else { continue }
            if item.status == .unversioned {
                files.remove(at: idx)
            } else {
                files[idx].status = .normal
                files[idx].isChecked = false
            }
        }
        showToast(backupBeforeRevert
                  ? "Reverted \(checked.count) file(s) - backup saved to ~/.MacSVN/trash"
                  : "Reverted \(checked.count) file(s)")
    }

    private func ignore(_ item: FileItem, mode: IgnoreMode) {
        switch mode {
        case .file:
            files.removeAll { $0.id == item.id }
            showToast("Added \"\(item.displayName)\" to ignore list")
        case .extension:
            files.removeAll { $0.ext == item.ext && $0.status == .unversioned }
            showToast("Added \"*.\(item.ext)\" to ignore list")
        case .folder:
            files.removeAll { $0.folder.hasPrefix(item.folder) && $0.status == .unversioned }
            showToast("Added \"\(item.folder)\" to ignore list")
        }
    }

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

    private func refreshStatus() {
        guard !isRefreshing else { return }
        withAnimation { isRefreshing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation { isRefreshing = false }
            showToast("Status refreshed")
        }
    }

    private func moveFocus(_ delta: Int) {
        guard !visibleFiles.isEmpty else { return }
        let current = visibleFiles.firstIndex { $0.id == focusedFile?.id } ?? -1
        let next = max(0, min(visibleFiles.count - 1, current + delta))
        selectedFileID = visibleFiles[next].id
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

struct CommitSheet: View {
    let wc: WorkingCopy
    @Binding var files: [FileItem]
    @Binding var draftMessage: String
    var onCommit: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var keepLocks = false

    private var commitable: [FileItem] {
        files.filter { $0.status.isChanged }
    }

    private var checkedCount: Int {
        files.filter { $0.isChecked && $0.status.isChanged }.count
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
                Text("Commit to \(activeName)")
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
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(height: 200)
            .background(ForkTheme.bg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))

            Text("Message")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ForkTheme.textSecondary)

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
                Text("\(checkedCount) file(s)")
                    .font(.system(size: 11))
                    .foregroundStyle(ForkTheme.textSecondary)
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    performCommit()
                } label: {
                    Label("Commit", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(ForkTheme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || checkedCount == 0)
            }
        }
        .padding(18)
        .frame(width: 640)
        .background(ForkTheme.sidebar)
        .onAppear { message = draftMessage }
    }

    private var activeName: String {
        wc.name
    }

    private func performCommit() {
        for idx in files.indices where files[idx].isChecked && files[idx].status.isChanged {
            files[idx].status = .normal
            files[idx].isChecked = false
        }
        draftMessage = message
        onCommit(checkedCount)
        dismiss()
    }
}

struct CheckoutSheet: View {
    var onCheckout: (WorkingCopy) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var url = "http://svn.example.com/repos/demo/DemoProject"
    @State private var destination = NSHomeDirectory() + "/Projects/"
    @State private var revision = "HEAD"
    @State private var depth = "Fully recursive"
    @State private var name = "DemoProject"

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
            TextField("http://...", text: $url)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

            Text("Checkout directory")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ForkTheme.textSecondary)
            HStack {
                TextField("Directory", text: $destination)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                Button("Choose...") {}
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Revision")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ForkTheme.textSecondary)
                    Picker("", selection: $revision) {
                        Text("HEAD revision").tag("HEAD")
                        Text("Revision 1523").tag("1523")
                        Text("Revision 1520").tag("1520")
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Checkout depth")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ForkTheme.textSecondary)
                    Picker("", selection: $depth) {
                        Text("Fully recursive").tag("Fully recursive")
                        Text("Immediate children").tag("Immediate children")
                        Text("Only this item").tag("Only this item")
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                Spacer()
            }

            Toggle("Omit externals", isOn: .constant(false))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundStyle(ForkTheme.textSecondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Checkout") {
                    onCheckout(WorkingCopy(
                        name: name,
                        path: destination + name,
                        url: url,
                        branch: "trunk",
                        revision: 1523
                    ))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(ForkTheme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(url.isEmpty || destination.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 620)
        .background(ForkTheme.sidebar)
    }
}

struct UpdateProgressSheet: View {
    let wc: WorkingCopy
    var onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var lines: [String] = []
    @State private var progress: Double = 0

    private let steps: [(String, Double)] = [
        ("Updating '\(Mock.workingCopies.first?.url ?? "")':", 0.1),
        ("Updating 'Resources':", 0.25),
        ("U  Resources/icon.png", 0.4),
        ("U  src/Utils/StringExt.swift", 0.6),
        ("Updating 'src':", 0.75),
        ("G  src/Core/Engine.swift", 0.9),
        ("Updated to revision \(1524).", 1.0),
        ("Done.", 1.0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(ForkTheme.accent)
                Text("Update - \(wc.name)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ForkTheme.textPrimary)
                Spacer()
            }
            ProgressView(value: progress)
                .tint(ForkTheme.accent)
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(line.hasPrefix("U ") || line.hasPrefix("G ") ? ForkTheme.addText : ForkTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 150)
            .padding(8)
            .background(ForkTheme.bg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ForkTheme.border))

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .disabled(progress < 1.0)
            }
        }
        .padding(18)
        .frame(width: 560)
        .background(ForkTheme.sidebar)
        .task {
            for step in steps {
                try? await Task.sleep(nanoseconds: 300_000_000)
                lines.append(step.0)
                progress = step.1
            }
            onFinish()
        }
    }
}
