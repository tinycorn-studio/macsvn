# MacSVN

macOS native SVN client với giao diện kiểu Fork — thay thế nhẹ nhàng cho SmartSVN / Cornerstone khi làm việc với Subversion.

- UI: SwiftUI, dark/light theme, hỗ trợ tiếng Anh cho interface.
- Backend: gọi trực tiếp `svn` CLI (không dùng thư viện C), parse XML/`svn diff` output.
- Đóng gói: `MacSVN.app` + DMG, không cần cài đặt phụ (chỉ cần svn CLI có sẵn trên máy).

---

## Tải về & cài đặt

Tải bản mới nhất tại trang **[Releases](https://github.com/tinycorn-studio/macsvn/releases)** (mỗi version có file `MacSVN-x.y.z.dmg` + ghi chú thay đổi).

1. Mở file `.dmg`, kéo **MacSVN** vào `Applications`.
2. Lần đầu mở: chuột phải vào app → **Open** (app chưa ký, bỏ qua Gatekeeper).
3. Cần svn CLI trên máy (xem mục Yêu cầu).

## Yêu cầu

| Thành phần | Ghi chú |
|---|---|
| macOS 14+ | Apple Silicon hoặc Intel |
| Subversion CLI | Khuyến nghị `brew install subversion` (Homebrew: `/opt/homebrew/bin/svn`). App tự dò theo thứ tự: `/opt/homebrew/bin/svn` → `/usr/local/bin/svn` → `/usr/bin/svn` |
| Swift 5.9+ (chỉ khi build) | Xcode hoặc Command Line Tools |

> App chưa được ký (unsigned). Lần đầu mở: chuột phải vào `MacSVN.app` → **Open** để bỏ qua Gatekeeper.

## Build & đóng gói

```bash
swift build                # build debug
swift run SVNDemo          # chạy trực tiếp từ source
./make-app.sh              # build release → dist/MacSVN.app + dist/MacSVN-0.4.0.dmg
```

Sửa số version trong `make-app.sh` (biến `VERSION`) trước khi phát hành.

### Phát hành phiên bản mới (release flow)

```bash
# 1. Bump VERSION trong make-app.sh, cập nhật CHANGELOG.md
# 2. Build app + DMG
./make-app.sh

# 3. Commit, tag, push
git add -A && git commit -m "vX.Y.Z: <tom tat>"
git tag -a vX.Y.Z -m "MacSVN vX.Y.Z"
git push origin main --tags

# 4. Tạo GitHub Release kèm file cài (DMG không commit vào repo, đính vào release)
gh release create vX.Y.Z dist/MacSVN-X.Y.Z.dmg \
  --title "MacSVN vX.Y.Z" --notes-file RELEASE_NOTES.md
```

Sau bước này, trang **Releases** sẽ hiển thị ghi chú thay đổi + file cài cho từng version (giống Firebase, Docker...).

## CLI test harness

`svncli` dùng để kiểm tra nhanh phần lõi SVNCore mà không cần mở app (đều là read-only, trừ `ignore`):

```bash
swift run svncli which                        # in ra đường dẫn svn đang dùng
swift run svncli info <path>                  # thông tin working copy
swift run svncli status <wc-path>             # danh sách file thay đổi
swift run svncli diff <wc-path> <file>        # diff 1 file (theo WC root)
swift run svncli log <wc-path> [limit]        # log gần đây kèm changed paths
swift run svncli rdiff <wc-path> <rev> <path> # diff của 1 path trong 1 revision
swift run svncli ignore <dir> <pattern>       # thêm pattern vào svn:ignore
```

---

## Tính năng

### 1. Quản lý working copies
- Thêm WC có sẵn (Add Existing Working Copy...) hoặc **Checkout** mới (URL + revision + depth, có streaming log).
- Danh sách WC lưu trong UserDefaults, hiển thị branch + revision hiện tại.
- Chuột phải WC: Update Working Copy / Update Folder... / Reveal in Finder / Remove from List.

### 2. Tab Changes — danh sách thay đổi
- Trạng thái đầy đủ: **M** modified (gồm cả prop-only như `svn:keywords`), **A** added, **?** unversioned, **!** missing, **C** conflicted.
- Filter theo loại thay đổi, search theo tên file/folder.
- Checkbox từng file; "Check all" / "Uncheck all" theo phạm vi đang xem; summary `xM xA x? x! xC`.
- **View theo folder (1 cấp)**: toggle Files / Folders ở header —
  - chế độ Folders liệt kê folder cấp 1 có thay đổi kèm số lượng + mini-summary;
  - click folder → xem toàn bộ file bên trong, breadcrumb **‹ Folders** quay lại;
  - tick ở dòng folder = chọn/bỏ chọn cả folder; chuột phải folder: Open / Update Folder / Show History / Check all / Commit / Revert / Open in Finder.
- Phím tắt: **↑/↓** di chuyển, **Space** tick/bỏ tick.

### 3. Diff preview
- Diff màu rõ ràng: thanh màu lề + số dòng cũ/mới + nền xanh/đỏ; hunk header tím.
- File binary: hiện card "Binary file" + nút Open in Finder (svn không hiển thị nội dung binary).
- File unversioned: đọc trực tiếp nội dung (giới hạn 3MB, chạy off-main).
- File missing: hiện diff xoá so với `svn cat -r BASE`.
- Cache diff theo `path|mtime|status`, prefetch trước 2 file kế để chuyển nhanh.

### 4. Update
- Nút **Update** (split button): update toàn bộ WC, hoặc menu **Update Folder...** chọn folder bên trong WC.
- Update từng file/folder qua chuột phải ở danh sách Changes (submenu Update).
- Streaming log + nút Cancel; toast `Updated to revision N` khi xong.

### 5. Commit
- Chọn file (checkbox) → **Commit** mở sheet: danh sách file, message, recent messages (5 gần nhất).
- Tự động `svn add` file unversioned và `svn delete` file missing trước khi commit.
- Streaming log; báo revision đã commit.

### 6. Revert
- Revert file đã chọn; tuỳ chọn **backup** vào `~/.MacSVN/trash/<yyyyMMdd-HHmmss>/` (bật/tắt trong menu ⚙).
- File unversioned bị xoá khỏi đĩa (kèm backup nếu bật).

### 7. Ignore
- Chuột phải file unversioned → Ignore: theo file, theo `*.ext`, hoặc theo folder; ghi vào `svn:ignore` của thư mục cha.

### 8. Tab History — xem log (`svn log -v`)
- Danh sách revision: r#, author, ngày (dd/MM HH:mm), message, số path thay đổi.
- Badge xanh **current** đánh dấu revision mà working copy đang ở; chi tiết có badge **working copy base**.
- Filter log (message/author/revision), **Load 100 more...** để tải thêm.
- Phím **↑/↓** duyệt revision, list tự cuộn theo; copy revision/message qua chuột phải.
- Panel chi tiết: message đầy đủ (select/copy), **Changed paths** (A/M/D/R, icon folder cho dir) — click 1 path để xem `diff -c rN` của path đó.
- Chuột phải file/folder ở tab Changes → **Show History**: lọc log theo path đó, chip phạm vi có nút ✕ để quay về toàn WC.

### 9. Phím tắt
| Phím | Tác dụng |
|---|---|
| ⌘R | Refresh (tab Changes: status; tab History: reload log) |
| ⌘↩ | Mở commit (khi có file được chọn) |
| ↑ / ↓ | Di chuyển selection (đổi cả file lẫn revision) |
| Space | Tick/bỏ tick file đang chọn |
| ⌘Q | Thoát |

---

## Kiến trúc

```
Package.swift
├── Sources/SVNCore/        # Thư viện lõi — wrapper svn CLI
│   └── SVNCore.swift
├── Sources/SVNDemo/        # Ứng dụng SwiftUI
│   ├── App.swift           # @main, window setup
│   ├── Models.swift        # FileStatus, FileItem, WorkingCopy, LogEntry, DiffNumbering...
│   ├── Operations.swift    # OperationController: streaming log, progress, cancel
│   └── Views.swift         # Toàn bộ UI: ContentView, Commit/Checkout sheets...
├── Sources/svncli/         # CLI test harness
└── tools/                  # Script tiện ích
    ├── generate_icon.swift         # sinh AppIcon
    ├── preview_update_button.swift # render preview nút Update (trước khi apply design)
    ├── preview_folder_view.swift   # render preview folder view
    └── preview_log_tab.swift       # render preview tab History
```

**SVNCore API chính** (`public enum SVN`):
- Process: `run`, `runStreaming` (đọc output theo dòng, `SVNTask` cancel được, set `LANG/LC_ALL=en_US.UTF-8`).
- Đọc: `info`, `status` (XML), `log` (XML + `-v`), `diffText`, `diffRevision` (theo WC path hoặc repo URL), `parseDiff`, `missingFileDiff`, `unversionedDiff`.
- Ghi: `add`, `scheduleDelete`, `revert`, `update(relativePaths:)`, `commit`, `checkout`, `addIgnore`.

**Quy ước code**: mọi mutation đều `throw` khi svn trả exit code ≠ 0; parse XML bằng `XMLDocument`; lỗi auth (E170001/E215004) nhận diện trong `SVNResult.isAuthError`.

## Cấu hình (UserDefaults — bundle `com.macsvn.app`)

| Key | Ý nghĩa |
|---|---|
| `wcPaths` | Danh sách đường dẫn working copies đã thêm |
| `recentMessages` | 5 commit message gần nhất |
| `backupBeforeRevert` | Bật/tắt backup khi revert (mặc định: bật) |
| `changesViewMode` | `files` hoặc `folders` — chế độ xem tab Changes |

Ví dụ:

```bash
defaults write com.macsvn.app wcPaths -array "/path/to/wc1" "/path/to/wc2"
defaults write com.macsvn.app changesViewMode -string folders
```

## Giới hạn đã biết

- Conflict: chỉ hiển thị trạng thái **C** / **!**; chưa có UI resolve conflict (dùng `svn resolve` qua terminal).
- Auth: dùng credential cache của `svn` CLI (chưa có UI nhập user/password; chạy 1 lệnh svn trong terminal trước nếu cần).
- Log chưa lazy-load vô hạn; tải theo lô 100 revision bằng "Load 100 more...".
- Chưa hỗ trợ blame/annotate, merge, branch/tag operations, repository browser.
- App chưa ký (unsigned) — phải mở bằng chuột phải → Open lần đầu.

## Lịch sử phiên bản

- **0.4.0** (18/10/2026): tích hợp SVN thật qua SVNCore; diff preview có cache/prefetch; folder view; Update từng folder/file; tab History (log -v + diff theo revision). [Chi tiết](CHANGELOG.md)
- **0.3.0**: UX quick wins — empty/loading states, error banner, keyboard navigation, light/dark theme, revert backup vào trash.
- **0.2.0**: demo UI + responsive layout.
- **0.1.0**: khung ứng dụng ban đầu.
