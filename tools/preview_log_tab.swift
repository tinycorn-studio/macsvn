import SwiftUI
import AppKit

// Self-contained preview renderer for the History (svn log -v) tab design.
// Usage: swift tools/preview_log_tab.swift out.png

let accent = Color(red: 0.357, green: 0.565, blue: 1.0)
let textPrimary = Color(red: 0.93, green: 0.93, blue: 0.93)
let textSecondary = Color(red: 0.58, green: 0.58, blue: 0.58)
let panel = Color(red: 0.145, green: 0.149, blue: 0.165)
let sidebar = Color(red: 0.106, green: 0.110, blue: 0.122)
let appBG = Color(red: 0.121, green: 0.125, blue: 0.137)
let borderColor = Color(red: 0.24, green: 0.24, blue: 0.24)
let buttonTint = Color(red: 0.30, green: 0.30, blue: 0.32)
let rowSelected = Color(red: 0.223, green: 0.333, blue: 0.588)
let addText = Color(red: 0.596, green: 0.910, blue: 0.659)
let delText = Color(red: 0.969, green: 0.616, blue: 0.624)
let hunkText = Color(red: 0.573, green: 0.478, blue: 0.965)
let addBG = Color(red: 0.157, green: 0.408, blue: 0.239)
let delBG = Color(red: 0.463, green: 0.180, blue: 0.200)

let mColor = Color.orange
let aColor = Color.green
let dColor = Color.red

struct HR: View {
    var body: some View { Rectangle().fill(borderColor).frame(height: 1) }
}

struct IconButton: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(textPrimary)
            .frame(width: 28, height: 24)
            .background(panel, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor))
    }
}

struct TopBar: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(accent)
            Text("MacSVN")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textPrimary)
            Text("FishSortProject")
                .font(.system(size: 12))
                .foregroundStyle(textSecondary)

            HStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 10, weight: .medium))
                    Text("Changes")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(textSecondary)
                .padding(.horizontal, 6)
                .frame(height: 20)

                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10, weight: .medium))
                    Text("History")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(height: 20)
                .background(accent, in: RoundedRectangle(cornerRadius: 5))
            }
            .padding(2)
            .background(appBG, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(borderColor))

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Text("FishSort")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(panel, in: Capsule())
                    .foregroundStyle(textPrimary)
                Text("r305898")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.22), in: Capsule())
                    .foregroundStyle(.green)
            }

            Spacer(minLength: 8)

            IconButton(symbol: "square.and.arrow.down")
            IconButton(symbol: "arrow.uturn.backward")
            IconButton(symbol: "arrow.clockwise")

            HStack(spacing: 0) {
                Label("Update", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                Rectangle().fill(borderColor).frame(width: 1, height: 14)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 7)
            }
            .background(buttonTint, in: RoundedRectangle(cornerRadius: 6))

            IconButton(symbol: "gearshape")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(sidebar)
    }
}

struct WCSidebar: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REPOSITORIES")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(textSecondary)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)

            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("FishSortProject")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("FishSort - r305898")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    Spacer(minLength: 4)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(rowSelected, in: RoundedRectangle(cornerRadius: 6))

                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("svntest")
                            .font(.system(size: 12))
                            .foregroundStyle(textPrimary)
                        Text("trunk - r5")
                            .font(.system(size: 10))
                            .foregroundStyle(textSecondary)
                    }
                    Spacer(minLength: 4)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .padding(.horizontal, 6)

            Spacer()
        }
        .frame(width: 190)
        .background(sidebar)
    }
}

struct RevisionRow: View {
    let revision: String
    let author: String
    let date: String
    let message: String
    let paths: Int
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("r\(revision)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                Text(author)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
                Spacer(minLength: 4)
                Text(date)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("\(paths) path\(paths == 1 ? "" : "s") changed")
                .font(.system(size: 9))
                .foregroundStyle(textSecondary.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(selected ? rowSelected.opacity(0.45) : Color.clear)
    }
}

struct HistoryListPanel: View {
    let revisions: [(String, String, String, String, Int)]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("History")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text("100")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(accent.opacity(0.16), in: Capsule())
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "shippingbox")
                    Text("Working copy")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 10))
                .foregroundStyle(textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
                Text("Filter log")
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(appBG, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor))
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            HR()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(revisions.enumerated()), id: \.offset) { index, rev in
                        RevisionRow(revision: rev.0, author: rev.1, date: rev.2, message: rev.3, paths: rev.4, selected: index == 3)
                    }
                }
                .padding(.vertical, 4)
            }

            HR()

            HStack {
                Text("Load 100 more...")
                    .font(.system(size: 11))
                    .foregroundStyle(accent)
                Spacer()
                Text("100 revisions")
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .frame(width: 330)
        .background(panel)
    }
}

struct PathRow: View {
    let action: String
    let color: Color
    let path: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 9) {
            Text(action)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 15)
            Text(path)
                .font(.system(size: 11))
                .foregroundStyle(textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(selected ? rowSelected.opacity(0.45) : Color.clear)
    }
}

struct DiffLineRow: View {
    let kind: String
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(kind == "+" ? addText : kind == "-" ? delText : Color.clear)
                .frame(width: 3)
            Text(kind == "+" ? "+ " : kind == "-" ? "- " : kind == "@" ? "" : "  ")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(kind == "+" ? addText : kind == "-" ? delText : kind == "@" ? hunkText : textPrimary.opacity(0.85))
            Text(text)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(kind == "+" ? addText : kind == "-" ? delText : kind == "@" ? hunkText : textPrimary.opacity(0.85))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .background(kind == "+" ? addBG : kind == "-" ? delBG : kind == "@" ? panel.opacity(0.7) : Color.clear)
    }
}

