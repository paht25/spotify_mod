# Build fix2: loại bỏ xung đột Git trong Protobuf

Log `logs_114798257368.zip`, commit `27c586269e139f8e31b9bc7fe7c97f478e479487`, dừng ở test transport vì hai file này bắt đầu bằng dấu xung đột Git:

```text
Sources/Chroma/Wire/Protobuf.h
Sources/Chroma/Wire/Protobuf.m
```

Bản local của hai file này sạch và trùng từng byte với nguồn Chroma v0.51.0 trong `upstream/Chroma-reference/tweak/Sources/Shared/Lyrics`. Fix2 cung cấp nguyên file sạch, giữ nguyên thuật toán đọc/ghi protobuf; không xóa tùy ý một nhánh xung đột chưa xem nội dung. Nó cũng giữ dòng import của fix1 và thêm preflight phát hiện marker trong source/config trước khi test/build.

## Áp dụng bản vá nhỏ

1. Giải nén `chroma-v5-build-fix2.zip`.
2. Ghi đè các file theo đúng đường dẫn tương đối trong ZIP ở root repo, bao gồm hai file Protobuf, `UnifiedSettings.m`, hai script và tool preflight. Giữ đúng chữ hoa/thường của đường dẫn.
3. Nếu GitHub báo conflict khi merge, dùng nguyên nội dung file sạch tương ứng trong ZIP để thay file, kiểm tra không còn marker rồi commit. Không chỉ xóa dòng `<<<<<<< HEAD`, vì phần nội dung hai nhánh ở giữa có thể bị lặp.
4. Commit lên `main`. Actions → **Chroma source integration - v5-9188** → **Run workflow**, chọn `main`. Không chỉ Re-run run của commit lỗi cũ.

Nếu dùng Git cục bộ, sau khi copy file có thể kiểm tra trước khi push:

```powershell
node tools/check-source-conflicts.mjs
git diff --check
git status --short
```

Preflight sẽ báo rõ đường dẫn/dòng nếu repo còn file khác bị conflict. Không bỏ qua preflight để tiếp tục build.

Run mới chỉ xác nhận CoreTests đã qua rồi dừng sớm; chưa chạy transport và các bước sau đó. Run trước đó đã có các test thành phần qua, nhưng không thay thế việc chạy lại source hiện tại. Fix1 chưa được kiểm chứng trong run này vì build chưa tới giao diện. Chưa có xác nhận build thành công dylib/`.deb` hoặc hoạt động trên Spotify sau fix2.
