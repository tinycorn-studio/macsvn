import SwiftUI
import AppKit

// Self-contained preview renderer for Update button design variants.
// Usage: swift tools/preview_update_button.swift out.png

let accent = Color(red: 0.357, green: 0.565, blue: 1.0)
let textPrimary = Color(red: 0.93, green: 0.93, blue: 0.93)
let textSecondary = Color(red: 0.58, green: 0.58, blue: 0.58)
let panel = Color(red: 0.145, green: 0.149, blue: 0.165)
let sidebar = Color(red: 0.106, green: 0.110, blue: 0.122)
let appBG = Color(red: 0.121, green: 0.125, blue: 0.137)
let borderColor = Color(red: 0.24, green: 0.24, blue: 0.24)
let buttonTint = Color(red: 0.30, green: 0.30, blue: 0.32)

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

struct UpdateLabel: View {
    var text: String = "Update"
    var body: some View {
        Label(text, systemImage: "arrow.triangle.2.circlepath")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
    }
}

struct TopBarRow<Control: View>: View {
    @ViewBuilder var control: () -> Control

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

            control()

            IconButton(symbol: "gearshape")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(sidebar)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(borderColor))
    }
}

// A - current split button
struct VariantA: View {
    var body: some View {
        HStack(spacing: 0) {
            UpdateLabel()
            Rectangle().fill(borderColor).frame(width: 1, height: 14)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(textPrimary)
                .padding(.horizontal, 7)
                .padding(.vertical, 7)
        }
        .background(buttonTint, in: RoundedRectangle(cornerRadius: 6))
    }
}

// B - single menu button
struct VariantB: View {
    var body: some View {
        HStack(spacing: 5) {
            UpdateLabel()
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(textPrimary)
                .padding(.trailing, 9)
        }
        .background(buttonTint, in: RoundedRectangle(cornerRadius: 6))
    }
}

// C - two separate buttons
struct VariantC: View {
    var body: some View {
        HStack(spacing: 8) {
            UpdateLabel(text: "Update All")
                .background(buttonTint, in: RoundedRectangle(cornerRadius: 6))
            Label("Update Folder...", systemImage: "folder")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(panel, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor))
        }
    }
}

// D - plain update button
struct VariantD: View {
    var body: some View {
        UpdateLabel()
            .background(buttonTint, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct VariantHeader: View {
    let letter: String
    let description: String

    var body: some View {
        HStack(spacing: 8) {
            Text(letter)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(textSecondary)
        }
    }
}

struct PreviewBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MacSVN — Preview: phương án nút Update (chế độ tối)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                VariantHeader(letter: "A", description: "Nút đôi (đang áp dụng): 'Update' = toàn bộ, mũi tên ▾ = menu (toàn bộ / chọn folder)")
                TopBarRow { VariantA() }
            }
            VStack(alignment: .leading, spacing: 8) {
                VariantHeader(letter: "B", description: "Một nút duy nhất: 'Update ▾' — bấm vào mở menu 2 lựa chọn (toàn bộ / chọn folder)")
                TopBarRow { VariantB() }
            }
            VStack(alignment: .leading, spacing: 8) {
                VariantHeader(letter: "C", description: "Hai nút tách rời: 'Update All' và 'Update Folder...' luôn hiện rõ")
                TopBarRow { VariantC() }
            }
            VStack(alignment: .leading, spacing: 8) {
                VariantHeader(letter: "D", description: "Tối giản: chỉ 'Update' (toàn bộ); update từng phần qua chuột phải file / working copy")
                TopBarRow { VariantD() }
            }
        }
        .padding(20)
        .frame(width: 1240)
        .background(appBG)
    }
}

// Render
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "update_button_preview.png"

let hosting = NSHostingView(rootView: PreviewBoard())
hosting.frame = NSRect(x: 0, y: 0, width: 1240, height: hosting.fittingSize.height)
hosting.layoutSubtreeIfNeeded()

let height = hosting.fittingSize.height
hosting.frame = NSRect(x: 0, y: 0, width: 1240, height: height)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(1240 * 2),
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
rep.size = NSSize(width: 1240, height: height)
hosting.cacheDisplay(in: hosting.bounds, to: rep)

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("error: could not encode PNG\n", stderr)
    exit(1)
}
try! data.write(to: URL(fileURLWithPath: outputPath))
print("written: \(outputPath) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
