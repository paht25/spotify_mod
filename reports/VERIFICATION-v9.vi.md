# Kiểm chứng v9 — 08/11/2026

Build thành công: https://github.com/paht25/spotify_mod/actions/runs/42467343447

Commit build `24ba7a22e7cc1a021fc5d3174d372531621010d4`, nhánh riêng `personal-v9-9190`. Main và các artifact v8 giữ nguyên.

## Đã kiểm tra

- Apple CI với Xcode 27.1: test core/transport/protobuf/feed/sharing/composition, service hooks và ad-policy đều qua.
- Test production spectrum, preset/EQ validators và HTTP parser qua. Shader Metal tích hợp, tweak ARM64, AppGroups và Live Activity biên dịch thành công. Cấu trúc Debian được dpkg kiểm tra thành công.
- Artifact tải về qua kiểm CRC, hash payload/support, quyền tệp Debian và marker ARM64/v9. Chi tiết: v9-artifact-verification.json.
- Bốn tùy chọn player mới nằm trong mã đã compile: black background, header glass, hide shuffle, hide repeat. Kiểm tra layer và xung đột mã qua; mechanical UI detector không có finding. Không dùng kết quả tĩnh này làm bằng chứng giao diện đã hoạt động trên iPhone.
- IPA ghép từ bản Spotify sạch 9.1.90 được kiểm CRC; SHA-256 `12327552517b5d4c03594b9ae5247eb53c840acecc228eba81780a9cb3b6ea80`. Chưa ký cài, chưa runtime test.

## Cài và thử

File: `C:/Users/Acer/Downloads/deb/Spotify-9.1.90-Personal-v9-unsigned.ipa`. Mở bằng Sideloadly, giữ/ký extension, không inject thêm cùng dylib/deb.

Trong Appearance bật Redesigned rồi restart. Mở Player → Now playing, lần lượt thử từng tùy chọn mới; kiểm tra nút close/menu vẫn chạm được, nền đen không lộ màu ở overscroll và ẩn shuffle/repeat không mất các nút còn lại. Đổi lại tùy chọn và restart để phục hồi các view.

## Chưa hoàn thành / bằng chứng cần có

Người dùng xác nhận chỉ có IPA; không có source Chroma 1.0.1. Public baseline tự khai 0.22.0. Vì vậy bản build này **chưa tái tạo toàn bộ 1.0.1**.

- Player morph, inline mini-player/NavBar và các bố cục mới: cần đối chiếu giao diện gốc cùng view/runtime traces 9.1.90; metadata lớp không chứng minh đầy đủ ngữ nghĩa animation/gesture.
- Lyrics/lock-screen styles và provider extensions: cần xác định từng tùy chọn, dữ liệu/timing gốc và thử trên iPhone; lyrics đồng bộ hiện có vẫn giữ.
- AutoMix: cần adapter đúng API và điều kiện tài khoản/runtime; crossfade không thay thế được.
- Workshop online/remote Web Player: chưa có dịch vụ độc lập tương đương; không giả kết quả từ Chroma backend.
- Local-file metadata/statistics/history, DSP output/song profiles, gestures mở rộng và page-look options: còn thiếu theo inventory. Chưa được biến thành nút giả hoặc đánh dấu hoàn thành.
- Quảng cáo âm thanh Eevee: giữ các sửa v8 và test qua, nhưng vẫn chưa có chẩn đoán lúc quảng cáo xuất hiện; chưa xác nhận hết quảng cáo.
- Native UI, playback, pin/nhiệt, accessibility và signing trên thiết bị: chưa kiểm thử.

Đối chiếu literal tĩnh: `chroma-1.0.1-option-coverage-v9.json`. 485 literal gồm cả notification/cache/infra; số literal không phải số tính năng. Các nhóm thiếu vẫn nằm trong FEATURES-v7.md và kế hoạch đã lưu. Ambient/Sing tiếp tục loại theo yêu cầu, không tính là thiếu; đăng nhập Spotify giữ nguyên.
