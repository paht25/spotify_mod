# Build nhánh cá nhân v8

Đây là nhánh mã mới, chưa hoàn tất toàn bộ tính năng Chroma 1.0.1. Ambient và Sing/tách giọng đã được loại theo yêu cầu; lyrics đồng bộ vẫn giữ.

Bản v8 đã build thành công ở commit `3333e66aacf5517ce0edc8636a643cf02c734af6`, nhánh `personal-v8-9190`. Workflow: https://github.com/paht25/spotify_mod/actions/runs/42465861202. IPA đã ghép đặt tại `C:/Users/Acer/Downloads/deb/Spotify-9.1.90-Personal-v8-unsigned.ipa`; mở bằng Sideloadly và giữ/ký extension. Không inject thêm cùng dylib/deb vào IPA đã ghép. Các bước dưới dùng để tái tạo build.

1. Giải nén `personal-independent-v8-9190-source.zip`, upload nội dung vào root repo private đang build, giữ các thư mục `.github`, `Integration`, `Sources`, `Tests`, `scripts`, `tools`, `Resources`, `Generated`, `Licenses`. Không upload các IPA Spotify hoặc thư mục `analysis`.
2. Chạy workflow **Personal independent modules - v8-9190** trên commit mới. Nó chạy các test trước đó cùng test phổ âm thanh, validator preset/EQ và HTTP cục bộ, rồi build ảnh ARM64 và Live Activity. Nếu runner có Metal compiler, shader tích hợp cũng được biên dịch kiểm tra; nếu thiếu, log ghi rõ phần đó chưa được kiểm chứng.
3. Chỉ sau khi build thành công mới tải **personal-independent-v8-9190-Sideloadly-test**. Gói dự kiến là `UnifiedSpotify-Personal_0.6.1-test1.deb`; chưa có binary v8 trong bộ nguồn này.
4. Tạo IPA có Live Activity và tài nguyên Web Display bằng Python 3.10+:

```powershell
python tools/assemble-personal-ipa.py --base "C:/Users/Acer/Downloads/Spotify-9.1.90-Clean-Decrypted.ipa" --artifact "C:/Users/Acer/Downloads/personal-independent-v8-9190-Sideloadly-test.zip" --output "C:/Users/Acer/Downloads/deb/Spotify-9.1.90-Personal-v8-unsigned.ipa"
```

Dùng bản Spotify sạch, không dùng `chroma-1.0.1.ipa` làm nền. IPA Chroma chỉ là tài liệu đối chiếu; nạp cùng bản gốc sẽ trùng chủ sở hữu UI/hook. Script kiểm tra đúng executable và marker v8, không ghi đè IPA gốc. Mở IPA mới bằng Sideloadly, giữ/ký extension, không inject lại cùng tweak.

## Thử các phần mới

Settings/sidebar → Unified Spotify → Personal features:

- Bật Audio-reactive background trong chế độ Redesigned, restart, phát nhạc và mở player. Spectrum/Orbit/Wave phải bám âm thanh thật và dịu về im lặng khi dừng. Theo dõi Status nếu chưa có audio tap hoặc shader lỗi.
- Local Workshop → Import file → chọn `.metal`, `.ttf/.otf`, preset `.json` hoặc GraphicEQ `.txt`. Chạm tệp để Apply/Delete. Import không tự áp preset hay font. Đổi font cần restart để thay text đã được tạo. DSP preset có tác dụng qua engine âm thanh thật.
- Web Display → bật trên Wi-Fi riêng → Copy private link → mở trên máy tính/TV cùng mạng. Không truyền nhạc, chỉ trạng thái/bìa/lyrics. Allow browser playback control là lựa chọn riêng, mặc định tắt. Link đổi sau mỗi lần bật/restart; tắt Web Display sẽ vô hiệu hóa link. Bản này dùng HTTP trong mạng nội bộ và không có relay Internet. Không bật trên Wi-Fi không tin cậy.

Thư viện cục bộ đặt trong Documents/UnifiedSpotify/Library. Nó không dùng tài khoản hay server Chroma. Shader dùng giao diện MSL được mô tả trong [định dạng tài nguyên](Resources/Personal/FORMAT.md), không tự coi shader Chroma là tương thích.

## Điều chưa được xác nhận

Mã player/Redesigned/NavBar cũ không tương đương đầy đủ 1.0.1. Native AutoMix, remote Workshop, CSS lock-screen styles, local-file metadata library, statistics và một số điều khiển mới còn thiếu. Chuyển cảnh dùng lớp Spotify cũ cũng chưa có adapter 9.1.90. Các phần đã viết mới vẫn cần Apple build và test thiết bị; không coi số lượng tệp hoặc workflow xanh là bằng chứng đủ tính năng.
