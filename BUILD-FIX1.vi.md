# Sửa lỗi build v5 từ logs_114796457459.zip

Log của commit `9a63499e9585ceae0405883cb07f513d9ecd4593` cho thấy các test core, transport/protobuf, feed, delegate hooks, sharing, premium, composition và service hooks đã qua trên Xcode/SDK 27.1. Thư viện ARM64 core đã build. Build tweak dừng tại `UnifiedSettings.m` vì thiếu khai báo `SGTopController()`; chưa tạo xong dylib hoặc `.deb`.

Sửa đúng một dòng import trong:

```text
Integration/Chroma/tweak/Sources/App/UnifiedSettings.m
```

```objc
#import "Settings/SGPageStyle.h"
```

Header này chứa khai báo hàm gốc `UIViewController *SGTopController(void);`, giống cách các trang Chroma khác đang sử dụng. Không đổi hành vi UI và không tắt kiểm tra compiler.

## Áp dụng

1. Giải nén `chroma-v5-build-fix1.zip`, thay `UnifiedSettings.m` theo đúng đường dẫn trên trong repo. Không đặt file này ở root hoặc trong `Sources/Core`.
2. Commit bản sửa lên `main`.
3. Vào Actions → **Chroma source integration - v5-9188** → **Run workflow** → chọn `main`.

Không chỉ bấm **Re-run all jobs** trên run lỗi cũ: run đó sử dụng commit cũ và không nhận dòng import mới. Workflow hiện lọc sự kiện push theo file workflow, nên sửa riêng source cần chạy thủ công.

Bản vá đã qua kiểm tra phân lớp và đóng gói/hash cục bộ. Chưa có lần build cloud chạy lại sau sửa; không coi `.deb` hay chức năng Spotify đã thành công. Những nhóm tính năng Eevee chưa port trong báo cáo v5 vẫn còn nguyên trạng thái đó.
