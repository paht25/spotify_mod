# Fix5: cập nhật API UIKit cho SDK 27.1

Log mới, repo `paht25/spotify_mod`, commit `1732aa3f04744f5bc823080d5cc3906fb8604afa`, xác nhận:

- Preflight không còn conflict.
- Các test core, transport/wire, feed, delegate, sharing, premium, composition và service hooks đều qua.
- Thư viện core ARM64 đã được tạo.
- Build tweak dừng tại `Redesigned/Kit/SGRDownload.m:215`: lời gọi super của `traitCollectionDidChange:` bị deprecated và nâng thành lỗi bởi `-Werror`.

## Bản sửa

Chỉ thay một file:

```text
Integration/Chroma/tweak/Sources/Redesigned/Kit/SGRDownload.m
```

Trong init, giữ lần paint đầu tiên và đăng ký `UITraitCollection.systemTraitsAffectingColorAppearance` bằng `registerForTraitChanges:withAction:` để gọi lại `sgr_paint`. Bỏ override deprecated. Giữ nguyên trạng thái/progress/animation của glyph và không tắt `-Werror`. Chỉ sửa bản tích hợp; source upstream và payload gốc không thay đổi.

Tham chiếu khai báo/API UIKit chính thức:

- [Đăng ký trait với selector trên chính view](https://developer.apple.com/documentation/uikit/uitraitchangeobservable-7qoet/registerfortraitchanges%3Awithaction%3A)
- [Nhóm trait ảnh hưởng đến màu](https://developer.apple.com/documentation/uikit/uitraitcollection/systemtraitsaffectingcolorappearance-18zhm)

Target đang là iOS 27 nên không thêm nhánh fallback dùng callback cũ.

## Áp dụng

1. Giải nén `chroma-v5-build-fix5.zip` và thay **nguyên** `SGRDownload.m` vào đúng đường dẫn trong repo. Không cần chép lại các file Swift đã sạch.
2. Commit lên `main`.
3. Actions → **Chroma source integration - v5-9188 → Run workflow → main**. Sửa riêng file source không tự kích hoạt push run theo bộ lọc workflow hiện tại. Không chỉ Re-run run của commit cũ.

Bản sửa qua preflight, kiểm tra phân lớp và kiểm CRC/hash gói ZIP. Chưa có Apple compilation sau sửa tại máy này; cần run mới để xác nhận toàn bộ build. Chưa có full dylib/extension/`.deb` hoặc test iPhone thành công. Những phần Eevee chưa port vẫn giữ trạng thái trong báo cáo chức năng.
