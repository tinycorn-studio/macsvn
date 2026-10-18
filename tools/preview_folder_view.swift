import SwiftUI
import AppKit

// Self-contained preview renderer for the "view by folder" design in the Changes panel.
// Usage: swift tools/preview_folder_view.swift out.png

let accent = Color(red: 0.357, green: 0.565, blue: 1.0)
let textPrimary = Color(red: 0.93, green: 0.93, blue: 0.93)
let textSecondary = Color(red: 0.58, green: 0.58, blue: 0.58)
let panel = Color(red: 0.145, green: 0.149, blue: 0.165)
let sidebar = Color(red: 0.106, green: 0.110, blue: 0.122)
let appBG = Color(red: 0.121, green: 0.125, blue: 0.137)
let borderColor = Color(red: 0.24, green: 0.24, blue: 0.24)
let rowSelected = Color(red: 0.223, green: 0.333, blue: 0.588)

let mColor = Color.orange
let aColor = Color.green
let qColor = Color.blue
let xColor = Color.red
let cColor = Color.yellow

struct HR: View {
    var body: some View { Rectangle().fill(borderColor).frame(height: 1) }
}

enum CheckState { case on, off, mixed }

struct RowCheck: View {
    let state: CheckState
    var body: some View {
        Image(systemName: state == .on ? "checkmark.circle.fill" : state == .off ? "circle" : "minus.circle")
            .font(.system(size: 14))
            .foregroundStyle(state == .on ? accent : textSecondary)
    }
}

struct ViewToggle: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "list.bullet")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textSecondary)
                .frame(width: 24, height: 20)
            Text("Folders")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(accent, in: RoundedRectangle(cornerRadius: 5))
        }
        .padding(2)
        .background(appBG, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(borderColor))
    }
}

struct PanelHeader: View {
    let count: Int
    let subtitle: String?

    var body: some View {
        HStack(spacing: 8) {
            Text("Changes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textPrimary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(accent.opacity(0.16), in: Capsule())
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }
            Spacer()
            ViewToggle()
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text("All")
            }
            .font(.system(size: 11))
            .foregroundStyle(textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct SearchField: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(textSecondary)
            Text("Filter files")
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
    }
}

struct FolderRow: View {
    let name: String
    let count: Int
    let check: CheckState
    let summary: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 9) {
            RowCheck(state: check)
            Image(systemName: "folder.fill")
                .font(.system(size: 13))
                .foregroundStyle(accent)
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(textPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(summary)
                .font(.system(size: 10))
                .foregroundStyle(textSecondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(accent.opacity(0.16), in: Capsule())
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(selected ? rowSelected.opacity(0.45) : Color.clear)
    }
}

struct FileRow: View {
    let badge: String
    let color: Color
    let name: String
    let subpath: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 9) {
            RowCheck(state: .on)
            Text(badge)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 15)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                Text(subpath)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(selected ? rowSelected.opacity(0.45) : Color.clear)
    }
}

struct Breadcrumb: View {
    let folder: String

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 9, weight: .semibold))
                Text("Folders")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(accent)
            Text("/")
                .font(.system(size: 11))
                .foregroundStyle(textSecondary)
            Image(systemName: "folder.fill")
                .font(.system(size: 10))
                .foregroundStyle(accent)
            Text(folder)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textPrimary)
            Spacer()
            Text("468 of 486 checked")
                .font(.system(size: 10))
                .foregroundStyle(textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(panel)
    }
}

struct Footer: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Check all")
            Text("Uncheck all")
            Spacer()
            Text("468M 12A 8? 9! 0C")
                .font(.system(size: 10))
                .foregroundStyle(textSecondary)
        }
        .font(.system(size: 11))
        .foregroundStyle(accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

struct FolderListPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(count: 513, subtitle: "398 files in 4 folders")
            SearchField()
            HR()
            ScrollView {
                VStack(spacing: 0) {
                    FolderRow(name: "Assets", count: 486, check: .on, summary: "461M 12A 8? 5!", selected: true)
                    FolderRow(name: "Packages", count: 9, check: .on, summary: "6M 3?", selected: false)
                    FolderRow(name: "ProjectSettings", count: 12, check: .mixed, summary: "10M 2!", selected: false)
                    FolderRow(name: "Tools", count: 4, check: .off, summary: "4M", selected: false)
                    FolderRow(name: "Root files", count: 2, check: .on, summary: "1M 1?", selected: false)
                }
                .padding(.vertical, 4)
            }
            HR()
            Footer()
        }
        .frame(width: 430)
        .background(panel)
    }
}

struct FolderContentsPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(count: 486, subtitle: nil)
            SearchField()
            HR()
            Breadcrumb(folder: "Assets")
            HR()
            ScrollView {
                VStack(spacing: 0) {
                    FileRow(badge: "M", color: mColor, name: "UIRevive.cs", subpath: "Scripts", selected: true)
                    FileRow(badge: "M", color: mColor, name: "FishSpawner.cs", subpath: "Scripts", selected: false)
                    FileRow(badge: "M", color: mColor, name: "UIPopup.cs", subpath: "Scripts/UI", selected: false)
                    FileRow(badge: "M", color: mColor, name: "GameManager.cs", subpath: "Scripts", selected: false)
                    FileRow(badge: "M", color: mColor, name: "red_fish", subpath: "Sprites/Fish", selected: false)
                    FileRow(badge: "?", color: qColor, name: "new_icon", subpath: "Textures", selected: false)
                    FileRow(badge: "M", color: mColor, name: "MainMenu", subpath: "Prefabs/UI", selected: false)
                    FileRow(badge: "M", color: mColor, name: "Main", subpath: "Scenes", selected: false)
                    FileRow(badge: "A", color: aColor, name: "ComboEffect", subpath: "Prefabs/FX", selected: false)
                    FileRow(badge: "!", color: xColor, name: "old_bg", subpath: "Textures", selected: false)
                }
                .padding(.vertical, 4)
            }
            HR()
            Footer()
        }
        .frame(width: 430)
        .background(panel)
    }
}

struct StateCaption: View {
    let step: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(step)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PreviewBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("MacSVN — Preview: View theo folder (1 cấp) trong panel Changes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textPrimary)

            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    StateCaption(step: "1", text: "Bật toggle \"Folders\" ở header: liệt kê folder cấp 1 có file thay đổi, kèm số lượng.\nTick ở dòng folder = chọn/bỏ chọn toàn bộ file trong folder đó.")
                    FolderListPanel()
                }
                VStack(alignment: .leading, spacing: 10) {
                    StateCaption(step: "2", text: "Click folder \"Assets\": hiện toàn bộ file thay đổi bên trong (mọi cấp con), có breadcrumb \"‹ Folders\" để quay lại danh sách folder.")
                    FolderContentsPanel()
                }
            }
        }
        .padding(20)
        .frame(width: 990)
        .background(appBG)
    }
}

// Render
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "folder_view_preview.png"

let hosting = NSHostingView(rootView: PreviewBoard())
hosting.frame = NSRect(x: 0, y: 0, width: 990, height: hosting.fittingSize.height)
hosting.layoutSubtreeIfNeeded()

let height = hosting.fittingSize.height
hosting.frame = NSRect(x: 0, y: 0, width: 990, height: height)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(990 * 2),
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
rep.size = NSSize(width: 990, height: height)
hosting.cacheDisplay(in: hosting.bounds, to: rep)

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("error: could not encode PNG\n", stderr)
    exit(1)
}
try! data.write(to: URL(fileURLWithPath: outputPath))
print("written: \(outputPath) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
