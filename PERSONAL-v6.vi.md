# Bản cá nhân v6 — Spotify 9.1.90

Đích chính xác: iOS 27, Spotify 9.1.90 build 919002269, ARM64, ký/cài bằng Sideloadly. Nguồn Chroma 0.51.0 làm chủ giao diện. Native và Redesigned có thiết lập riêng. Cấu hình, feed và tiện ích Eevee chạy trong cùng một image; không nhúng hai tweak gốc cạnh nhau.

## Thay đổi

- Tạo lại bảng 2.523 cờ từ binary 9.1.90 bạn cung cấp: 2.361 cờ có kiểu/default đọc được, 162 cờ chưa xác định; không đoán default.
- Thêm xử lý trạng thái quảng cáo lúc tạo playback product state, lúc cập nhật và lúc đọc; kiểm tra đúng selector/ABI của 9.1.90. Phần mới cần thử nghe thực tế, chưa xác nhận hết quảng cáo.
- Đồng bộ mặc định công tắc Redesigned với chế độ chạy. Bật Redesigned sau reset stock sẽ bỏ dấu reset để mặc định profile áp dụng; giữ các lựa chọn lưu riêng. Đổi chế độ cần restart.
- Thêm báo cáo chế độ đang chạy, implementation của hook, player field và các lượt đọc trạng thái quảng cáo. JSON phân biệt bootstrap, customize và feed.
- Bỏ donate, cập nhật/quảng bá, Discord và gửi usage tác giả khỏi bản biên dịch. Giữ giấy phép/ghi công trong Licenses và đường dẫn dữ liệu cũ để không mất preset/tệp âm thanh.

## Build trên GitHub

Upload nội dung `personal-v6-9190-source.zip` vào root repo private, giữ đúng đường dẫn. Không upload IPA. Chạy **Chroma source integration - v6-9190** trên `main` với runner `xcode-27` đã chạy được. Cần commit mới; re-run job cũ không lấy mã mới.

Workflow chạy test thành phần, composition, service và ad-policy; build protobuf thật, tweak bằng Theos đã ghim, Live Activity và kiểm tra Debian. Khi xanh hết, tải **personal-v6-9190-Sideloadly-test**. Dự kiến có `spotifyglass.dylib`, `SpotifyGlassAppGroups.dylib`, `UnifiedSpotify-ChromaEevee_0.5.0-test1.deb`, manifest và thư mục `live-activity`.

## Chuẩn bị IPA để giữ Live Activity

Dùng Python 3.10+ trên Windows sau khi tải artifact thật. Đổi đường dẫn artifact theo vị trí tải; đầu ra phải chưa tồn tại:

```powershell
python tools/assemble-personal-ipa.py --base "C:/Users/Acer/Downloads/Spotify-9.1.90-Clean-Decrypted.ipa" --artifact "C:/Users/Acer/Downloads/personal-v6-9190-Sideloadly-test.zip" --output "C:/Users/Acer/Downloads/deb/Spotify-9.1.90-Personal-v6-unsigned.ipa"
```

Script kiểm tra version/build, hash executable/artifact, nhúng dylib + extension + App Intents, đặt native glass compatibility đúng rồi kiểm tra ZIP. IPA đầu ra **chưa ký**. Mở IPA mới bằng Sideloadly, giữ và ký extension Live Activity. Không thêm lại `.deb`/dylib vào IPA đã nhúng. Giữ bundle identity nhất quán khi ký để tương tác màn hình khóa mở đúng app.

Nếu chỉ thử inject bằng Sideloadly, `.deb` chứa hai thư viện là đầu vào thử; cách đó không tự cài Live Activity extension. Không cài Debian này bằng trình quản lý jailbreak rootless: nó là container cho IPA injection, chưa phải gói rootless kiểm chứng.

## Kiểm tra trên máy

1. Spotify → Settings/sidebar → Unified Spotify. About phải ghi **Personal v6**, Spotify **9.1.90**.
2. Appearance → bật Redesigned UI → restart. Thử tab bar, thanh phát nhỏ, player, Search, Library và các trang nội dung. Active look trong Eevee diagnostics phải khớp.
3. Bật patch cấu hình, ad services và audio ads rồi restart. Thử nhiều bài qua thời điểm trước đây có quảng cáo; ghi nhận quảng cáo, khoảng im lặng hoặc bài xám/không phát. Không coi số đếm tăng là bằng chứng chặn thành công.
4. Thử lyrics từng nguồn và bài không có lyrics Spotify, lock-screen lyrics/artwork, Live Activity/controls, speed/pitch, DSP, gestures, haptics, export/import settings theo checklist.
5. Mở player rồi chọn **Share diagnostic report**. JSON phân biệt chế độ chưa bật, hook chưa nạp và player chưa tạo view; không chứa token hay phản hồi tài khoản.

## Phần còn thiếu đã xác định

`SPTBarOverlayPresentationTransition` không có trong 9.1.90. Hai hook dùng nó cho chuyển cảnh mini-player/player không chạy. Cần xác định vòng đời/progress/context của transition mới qua phân tích và quan sát runtime; không thay bằng lớp khác chỉ vì tên giống.

Các nhóm riêng Eevee như UI/karaoke/provider bổ sung, SponsorBlock và một phần session/premium chưa port đầy đủ. Nguồn Chroma có mặt không đồng nghĩa mọi chức năng 0.51.0 đã chạy trên 9.1.90. Xem [bảng kiểm chứng](reports/UNIFIED-v6-STATUS.md). V6 chưa có kết quả build Apple, cài đặt hay runtime; chưa hoàn tất 100%.
