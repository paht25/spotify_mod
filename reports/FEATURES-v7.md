# Phạm vi và đối chiếu tính năng

Yêu cầu hiện tại: toàn bộ nhóm tính năng quan sát được trong Chroma 1.0.1, gồm player, Liquid Glass Redesigned, NavBar, các trang nội dung, lyrics và màn hình khóa; **loại ambient và Sing/tách giọng**, **giữ lyrics đồng bộ**. Mục tiêu chưa hoàn thành.

Đã đọc IPA và Debian mới trong thư mục phân tích riêng, không sửa tệp gốc. IPA dùng Spotify 9.1.90 build 919002269, chứa bốn dylib Chroma/AppGroups/AutoMix và Live Activity; không có source `.m/.x/.swift`. Metadata giải mã được 626 lớp Objective-C và 485 literal mang tiền tố cấu hình. Các literal bao gồm cả cache, notification và trạng thái nội bộ; chúng không phải 485 tính năng đã xác nhận. [Inventory JSON](feature-inventory-v7.json) giữ từng literal trong 29 nhóm bằng chứng, kể cả hai nhóm loại theo yêu cầu. Hành vi ẩn/dynamic và phân loại Plus/free chưa được xác minh hết.

Điểm đính chính: public ref `v0.51.0` và `main` đều trỏ tới `425d68bc1761e90a6b5828864720511bcef79fa9`; `version.txt` và changelog tự khai 0.22.0. Không tìm thấy ref `v1.0.1` hoặc `1.0.1` qua các kiểm tra đã thực hiện. Vì vậy không được gọi nguồn nền là bản đầy đủ 0.51.0/1.0.1. Bản v6 đã build được không chứng minh điều ngược lại. Nguồn được kiểm tra tại [ref công khai](https://github.com/skopevoj/spoti.pw/blob/v0.51.0/version.txt); website hiện mô tả các nhóm tính năng mới nhưng không cung cấp đặc tả đầy đủ cho từng hành vi. [Chroma](https://chroma.pw/).

| Nhóm | Trạng thái nhánh mới |
|---|---|
| Player: cover, nền, controls, scrubber, menu, artwork | Giữ mã nền cũ; chưa tái tạo đủ bố cục/tùy chọn player 1.0.1 |
| Liquid Glass Redesigned, native look, accent, AMOLED | Giữ hai renderer/namespace riêng; cần xác nhận 9.1.90; chưa đủ appearance/page-look options mới |
| NavBar, tab editor, custom URI/icon | Mã nền có mặt; inline mini-player và các tùy chọn 1.0.1 chưa đủ |
| Home, Search, Library, playlist, album, artist | Mã nền có mặt; hero/top picks, logo/motion, notes/play counts và các chi tiết mới còn thiếu |
| Chuyển cảnh player/mini-player | Lớp Spotify cũ vắng trên 9.1.90; adapter mới chưa có, không đổi tên lớp để đoán |
| Lyrics line/word sync, pronunciation, translation có sẵn, meanings | Giữ pipeline nguồn/timing/render hiện có; không phải Sing/tách giọng; provider mới, chữ-shader và tùy chọn mở rộng còn thiếu |
| Lyrics ngang màn hình / phong cách chữ mới | Chưa có parity 1.0.1 |
| Lock-screen lyrics/artwork và Live Activity | Giữ mã/extension nguồn nền; CSS style engine và các style mới chưa có; ký/device còn phải thử |
| Visualizer/audio-reactive background | Mã độc lập mới: tap chỉ đọc output, FFT thực, Spectrum/Orbit/Wave, nhập MSL, sensitivity; C core đã qua test, Metal/UIKit chưa chạy |
| Workshop | Mã độc lập mới nhập/xóa/áp shader, font, audio preset, GraphicEQ cục bộ; gallery online/favorites/editor/community backend chưa có |
| Font toàn app | Đăng ký CoreText và thay UIFont APIs được hỗ trợ; cần build/device, không tuyên bố thay được mọi text renderer |
| DSP, speed/pitch, headphone EQ | Giữ engine thật; nối preset/EQ importer mới; per-output/per-song options mới còn thiếu |
| Web Player/TV | Mã độc lập mới cho Wi-Fi riêng, bìa/lyrics đồng bộ/controls tùy chọn; không truyền nhạc; relay Internet/shader/layout parity còn thiếu |
| Gestures, haptics | Giữ controls/music haptics và tap zones nền; head gestures, hold, shortcuts/latency extensions chưa đủ |
| AutoMix | Có bằng chứng hai adapter private SonicKit trong IPA; chưa có adapter độc lập. Không coi crossfade hiện có là AutoMix |
| Local-file metadata library, stats/history | Chưa tái tạo |
| Custom translation/Gemini service | Translation từ provider hiện có vẫn giữ; dịch vụ thay thế với key người dùng chưa có |
| Ambient | Đã gỡ mã phát/điều khiển/import audio ambient vừa thêm; loại theo yêu cầu |
| Sing/vocal separation/spatial voice của Sing | Không triển khai/không bật; loại theo yêu cầu; không cần mô hình tách giọng trong phạm vi mới |
| Đăng nhập | Spotify giữ nguyên. Mô-đun mới không có tài khoản Chroma, không sửa binary Plus hay giả quyền truy cập backend |
| Quảng bá tác giả | Các module donate/update/usage của nền đã loại khỏi build; giấy phép/ghi công giữ lại |

## Eevee và tránh xung đột

Nguồn 6.6.8 đúng tag/commit `0d846646922231d5367e1625764835826f807e5d` đã lấy để đối chiếu. Bốn model/helper đang dùng giống nội dung 6.6.8; một số account/feed fixes từ nhánh 7 đã được giữ vì không nên lùi bản lọc đang có. Đây không phải lời khẳng định đã port trọn mọi tính năng 6.6.8.

Debian 6.6.8 là layout rootless `/var/jb`, cần Orion và EeveeSwiftProtobuf; Orion không có trong hai tệp mới. Không tạo framework rỗng. Nguồn tích hợp đã port các module chọn lọc sang registry/bridge nên không cần nạp binary Eevee gốc. Chroma 1.0.1 cũng chỉ được dùng làm đối chiếu. Mạng chỉ có một collector/completion owner; giao diện dùng một renderer theo profile. [Danh sách shared-target](shared-target-candidates-v7.json) có 11 tệp Eevee với target trùng dạng literal/alias; đây là ứng viên cần kiểm tra selector/ABI/runtime, không phải 11 lỗi đã tái hiện.

Phần Eevee đang có: account/config transforms, lọc feed, ad-service policy, ad product-state policy, true shuffle/crossfade/sharing utilities đã có từ nền. Chặn quảng cáo âm thanh, session behavior, UI, extra lyrics và SponsorBlock vẫn chưa có xác nhận đầy đủ trên thiết bị. Không giả kết quả thử nghiệm hoặc trộn hai binary rồi gọi là đã hòa giải.
