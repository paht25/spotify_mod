# Build bản v5 trên GitHub từ Windows

Hướng dẫn hiện tại: [CHROMA-CORE-v5.vi.md](CHROMA-CORE-v5.vi.md).

1. Giải nén `chroma-core-v5-9188.zip`, upload nội dung vào root repo riêng `paht25/cloud`, giữ cấu trúc thư mục.
2. Commit file `.github/workflows/build-core.yml` mới. Trong Actions chạy **Chroma source integration - v5-9188**.
3. Chờ các test, build Chroma + Eevee đã tích hợp, extension và kiểm tra `.deb` thành công.
4. Tải artifact **chroma-core-v5-9188-Sideloadly-test**.
5. Dùng script assembly trong hướng dẫn để nhúng cả extension vào bản sao IPA NoEevee 9.1.88, rồi ký/cài bằng Sideloadly. Không inject lặp `.deb` vào IPA đã được script nhúng.

V5 chưa được Apple toolchain biên dịch/kiểm thử trong phiên này. Không có file `.deb` v5 được tạo giả. Chưa hoàn thành toàn bộ tính năng riêng của Eevee; xem [báo cáo chức năng](reports/UNIFIED-v5-STATUS.md).
