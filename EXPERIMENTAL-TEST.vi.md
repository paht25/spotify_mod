# Bản thử hook feed cho Sideloadly

Đây là bước kiểm thử riêng bộ lọc feed, chưa phải bản hợp nhất đầy đủ Chroma + EeveeSpotify. Không có UI/theme, lyrics provider, Premium patching, SponsorBlock hay các module còn lại trong dylib này. Các phần đó vẫn nằm trong kế hoạch tích hợp, không được tuyên bố là đã hoàn thành.

## Build

Upload đè `Sources`, `Tests`, `scripts`, `tools`, `.github` và `Licenses` từ bộ kit mới vào repository riêng tư. Chạy workflow như lần trước. Workflow chỉ đóng gói sau khi các test mới và bước biên dịch thành công. File `.deb` chưa được build trên máy Windows hiện tại.

Nếu thành công, artifact `experimental-feed-only-Sideloadly-test` chứa:

- `UnifiedSpotifyExperimental.dylib`: dylib ARM64 thực, được build từ các nguồn mới và bộ lọc gốc Eevee.
- `UnifiedSpotify-FeedTest_0.1.0-test1.deb`: container để thử inject. Nó dùng bố cục Library/MobileSubstrate phổ biến cho payload tweak, không phải gói cài rootless đã được kiểm chứng. Không cài bằng package manager trên jailbreak từ hướng dẫn này.
- `package-manifest.json`: hash và danh sách file/mode trong package.
- `dependencies.txt`: dependency thực từ Mach-O sau khi link.

Dylib dùng Apple Foundation/Swift runtime, không yêu cầu Orion ở milestone feed độc lập này. Không có thư viện giả hoặc placeholder thay thế Orion.

## Kiểm tra bằng Sideloadly

1. Dùng một bản sao IPA Spotify 9.1.90 bạn có quyền sử dụng. Để thử độc lập, IPA đầu vào cần không chứa Chroma/Eevee đã inject sẵn; không cần thay đổi các thư mục payload gốc trên máy.
2. Inject dylib hoặc `.deb` qua chức năng tương ứng của phiên bản Sideloadly đang dùng, rồi ký/cài bằng tài khoản và cấu hình của bạn. Không cần chia sẻ chứng chỉ hay mật khẩu với tôi.
3. Mở Spotify: ghi nhận có khởi động được không, Home/feed có tải được không, nội dung thường còn hiển thị không và nhạc có phát được không.
4. Nếu crash hoặc treo, giữ crash log và log có tiền tố `[UnifiedSpotify]`, cùng thông tin iOS/Spotify và cách tái hiện.
5. Không coi test thành công là xác nhận chức năng của toàn bộ hai tweak. Không inject artifact `.a`.

Bootstrap chỉ kích hoạt khi executable tên Spotify và version là 9.1.90. Nếu phát hiện dylib gốc tên spotifyglass.dylib hoặc EeveeSpotify.dylib đang nạp, nó sẽ bỏ qua hook để tránh thử đồng thời hai bộ hook. Việc đổi tên dylib gốc để vượt kiểm tra không phải cấu hình được hỗ trợ.

## Hành vi và giới hạn

- Ba callback response/data/completion được kiểm tra type encoding trước khi thay thế. Class thiếu selector, method kế thừa hoặc đã có owner trong registry bị từ chối.
- Chỉ phản hồi HTTP 200 từ domain Spotify thuộc browsita/casita/scrollsita phù hợp mới được buffer; endpoint casita feeds bị loại trừ như thuật toán gốc.
- Giữ quyết định allow/cancel của delegate gốc. Buffer thuộc task object, không dùng taskIdentifier chung giữa các session. Tối đa 8 MB; khi vượt giới hạn, phát lại nguyên các byte đã buffer rồi chuyển sang passthrough.
- Xử lý ở worker queue; phát lại body/completion trong một operation trên chính delegateQueue của session. Response header đã được delegate gốc nhận trước khi transform; bản thử không gửi response lần hai. Đây là hạn chế cần kiểm tra đối với consumer đọc Content-Length.
- Chưa hỗ trợ biến đổi header sớm, 304 tổng hợp, donor lyrics, retry sau khi class chưa được đăng ký, hay mọi nguồn swizzle bên ngoài. Nếu hook kích hoạt một phần do runtime bị thay đổi đồng thời, log sẽ yêu cầu dừng bản thử. Chưa có cơ chế hot-uninstall hook; muốn bỏ bản thử phải ký/cài lại IPA không có dylib này.
- Test delegate mới dùng NSURLSessionTask thực nhưng không resume request; nó kiểm tra hook gọi thuật toán thật, passthrough, cancellation và buffer overflow. Nó không thay thế test trong Spotify.

Trạng thái hiện tại: mã hook/packager đã viết, chưa chạy bộ test mới hoặc build dylib trên Apple toolchain trong phiên này, chưa tạo `.deb` và chưa test trên thiết bị.
