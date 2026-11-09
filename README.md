# PwEevee UI fixes · r4

Repo build IPA qua GitHub Actions trên macOS. Source nền là PwEevee v3.1.6.1;
`upstream.lock.json` ghi commit gốc và SHA-256 ZIP source 0.23.0 do bạn cung cấp.

R4 chuyển nguyên tùy chọn **Navbar → Apple Music style player** của 0.23.0:

- Navbar dùng `UITabBarController`, mini-player là `UITabAccessory` hiển thị thật.
- UIKit tự co/mở navbar và đưa cùng một accessory xuống giữa hai tab khi cuộn.
- Giữ phần cài đặt Navbar của 0.23.0, thao tác tab, mở player, play/pause và swipe đổi bài.
- Bỏ `NativeTabMotion.x`, cơ chế thu gọn cũ và mini-player mô phỏng của r3.
- Giữ chiều rộng/chiều cao của PwEevee: navbar độc lập được dùng làm mốc đo không hiển thị;
  viewport của controller được căn theo mốc đó. Now Playing lấy chiều cao từ card gốc (56 pt
  trong fixture), compact accessory 48 pt; navbar mở rộng 62 pt trong fixture.
- Giữ các sửa **Bottom navbar gradient** và **Show profile photo**; không đổi UI ngoài phần này.

Tùy chọn mới mặc định bật nếu chưa có lựa chọn đã lưu. Bật/tắt trong **Navbar → Apple Music
style player**, rồi khởi động lại app để áp dụng, giống 0.23.0. Khi tắt, dùng navbar và card độc lập.
Redesigned UI cần iOS 26+.

## Build trên GitHub

1. Actions → Build PwEevee UI fixes → Run workflow, chọn `main`.
2. Để trống input để dùng IPA release 3.1.6.1 đã ghim checksum. Có thể nhập URL HTTPS trực tiếp
   và SHA-256 để dùng một base khác.
3. Chờ `checks`, `runtime`, `build` thành công.
4. Tải artifact **PwEevee-3.1.6.1-ui-fixes-r4**, giải nén và ký lại IPA bằng công cụ sideload.

Push `main` cũng chạy build. CI dùng IPA release công khai; file riêng trên Windows không tự được
upload. Bản giao cục bộ được đóng gói từ đúng IPA bạn gửi, chỉ thay `Frameworks/spotifyglass.dylib`.
Packer kiểm tra danh sách entry và hash nội dung từng file còn lại: executable, extension, icon,
framework khác được giữ nguyên. IPA cần ký lại trước khi cài.

## Kiểm tra

`runtime` biên dịch module Navbar/mini-player/settings thật vào fixture UIKit, dùng Spotify data và
navigation giả lập. Test đo kích thước sau layout, bật/tắt hai tùy chọn Appearance, bật/tắt toàn bộ
option qua restart, cuộn bằng gesture và kiểm tra các thao tác player/tab được chuyển đến Spotify.
`ui-runtime-results` chứa screenshot, số đo và kết quả test. Fixture không thay cho kiểm tra toàn bộ
Spotify trên iPhone thật; cần xác nhận cảm giác animation và tích hợp trên thiết bị sau khi cài.

Build thủ công với Xcode 26+, Theos, Python 3.11+, `brew install make dpkg ldid`:

```sh
bash scripts/check.sh
THEOS="$HOME/theos" bash scripts/build-ipa.sh "/absolute/path/PwEevee-3.1.6.1.ipa"
```

Output trong `dist/`, kèm `BUILD-MANIFEST.json`. `patches/pweevee-ui-fixes.patch` là diff sản phẩm
so với release gốc. Giấy phép source và catalog SF Symbols nhập từ 0.23.0 được giữ trong repo.
