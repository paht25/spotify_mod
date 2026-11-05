# Build phần lõi từ Windows

Mục tiêu đã ghi nhận: iOS 27, Spotify 9.1.90, inject vào IPA bằng Sideloadly. Bạn đã xác nhận quyền tích hợp Chroma để thử nghiệm riêng.

Workflow hiện tại biên dịch và chạy test cho mã lõi, pipeline phản hồi mạng, codec protobuf gốc của Chroma và bộ lọc feed gốc của Eevee đã gắn vào pipeline. Nó chưa build tweak hợp nhất hoặc tạo `.deb`. Artifact `.a` là thư viện tĩnh để liên kết vào tweak sau này, không thể inject bằng Sideloadly. Xem `TRANSPORT-INTEGRATION.md` để biết phần còn thiếu.

## Cách chạy

1. Tạo repository riêng tư trên GitHub.
2. Upload nội dung `cloud-build-kit.zip` vào gốc repository, giữ đúng các thư mục `.github/workflows`, `Sources`, `Tests`, `scripts`, `Licenses`. Với repository đã tạo, thay các file trùng bằng bản mới.
3. Commit vào nhánh mặc định của repository.
4. Mở Actions → Compile and test independent integration core → Run workflow.
5. Nếu job thành công, tải artifact. Nếu thất bại, giữ log lỗi để sửa mã hoặc cấu hình SDK. Không suy ra rằng các chức năng Spotify đã được kiểm thử từ kết quả job này.

Workflow dùng runner `xcode-27` trong danh mục GitHub, kiểm tra SDK thật rồi mới build. Chưa có lần chạy cloud nào được thực hiện trong phiên làm việc này. Repository riêng tư sử dụng quota/phút Actions của tài khoản của bạn; xem mức sử dụng tài khoản trước khi chạy.

Hướng dẫn GitHub: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow

## Phần còn phải triển khai để có `.deb` hợp nhất

- Chuyển logic chức năng từ hai mã nguồn sang hook có cùng chủ sở hữu; xử lý đặc biệt các callback mạng, lyrics, player và tab bar.
- Tích hợp settings, ánh xạ preference có kiểm chứng và giữ các lựa chọn giao diện riêng.
- Build Orion và EeveeSwiftProtobuf thật, xử lý tài nguyên theo app bundle cho quy trình inject vào IPA.
- Tạo một dylib có đầy đủ module đã tích hợp, rồi đóng gói `.deb` để Sideloadly sử dụng; kiểm tra kết quả inject thực tế.
- Test Spotify 9.1.90 trên thiết bị. Các phương thức/đường dẫn mà công cụ inject tự sửa phải được đối chiếu thực tế, không mặc định rằng cấu trúc rootless `/var/jb` có thể dùng nguyên trong IPA.

Không upload IPA, certificate, mật khẩu hoặc payload tham chiếu vào repository chỉ để chạy bài test core này; chúng không phải đầu vào của workflow.
