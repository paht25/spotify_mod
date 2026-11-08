# Tiếp tục tái tạo Chroma 1.0.1 — v9

## Mã đã bổ sung

Bốn tùy chọn được viết độc lập trên renderer Redesigned hiện có:

- **Black player background:** backing đen phủ vùng nền và overscroll, tắt flow/backdrop ảnh khi bật; giữ controls và visualizer tùy chọn phía trên.
- **Glass behind header buttons:** bật/tắt phần kính trang trí, giữ nút đóng/menu, vùng chạm và hành động Spotify.
- **Hide shuffle / Hide repeat:** chỉ ẩn bằng alpha/touch/accessibility trên hàng năm nút đã nhận diện, không dùng hidden để làm hỏng stack Spotify. Restart để phục hồi view nếu đổi lại tùy chọn.

Các tùy chọn nằm ở Player → Now playing khi bật Redesigned. Nền đen/ẩn nút mặc định tắt; kính mặc định bật, giữ cách hiển thị cũ. Các chế độ Native và Redesigned có key riêng. Không thêm hook Spotify thứ hai cho cùng các tùy chọn.

Tên khóa có bằng chứng trong IPA Chroma 1.0.1; cách triển khai trên là của project này, không phải tuyên bố đã xác minh mọi chi tiết/default/animation của bản gốc. UI native vẫn cần kiểm tra trên iPhone.

## Điều chưa hoàn thành

Không thể gọi nhánh này là bản tái tạo đầy đủ 1.0.1. File tham chiếu là IPA đã biên dịch, không có source 1.0.1. Các nhóm player/layout/morph, inline mini-player/NavBar, các trang nội dung mới, lyrics styles/providers, lockscreen styles, AutoMix, Workshop online, metadata/history, DSP theo output và gestures mở rộng còn khoảng trống trong inventory/kế hoạch.

`chroma-1.0.1-option-coverage-v9.json` đối chiếu từng literal cấu hình với mã: chỉ là kiểm tra tĩnh, không phải số lượng tính năng hoạt động. Không có literal trùng không đồng nghĩa tính năng chắc chắn vắng; có literal trùng không chứng minh tính năng đã hoạt động. Caches/notifications cũng xuất hiện trong danh sách.

Ambient và Sing vẫn được loại theo yêu cầu; lyrics đồng bộ và đăng nhập Spotify giữ nguyên. Không giả Plus entitlement và không sử dụng backend Chroma để thay thế phần chưa viết.
