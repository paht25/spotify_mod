# Fix3: workflow sạch và bản vá cộng dồn

Ảnh run #10, commit hiển thị `295b1a0`, cho thấy `.github/workflows/build-core.yml` chứa các marker xung đột giữa workflow v5 và v3. GitHub không thể parse YAML nên chưa khởi chạy job. Preflight trong job không thể sửa hoặc phát hiện lỗi trước khi chính workflow được parse thành công.

Ảnh là snapshot của workflow tại commit của run đó, không xác nhận nội dung `main` hiện tại. Sau khi sửa, trang run cũ vẫn giữ lỗi cũ; phải kiểm tra run mới.

## Cách áp dụng

1. Giải nén `chroma-v5-build-fix3.zip`. Bản vá gồm workflow sạch và toàn bộ file sửa của fix1/fix2.
2. Ở tab **Code**, nhánh **main**, thay nguyên file `.github/workflows/build-core.yml` bằng file cùng đường dẫn trong ZIP. Nếu chỉnh trên web: mở đúng file → Edit → **Ctrl+A** → dán toàn bộ nội dung sạch → Commit changes. Không sửa trong trang Workflow file của run cũ; không chỉ xóa vài marker vì file còn những đoạn xung đột khác.
3. Thay cả các file source/script/tool còn lại trong ZIP theo đúng đường dẫn. Commit tất cả thay đổi lên `main`; nếu có thể hãy gom chúng vào một commit.
4. Trong Actions, kiểm tra run của **commit mới**. Sửa file workflow sẽ kích hoạt push run theo cấu hình. Nếu cần: mở **Chroma source integration - v5-9188** → Run workflow → chọn `main`.

Nếu Git đang yêu cầu giải quyết merge, các file bị conflict cần được thay bằng nội dung sạch và đánh dấu resolved trước khi commit; không dùng Accept both để ghép hai workflow hay hai bản source hoàn chỉnh.

Workflow mới có bước **Check source for unresolved merge conflicts** ngay sau checkout, trước khi tải/build dependencies. Nếu bước này báo file khác ngoài bản vá, phải giải quyết đúng nội dung file đó trước khi tiếp tục. Không thể kiểm tra toàn bộ repo riêng từ ảnh này; bản vá không khẳng định đã sửa remote repository.

## Kiểm tra đã làm

- Workflow sạch parse YAML thành công với kiểm tra key trùng; có cả workflow_dispatch và push, một job core và bước preflight đầu tiên sau checkout.
- Source/configuration trong project local không còn marker.
- ZIP đã kiểm CRC/hash và gồm hai file Protobuf sạch, dòng import SGPageStyle.h của fix1, hai script và tool preflight của fix2.
- Chưa có kết quả cloud build sau fix3; chưa xác nhận dylib/extension/`.deb` hay chức năng iPhone thành công.