struct RevisionDetailPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("r305895")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.22), in: Capsule())
                    .foregroundStyle(.green)
                Text("trang.le")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text("17/10/2026 12:40")
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
                Spacer(minLength: 8)
                Text("3 changed paths")
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
                IconButton(symbol: "doc.on.doc")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            HR()

            VStack(alignment: .leading, spacing: 0) {
                Text("Tweak combo effect balance: reduce particle count on low-end devices, fix fx scale on 4:3 screens. Also rename trigger column to \"comboPower\" for consistency.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(appBG, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack {
                Text("CHANGED PATHS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            VStack(spacing: 0) {
                PathRow(action: "M", color: mColor, path: "Assets/Prefabs/FX/ComboEffect.prefab", selected: false)
                PathRow(action: "M", color: mColor, path: "Assets/Scripts/GameManager.cs", selected: true)
                PathRow(action: "A", color: aColor, path: "Assets/Textures/FX/combo_glow.png", selected: false)
            }

            HR()

            HStack(spacing: 8) {
                Text("GameManager.cs")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text("@ r305895")
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text("diff -c r305895")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(textSecondary.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            HR()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DiffLineRow(kind: "@", text: "@@ -118,7 +118,6 @@ private void Awake()")
                    DiffLineRow(kind: " ", text: "    comboPower = 1.0f;")
                    DiffLineRow(kind: " ", text: "    comboDecay = 0.85f;")
                    DiffLineRow(kind: "-", text: "    comboPower *= 1.5f;  // amplify on combo")
                    DiffLineRow(kind: "+", text: "    comboPower *= 1.25f; // tuned for low-end devices")
                    DiffLineRow(kind: " ", text: "    ApplyComboVisual();")
                    DiffLineRow(kind: "@", text: "@@ -201,6 +200,10 @@ private void SpawnComboFx()")
                    DiffLineRow(kind: " ", text: "    var fx = Instantiate(comboFxPrefab);")
                    DiffLineRow(kind: "+", text: "    var budget = QualitySettings.GetQualityLevel() > 2 ? 48 : 24;")
                    DiffLineRow(kind: "+", text: "    fx.particleCount = budget;")
                    DiffLineRow(kind: "+", text: "    fx.transform.localScale = Screen.width > Screen.height")
                    DiffLineRow(kind: "+", text: "        ? Vector3.one : Vector3.one * 0.85f;")
                    DiffLineRow(kind: " ", text: "    fx.Play();")
                }
                .padding(.vertical, 6)
            }

            Spacer(minLength: 0)
        }
        .background(appBG)
    }
}

struct PreviewBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MacSVN — Preview: Tab History (svn log -v đầy đủ)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textPrimary)

            VStack(alignment: .leading, spacing: 5) {
                Text("• Tab \"Changes | History\" trên top bar — bấm History để chuyển sang xem log.")
                Text("• Panel giữa: danh sách revision (r, author, ngày, message tóm tắt, số path thay đổi); filter + Load more.")
                Text("• Panel phải: chi tiết revision — message đầy đủ, danh sách path thay đổi (M/A/D).")
                Text("• Click 1 path → xem diff của path đó trong revision; chuột phải file ở tab Changes → \"Show History\" để lọc log theo file (chip phạm vi, bấm ✕ quay về toàn WC).")
            }
            .font(.system(size: 11))
            .foregroundStyle(textSecondary)

            VStack(spacing: 0) {
                TopBar()
                HR()
                HStack(spacing: 0) {
                    WCSidebar()
                    HR().frame(width: 1, height: nil).frame(maxHeight: .infinity)
                        .overlay(Rectangle().fill(borderColor).frame(width: 1))
                    HistoryListPanel(revisions: [
                        ("305898", "lamhd", "17/10 16:22", "Fix fish spawn timing on level start", 4),
                        ("305897", "huy.dev", "17/10 15:05", "Update UI assets and prefabs", 12),
                        ("305896", "lamhd", "17/10 14:11", "Merge branch 'hotfix/vfx-scale'", 7),
                        ("305895", "trang.le", "17/10 12:40", "Tweak combo effect balance", 3),
                        ("305894", "huy.dev", "17/10 10:02", "Add new icon set for shop", 22),
                        ("305893", "lamhd", "16/10 18:47", "Refactor GameManager state machine", 5),
                        ("305892", "trang.le", "16/10 17:30", "Update localization strings", 9),
                        ("305891", "lamhd", "16/10 15:58", "Fix crash on revive popup", 2),
                        ("305890", "huy.dev", "16/10 11:15", "Daily sync from designer", 18),
                        ("305889", "lamhd", "16/10 09:40", "Disable debug overlay in release", 1),
                    ])
                    Rectangle().fill(borderColor).frame(width: 1)
                    RevisionDetailPanel()
                }
                .frame(height: 640)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor))
        }
        .padding(20)
        .frame(width: 1320)
        .background(Color(red: 0.09, green: 0.09, blue: 0.10))
    }
}

// Render
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "log_tab_preview.png"

let hosting = NSHostingView(rootView: PreviewBoard())
hosting.frame = NSRect(x: 0, y: 0, width: 1320, height: hosting.fittingSize.height)
hosting.layoutSubtreeIfNeeded()

let height = hosting.fittingSize.height
hosting.frame = NSRect(x: 0, y: 0, width: 1320, height: height)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(1320 * 2),
    pixelsHigh: Int(height * 2),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("error: could not create bitmap rep\n", stderr)
    exit(1)
}
rep.size = NSSize(width: 1320, height: height)
hosting.cacheDisplay(in: hosting.bounds, to: rep)

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("error: could not encode PNG\n", stderr)
    exit(1)
}
try! data.write(to: URL(fileURLWithPath: outputPath))
print("written: \(outputPath) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
