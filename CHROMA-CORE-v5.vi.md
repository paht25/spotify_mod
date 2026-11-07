# Tích hợp nguồn v5 — Spotify 9.1.88 / iOS 27

Đây là **source candidate chưa được biên dịch bằng Apple toolchain**, chưa hoàn thành 100% Chroma + Eevee. Build v2/v3 trước đây không xác nhận v5.

## Đã thực hiện

- Đưa đủ 278 tệp mã nguồn Chroma v0.51.0 vào `Integration/Chroma`, cùng thư viện audio, extension và script cần thiết. Giữ nguồn gốc và giấy phép. Không đổi `upstream`, `data-pw`, `data-eve` hoặc IPA đầu vào.
- Một image chính `spotifyglass.dylib`: Chroma sở hữu các màn hình, player, lyrics, artwork, DSP và haptics. Giữ hai chế độ native/redesigned và các trang tùy chỉnh. Mặc định redesigned cho cài mới; lựa chọn đã lưu được giữ.
- Một hàng **Unified Spotify** trong Settings/sidebar gốc, không có nút nổi. Trang Eevee dùng chung giao diện settings Chroma.
- Bootstrap/customize và feed gốc Eevee dùng chung luồng delegate: Eevee xử lý trước, dữ liệu đi vào xử lý lyrics/card Chroma sau. Không nạp hai dylib tweak gốc.
- Các dịch vụ quảng cáo/upsell theo danh sách Eevee có kiểm tra ABI/original IMP; True Shuffle và đồng bộ crossfade; giữ clean-share/rating-block; có chẩn đoán chia sẻ được.
- Export/import/reset settings gồm cả khóa Eevee đã tích hợp, không reset tài khoản Spotify.
- Build Live Activity/App Intents riêng; giữ shim App Groups gốc. Đây là thành phần phụ trợ extension.
- Module Eevee đã chuyển sang C bridge/runtime hooks không cần Orion. Không tạo framework giả. Orion 1.0.2 có thật trong IPA Eevee đã phân tích; điều này không giải quyết các module chưa port.

## Build trên GitHub riêng

1. Giải nén `chroma-core-v5-9188.zip`. Upload **nội dung** vào root repo, giữ đúng `.github/workflows/build-core.yml`, `Integration`, `Sources`, `Resources`, `scripts`, `Tests`, `tools`. Không upload riêng ZIP làm source.
2. Commit; Actions → **Chroma source integration - v5-9188**. Workflow dùng runner `xcode-27` như lần build thành công trước đây; runner phải có SDK iPhoneOS 27+. Nhãn này phụ thuộc dịch vụ runner cấp cho repo.
3. Workflow chạy test Foundation/Swift, test composition/service hooks, build protobuf thật, toàn bộ source Chroma bằng Theos, extension và kiểm tra `.deb` bằng dpkg.
4. Chỉ khi thành công mới có artifact **chroma-core-v5-9188-Sideloadly-test**. Nếu lỗi, lấy log bước thất bại. Chưa có xác nhận build v5 trên máy hiện tại.

Theos cố định commit `8167f59de02fd32cf45b16bfcb1330dfa5c9974c`, SwiftProtobuf 1.29.0 build từ nguồn. Tài liệu chính thức: https://theos.dev/docs/swift và https://theos.dev/docs/installation-macos.

## Chuẩn bị IPA có Live Activity

Sau khi tải artifact thành công về Downloads, chạy từ thư mục project:

```powershell
& './build/python/cpython-3.12.14-windows-x86_64-none/python.exe' tools/assemble-personal-ipa.py `
  --base 'C:/Users/Acer/Downloads/Spotify-9.1.88-NoEevee.ipa' `
  --artifact 'C:/Users/Acer/Downloads/chroma-core-v5-9188-Sideloadly-test.zip' `
  --output 'C:/Users/Acer/Downloads/deb/unified-spotify/build/Spotify-9.1.88-Unified-v5-UNSIGNED.ipa'
```

Python ở đường dẫn trên đã đặt trong `build` của máy hiện tại; ZIP source không chứa Python. Máy khác dùng Python 3.10+ và thay phần lệnh đầu bằng `python`.

Script kiểm tra version/build/hash executable, hash artifact, padding Mach-O và CRC ZIP; không ghi đè input. Nó thêm load commands, image tích hợp, extension, App Intents và thiết lập Liquid Glass/Live Activity vào **bản sao mới chưa ký lại**. Dùng Sideloadly ký/cài IPA output, giữ và ký extension; không thêm lại `.deb`/dylib đã có trong IPA. Khả năng signer giữ extension và cấp entitlement/App Groups phù hợp phải kiểm tra trên thiết bị.

Nếu chỉ inject `.deb`/dylib: **không coi Live Activity đã được cài**, vì thiếu bước nhúng extension/metadata. `.deb` này là container IPA injection, không phải gói rootless jailbreak đã xác minh.

## Test điện thoại

Mở sidebar/Settings → Unified Spotify. Kiểm tra:

- Có menu, không có nút nổi; đổi native/redesigned rồi restart.
- Tab bar, Home/Search/Library, player, queue, scrub/skip/seek, gesture, haptics và từng DSP effect.
- Player → Lyrics: chọn nguồn muốn dùng; bài có/không có lyrics; timeline/seek/translation/pronunciation khi nguồn cung cấp. Source tích hợp không bảo đảm dịch vụ trả dữ liệu cho mọi bài.
- Player → Lock screen widget → Artwork: Canvas/Apple artwork khi khóa màn hình, đổi bài, pause/phát lại.
- Live Activity: sau khi nhúng/ký extension, thử lyrics, queue, control menu và timer.
- Eevee: response/service counters, quảng cáo âm thanh, khởi động và playback. Hook installed chưa chứng minh chặn hết quảng cáo. Xuất diagnostic report nếu lỗi.
- Persistence, export/import/reset settings, đăng xuất chủ động; crash, treo hoặc mất âm thanh.

Xem `reports/UNIFIED-v5-STATUS.md`. **SponsorBlock/reporting, provider/karaoke và tùy chọn giao diện riêng Eevee, các hook session/premium/ad còn lại chưa tích hợp đầy đủ.** Không có xác nhận 100% hoặc bảo đảm hết quảng cáo cho v5. Chỉ upload repo riêng theo quyền tích hợp cá nhân đã xác nhận.
