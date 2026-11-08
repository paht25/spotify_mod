# Bản sửa v8 — 08/11/2026

## Thay đổi mã thật

- Cài bổ sung các hook Eevee còn thiếu khi có image mới, khi app trở lại foreground và mỗi 30 giây khi đang active. Mỗi lần chỉ nhận selector chưa có owner và ABI phù hợp; không cài đè hook hiện hữu. Không làm thao tác Objective-C trong callback khóa loader. Cơ chế này thay giới hạn chỉ thử lại 1/3/8 giây đầu; chưa chứng minh đây là nguyên nhân quảng cáo người dùng gặp.
- Ad policy xử lý thêm `ad-formats` và getter `overrides` của SPTCoreProductState. Các selector này hiện diện trong metadata Spotify 9.1.90 đã đọc. Không sửa country, chất lượng/offline hay gọi API ghi tài khoản.
- Theo dõi dictionary có `ads` bật và có `ad-formats` bằng bộ đếm; không lưu account ID hay nội dung bài. Bộ đếm gồm cả getter snapshots, không thể dùng làm số lần quảng cáo bị chặn.
- Registry lưu IMP đã cài để phát hiện selector bị thay sau đó. Trước đây chẩn đoán chỉ dùng tên dylib, không đáng tin với IMP trampoline của Objective-C block. Không tự chiếm lại hook bị thay.
- Chẩn đoán bổ sung trạng thái policy/service đang bật, cần restart renderer và lớp UIGlassEffect có sẵn hay không.
- Thêm regression tests cho dịch vụ đăng ký muộn, snapshot overrides, ad-formats và IMP bị thay. Các test Foundation cần Apple CI; không gọi là đã PASS khi chưa chạy.

## Giới hạn chưa giải quyết

Chưa nhận chẩn đoán lúc quảng cáo xảy ra, nên chưa xác định root cause và chưa xác nhận hết quảng cáo âm thanh. Không thêm giải pháp giả như tắt tiếng quảng cáo rồi gọi là Premium.

Nguồn Redesigned hiện có giữ nguyên các thành phần thật, nhưng chưa tương đương toàn bộ Chroma 1.0.1. Hai hook morph cũ dùng lớp không có trong Spotify 9.1.90. Metadata chỉ cho thấy các animator mới; không đủ chứng minh chúng là adapter tương đương. Chưa đổi tên lớp hoặc giả hành vi chuyển cảnh. Các mục khác trong FEATURES-v7.md/PLAN-2026-11-09.vi.md vẫn còn phải làm.

Ambient và Sing bị loại theo yêu cầu; lyrics đồng bộ vẫn giữ. Bản mới cần build và thử iOS; artifact v6/v7 không được đổi tên thành v8.
