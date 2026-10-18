# Changelog

Mọi thay đổi đáng chú ý của MacSVN được ghi tại đây.
Định dạng theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/), version theo [Semantic Versioning](https://semver.org/lang/vi/).

## [0.4.0] - 2026-10-18

### Added
- **Tích hợp SVN thật** qua thư viện `SVNCore` (thay toàn bộ dữ liệu demo cũ): working copies thật, status/diff/update/commit/revert/ignore/checkout đều chạy qua `svn` CLI.
- Quản lý nhiều working copies: thêm WC có sẵn, checkout mới (URL + revision + depth) với log streaming.
- Diff preview đầy đủ: tô màu +/- với thanh màu lề và số dòng cũ/mới, hunk header, cache diff theo `path|mtime|status`, prefetch 2 file kế tiếp.
- Xử lý file đặc biệt: card riêng cho **file binary**, preview nội dung cho **file unversioned** (giới hạn 3MB, chạy off-main), diff xoá cho **file missing** (`svn cat -r BASE`).
- **View theo folder (1 cấp)**: toggle Files/Folders, danh sách folder kèm số lượng thay đổi, drill-down xem file trong folder với breadcrumb, tick chọn cả folder, chuột phải folder có Update/Commit/Revert/Show History.
- **Update từng phần**: nút Update split-button (toàn bộ WC / chọn folder), update file hoặc folder qua chuột phải, streaming log + Cancel, toast "Updated to revision N".
- **Tab History** (`svn log -v`): danh sách revision (author, ngày, message, số path), filter, tải thêm theo lô 100, duyệt bằng phím ↑/↓ tự cuộn, badge **current** đánh dấu revision của working copy.
- Chi tiết revision: message đầy đủ, danh sách changed paths (M/A/D/R) — click path xem diff `-c rN` của riêng path đó; chuột phải file/folder ở tab Changes → **Show History** để lọc log theo path.
- Revert có **backup vào `~/.MacSVN/trash`** (bật/tắt trong Settings).
- Ignore qua `svn:ignore`: theo file, theo `*.ext`, hoặc theo folder.
- Commit từ app: tự `svn add` file unversioned và `svn delete` file missing trước khi commit; recent messages (5 gần nhất).
- `svncli` CLI test harness: `which / info / status / diff / log / rdiff / ignore`.
- `tools/`: script sinh icon + các renderer preview UI (nút Update, folder view, tab History) để duyệt thiết kế trước khi code.
- README: tài liệu đầy đủ về tính năng, kiến trúc, cấu hình, release flow.

### Changed
- UI chuyển từ dữ liệu mock sang dữ liệu thật (xóa `MockData.swift`).
- Theme Fork-style tinh chỉnh màu diff đậm rõ hơn (nền xanh/đỏ + thanh màu + số dòng).

### Fixed
- File chỉ đổi thuộc tính (`props="modified"`, item normal) giờ hiển thị đúng là Modified — trước đây bị ẩn khỏi danh sách.
- Preview file unversioned chạy ngoài main thread + giới hạn kích thước, không còn treo UI với file lớn.
- Diff giữ highlight đúng khi chuyển file nhanh (cache theo mtime, hủy task cũ).

## [0.3.0] - 2026-10-17

### Added
- Empty/loading states, banner báo lỗi svn trực quan.
- Điều hướng bàn phím trong danh sách file (↑/↓, Space tick, ⌘↩ commit).
- Hỗ trợ light/dark theme.
- Revert kèm backup file vào `~/.MacSVN/trash`.

## [0.2.0] - 2026-10-16

### Added
- Demo UI kiểu Fork: sidebar repositories, danh sách changes, diff panel, commit bar.
- Layout responsive với HSplitView.

## [0.1.0] - 2026-10-15

### Added
- Khung ứng dụng ban đầu (window, theme, cấu trúc project SwiftPM).
