# Kiểm chứng v8 ngày 08/11/2026

Build thực tế thành công: https://github.com/paht25/spotify_mod/actions/runs/42465861202

- Nhánh riêng `personal-v8-9190`, commit build `3333e66aacf5517ce0edc8636a643cf02c734af6`. Không sửa main.
- Xcode 27.1; biên dịch iOS ARM64, shader Metal tích hợp, AppGroups và Live Activity thành công.
- Test core/transport/protobuf/feed/composition/sharing, service đăng ký muộn, ad-policy và phát hiện IMP bị thay đều qua. Đây là test biên tích hợp bằng fixtures, không phải chạy Spotify.
- Test phổ âm thanh thật, validator preset/GraphicEQ và parser HTTP/capability đều qua trên macOS.
- `dpkg-deb --info/--contents` qua. Kiểm tra artifact tải về: ZIP CRC, hash từng payload, quyền tệp Debian, hash support resources và ARM64/revision markers đều qua.
- IPA ghép từ Spotify sạch 9.1.90, giữ SHA đầu vào gốc. Đã kiểm CRC đầu ra; chưa ký cài. Hash và trạng thái nằm trong file JSON bên cạnh IPA.

Lần build đầu dừng do biến observer được gán nhưng không dùng. Đã sửa bằng class observer có vòng đời theo process; lần build trên đã qua. Còn cảnh báo API unarchive cũ của upstream và linker flag obsolete; không ảnh hưởng kết quả build, chưa thay thuật toán chia sẻ hiện hữu.

## Chưa thể xác nhận

- Không có phiên chạy iPhone của v8: chưa kiểm startup, đăng nhập, giao diện/gesture, GPU, Web Display, âm thanh/DSP, lock-screen/extension hoặc pin/nhiệt.
- Chưa nhận chẩn đoán lúc quảng cáo giữa bài xảy ra. Ad policy được sửa ở mã và qua test; chưa thể kết luận hết quảng cáo. Người dùng sẽ gửi chẩn đoán sau khi thử.
- Redesigned vẫn là nguồn nền tự khai 0.22.0 với module riêng mới; không phải toàn bộ UI Chroma 1.0.1. Player morph còn thiếu adapter 9.1.90. AutoMix, các UI/page options mới và các nhóm nâng cao còn thiếu ghi trong FEATURES-v7.md và kế hoạch ngày 09/11.
- Ambient/Sing đã loại có chủ đích; lyrics đồng bộ vẫn giữ. Spotify login không bị thay.

## Cài thử

Mở `C:/Users/Acer/Downloads/deb/Spotify-9.1.90-Personal-v8-unsigned.ipa` bằng Sideloadly, giữ/ký extension. IPA đã có tweak; không inject thêm cùng `.deb`/dylib. Bật Redesigned trong Appearance, restart rồi kiểm tra. Nếu quảng cáo xuất hiện, dùng Eevee integration → Share diagnostic report. Chỉ đánh dấu chức năng PASS sau kiểm tra trên thiết bị.
