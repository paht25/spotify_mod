# spotify_mod — PwEevee UI fixes

Repo này build IPA bằng **GitHub Actions trên macOS**, không cần máy Mac riêng.
Source trong `app/` lấy từ PwEevee `v3.1.6.1`, commit được ghi trong `upstream.lock.json`.
Bộ code cũ đã được thay thế; lịch sử Git vẫn giữ để có thể khôi phục.

Các thay đổi UI:

- Căn mép trái/phải của Now Playing theo phần glass hiển thị của bottom navbar.
- Tắt Bottom navbar gradient sẽ gỡ fade riêng và ẩn bottom scroll-edge effect tương ứng.
- Dùng chuyển động UIKit từ cơ chế của IPA mẫu 0.23.0 để thu gọn/mở lại player và tab khi cuộn;
  navbar gốc vẫn là thanh đang hiển thị, không thay bằng navbar của mẫu.
  Bản r3 đối chiếu trực tiếp ZIP source 0.23.0 bạn gửi: chuyển phần gắn scroll view/appearance,
  cache vị trí và icon, cập nhật bài hát qua observer, dừng marquee trong lúc morph và animate
  layout UIKit khi đảo chiều để tránh nhảy về trạng thái mở rộng.
  Trạng thái accessory kích hoạt một animation UIKit chung cho player và tabs. Core Animation tự nội suy;
  không đọc tọa độ rồi gán lại frame UI ở mỗi tick, tránh giật khi UIKit đổi hierarchy hoặc Spotify bận layout.
- Show profile photo điều khiển cả hiển thị, tương tác và VoiceOver, kể cả khi header cập nhật lại.

Giữ nguyên navbar gốc khi mở rộng: các tab, thứ tự, icon, nhãn và chất liệu glass.
Source của giao diện Native không thay đổi.

## Build trên GitHub

1. Mở **Actions → Build PwEevee UI fixes → Run workflow** và chọn `main`.
2. Để trống hai ô input để dùng IPA PwEevee 3.1.6.1 từ release gốc đã ghim SHA-256.
   Nếu muốn dùng đúng file IPA riêng của bạn, nhập link tải HTTPS trực tiếp và SHA-256 của file đó.
3. Chờ `checks`, `runtime` và `build` thành công. `runtime` kéo cuộn thật và thao tác toggle trên simulator.
4. Mở run, tải artifact **PwEevee-3.1.6.1-ui-fixes-r3** rồi giải nén.
5. Ký lại file `.ipa` bằng công cụ sideload bạn đang dùng, sau đó cài lên iPhone.

Push vào `main` cũng tự chạy build. Workflow không cần certificate hoặc secret để xuất IPA chờ ký.
IPA base mặc định là bản release công khai; không phải file đang nằm trên máy Windows của bạn.
Nếu dùng file khác, phải nhập đúng cả URL và SHA-256.

Kết quả gồm IPA, `spotifyglass.dylib` và `BUILD-MANIFEST.json`. Bước đóng gói chỉ thay
`Payload/Spotify.app/Frameworks/spotifyglass.dylib` và kiểm tra mọi entry còn lại có nội dung giống hệt
IPA đầu vào. Không rebuild executable Spotify, icon, extension hay thư viện khác.

## Kiểm tra trên iPhone

Dùng iOS 26+ và bật Redesigned UI; khởi động lại app sau khi cài bản build mới.
Phát hoặc pause một bài, kiểm tra độ rộng Now Playing, thử hai toggle trong Appearance, rồi cuộn xuống/lên
trên một trang dài và đảo chiều giữa animation. Kiểm tra lại sau khi chuyển tab và khởi động lại app.
Khi không có bài, navbar phải giữ trạng thái mở rộng. Với Reduce Motion, trạng thái vẫn hoạt động.

CI kiểm tra build, nội dung archive và hành vi UIKit trong fixture simulator. Artifact
`ui-runtime-results` chứa ảnh và kết quả test. Fixture không phải toàn bộ app Spotify; hiệu ứng hiển thị
và timing vẫn cần xác nhận trên thiết bị thật.
Lượt test cuộn lưu thêm video simulator và trace trạng thái hiển thị, kiểm tra cả chiều thu gọn/mở lại
có nhiều trạng thái trung gian, không chạy ngược và player/tabs đều có animation trên compositor.

## Source và kiểm tra

- `app/tweak/Sources/Redesigned/`: các sửa UI, đã tích hợp trực tiếp vào source.
- `patches/pweevee-ui-fixes.patch`: bản diff so với release gốc để đối chiếu.
- `.github/workflows/build-ipa.yml`: pipeline mới.
- `scripts/check.sh`: kiểm tra layer, trạng thái cuộn, đóng gói và cấu hình tải IPA.
- `app/harness/home-header/`: harness profile photo cho simulator trên Mac Apple silicon.
- `LICENSE`, `app/vendor/audio/`: giấy phép và notice gốc được giữ lại.

Build thủ công trên Mac có Xcode 26+, Python 3.11+, Theos và `brew install make dpkg ldid`:

```sh
bash scripts/check.sh
THEOS="$HOME/theos" bash scripts/build-ipa.sh "/absolute/path/PwEevee-3.1.6.1.ipa"
```

Output nằm trong `dist/`. Mỗi lần build dùng checkout sạch hoặc tên output mới vì packer không ghi đè file cũ.
