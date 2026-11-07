# Bản personal-menu-v3

## Có gì mới trong mã

- Nút Mod mở một menu UIKit thật: bật/tắt lọc feed, chặn popup đánh giá, làm sạch link và rung ở nút phát. Cấu hình được lưu trong UserDefaults.
- Menu hiển thị dylib đã nạp, phiên bản Spotify, lý do chặn kích hoạt nếu có, kết quả cài từng hook và các bộ đếm thực. Nhấn Refresh để đọc số liệu mới. Xuất báo cáo qua share sheet không kèm token/tài khoản.
- Thuật toán làm sạch link lấy từ Eevee v7.0.0: loại `si`/`utm_*`, giữ tham số nội dung và encoding, xử lý text, clipboard dữ liệu và Spotify URL nằm trong deep link. Hook hiện áp dụng vào pasteboard cụ thể và UIApplication.openURL. Đường khởi tạo share sheet riêng chưa được hook; không tuyên bố parity toàn bộ sharing.
- Chặn yêu cầu đánh giá qua hai selector SKStoreReviewController nếu chúng có mặt. Lưu trạng thái selector vắng mặt vào diagnostics; không giả định SwiftUI hoặc mọi hệ thống review tương lai dùng cùng đường này.
- Rung điều khiển dùng các accessibility identifier của player từ nguồn Eevee và chống rung lặp trong 80 ms. Chưa có scrub haptics hay music haptics.
- Feed hook có công tắc, đếm response được chọn, response đã thay đổi, lỗi và passthrough khi quá 8 MB. Bootstrap thử lại các class sau 1/3/8 giây; không bỏ qua việc xác nhận version.

Đây vẫn là một milestone của dự án cá nhân, chưa phải bản tích hợp 100%. Chưa có giao diện Liquid Glass của Chroma, lyrics providers/karaoke/lock screen, Premium/config patching, SponsorBlock, DSP và các phần khác còn trong nguồn tham chiếu. Không có mục menu giả cho các phần đó.

## Build và thử

1. Upload nội dung ZIP `personal-menu-v3.zip` vào gốc repo riêng tư, thay file trùng. Giữ `.github`, `Sources`, `Tests`, `scripts`, `tools` và `Licenses`.
2. Commit và chạy workflow **Personal integration - menu-v3**. Phần SharingTests mới phải đạt; các nguồn UIKit được biên dịch ở bước build dylib.
3. Nếu build thành công, tải artifact **personal-menu-v3-Sideloadly-test**. `.deb` mới tên `UnifiedSpotify-Personal_0.2.0-test1.deb`; tên dylib vẫn là `UnifiedSpotifyExperimental.dylib`.
4. Dùng một bản sao IPA Spotify 9.1.90 sạch, inject duy nhất bản mới bằng Sideloadly rồi ký/cài lại. Không dùng IPA đã kèm Chroma/Eevee hoặc nhiều bản dylib thử cũ.
5. Sau khi app có cửa sổ hoạt động, tìm nút **Mod** ở cạnh phải, phía trên khu vực mini player. Gửi ảnh menu và báo cáo trạng thái nếu hook vắng mặt hoặc bộ đếm không tăng sau khi tải feed.
6. Bật từng tính năng để thử: sao chép link Spotify và kiểm tra tracking; thao tác nút phát để kiểm tra rung; xem counter đánh giá khi thực sự có lời gọi review. Bộ đếm 0 không tự chứng minh lỗi hook. Không có thông báo review thử giả.

Nếu không thấy nút Mod sau vài giây, không kết luận dylib đang chạy; cần kiểm tra IPA đầu ra và log injection. Nếu menu báo activation bị chặn, không tự đổi version để vượt kiểm tra; gửi lý do trong báo cáo.

## Đã kiểm tra và chưa kiểm tra

Đã thực hiện kiểm tra cú pháp shell/Node tại máy Windows theo kết quả công cụ; kiểm tra hash các payload gốc được duy trì. Toàn bộ mã UIKit, sharing và state mới cần build cloud và test thật; chưa có screenshot render của menu. Không tuyên bố binary v3 đã được tạo hay chạy thành công cho tới khi có artifact/log của lượt mới.
