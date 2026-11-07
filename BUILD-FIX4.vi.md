# Fix4: thay tất cả 11 file còn conflict trong log mới

`job-logs.txt` ghi nhận repo `paht25/spotify_mod`, commit `1e4bcde03ee71d9b8762d6918ebb55c4a37039af`. Workflow đã parse và checkout được. Preflight dừng vì 11 file còn marker xung đột. Lần chạy này chưa tới compiler/test hay đóng gói.

Fix4 cung cấp nguyên file sạch cho **toàn bộ 11 đường dẫn được log báo**, đồng thời giữ workflow, Protobuf, header giao diện và preflight đã sửa ở fix1–fix3. Không ghép hai nhánh source và không chỉ xóa marker. Đây là source sửa build; không phải `.deb` và không xác nhận đầy đủ chức năng Eevee.

## Nếu bạn đang upload bằng giao diện GitHub

1. Giải nén `chroma-v5-build-fix4.zip`.
2. Thay nguyên file trong repo theo đúng đường dẫn thư mục trong ZIP, gồm `Sources`, `Tests`, `target.json`, `Integration`, `scripts`, `tools` và `.github`. Không upload ZIP nguyên khối thay cho source.
3. Nếu GitHub yêu cầu giải quyết merge, thay toàn bộ nội dung mỗi file bằng bản sạch trong ZIP rồi đánh dấu resolved. Không chọn Accept both hoặc nối thêm source ở cuối file cũ.
4. Commit lên `main`. Chạy **Chroma source integration - v5-9188 → Run workflow → main**, xem run của commit mới.

## Nếu bạn có bản clone repo trên Windows

Giải nén bản vá ở một thư mục **ngoài checkout**, ví dụ Downloads. Mở terminal tại root bản clone `spotify_mod` và chạy Node với đường dẫn thật tới script trong bản vá:

```powershell
node "C:/Users/Acer/Downloads/chroma-v5-build-fix4/apply-clean-files.mjs" .
```

Nếu bạn giải nén ở nơi khác, thay đường dẫn script cho đúng. Script yêu cầu Git/Node có sẵn và origin trỏ tới `paht25/spotify_mod` hoặc repo `paht25/cloud` cũ. Nó kiểm tra hash tất cả payload trước khi sửa, chép đè source sạch, lưu file cũ dưới thư mục `backups` **bên trong thư mục bản vá**, rồi chạy preflight trên checkout. Không xóa file, không sửa `.git`, không merge, commit hay push tự động. Nếu còn conflict ở file khác, nó báo đường dẫn và dừng trước bước commit của bạn.

Sau khi script thành công, xem thay đổi rồi commit/push như bình thường. Nếu repo đang trong merge, cần stage các file đã giải quyết trước khi hoàn tất merge. Không cần áp dụng lại fix1–fix3 riêng vì fix4 đã chứa các file đó.

## Danh sách 11 file trong log

- `Sources/Eevee/Feed/BrowsitaSectionStripper.swift`
- `Sources/Eevee/Premium/Account.pb.swift`
- `Sources/Eevee/Premium/BootstrapMessage+Extension.swift`
- `Sources/Eevee/Premium/BundledConfigurationPolicy.swift`
- `Sources/Eevee/Premium/EeveePropertyReplacement.swift`
- `Sources/Eevee/Premium/ModifyRemoteConfiguration.swift`
- `Sources/Eevee/Premium/ServerSidedFeaturePolicy.swift`
- `Sources/Eevee/Premium/UcsResponse+Extension.swift`
- `Sources/Eevee/Sharing/CleanShareLinks.swift`
- `Tests/EeveeFeed/main.swift`
- `target.json`

File local thay thế không chứa marker; gói ZIP được kiểm hash/CRC. Công cụ đã được chạy với bản vá thật trên checkout Git cô lập: 18 file đích khớp hash, backup giữ nguyên byte cũ, áp dụng lần hai không đổi thêm file, payload hỏng hoặc đường dẫn thoát thư mục bị từ chối trước khi chép. Đây là kiểm tra công cụ sửa source, không phải runtime Spotify.

Chưa có run cloud sau fix4, chưa xác nhận full dylib/extension/`.deb` hoặc Spotify trên thiết bị. Kết nối GitHub trong phiên vẫn trả 404 cho repo riêng, nên chưa có thay đổi nào được ghi trực tiếp lên remote.
