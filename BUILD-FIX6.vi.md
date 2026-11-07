# Fix6: bỏ UIScreen.mainScreen deprecated trên SDK 27.1

Log mới chạy commit `8729d5860233f836a6b2cfcb112e1a6e7e3875f2`. Fix5 đã qua: log không còn lỗi trait callback. Preflight và chín nhóm test thành phần qua, core ARM64 build được. Build tweak dừng ở `Redesigned/Library/LibraryRows.x:55` vì `UIScreen.mainScreen` deprecated bị nâng thành lỗi bởi `-Werror`.

Tìm trong toàn bộ target cho thấy ba file còn gọi mainScreen. Fix6 thay nguyên ba file đó:

- `Integration/Chroma/tweak/Sources/Redesigned/Library/LibraryRows.x`: độ dày separator lấy từ `cell.traitCollection.displayScale`, chặn scale chưa xác định để không chia cho 0.
- `Integration/Chroma/tweak/Sources/Shared/AudioEffects/SGDSPCurveView.m`: độ dày grid lấy từ trait của view, cập nhật khi layout và khi display scale đổi hoặc gắn sang window. Không thay DSP, preset, gain hoặc điều khiển đồ thị.
- `Integration/Chroma/tweak/Sources/Redesigned/Player/PlayerMorph.x`: lấy screen qua windowScene của container transition; giữ cách đọc corner-radius có try/catch và fallback 55 của nguồn gốc. Lưu radius trong mỗi transition để không đọc KVC mỗi frame. Không thay thời lượng, easing hoặc nội dung morph.

Không đổi chế độ Native/Redesigned, không tắt `-Werror`, không sửa source upstream hay payload gốc. API dựa trên tài liệu Apple:

- [mainScreen và cách lấy screen từ context](https://developer.apple.com/documentation/uikit/uiscreen/main?language=objc)
- [displayScale của UITraitCollection](https://developer.apple.com/documentation/uikit/uitraitcollection/displayscale?language=objc)
- [Đăng ký trait thay đổi với selector](https://developer.apple.com/documentation/uikit/uitraitchangeobservable-7qoet/registerfortraitchanges%3Awithaction%3A)

## Áp dụng

1. Giải nén `chroma-v5-build-fix6.zip`, thay nguyên **cả ba file** đúng đường dẫn vào repo `spotify_mod`.
2. Giữ fix5 đã commit; không cần áp dụng lại các bản sửa cũ.
3. Commit lên `main`, chạy **Chroma source integration - v5-9188 → Run workflow → main**. Run mới phải có SHA khác `8729d58`; không chỉ Re-run run cũ.

Preflight, kiểm tra phân lớp, tiền xử lý Logos của hai file hook đã sửa và CRC/hash ZIP được kiểm tra tại máy này. Chưa có Apple compilation sau fix6, chưa có full dylib/extension/`.deb` hoặc runtime iPhone được xác nhận. Khả năng hiển thị trên màn hình có scale khác và chuyển player vẫn cần kiểm tra thiết bị; không dùng kết quả test Foundation để suy ra UI đã đúng.
