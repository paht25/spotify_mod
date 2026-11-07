# Build v6 cho Spotify 9.1.90

Hướng dẫn đầy đủ: [PERSONAL-v6.vi.md](PERSONAL-v6.vi.md).

1. Giải nén `personal-v6-9190-source.zip`, upload nội dung vào root repo private đang dùng, bao gồm `.github`, `Integration`, `Sources`, `Tests`, `scripts`, `tools`, `Resources`, `Generated` và hướng dẫn. Không upload IPA Spotify.
2. Thay các tệp cùng đường dẫn bằng bản mới và commit trong một lần. Không ghép nội dung YAML/Swift cũ với bản mới.
3. Actions → **Chroma source integration - v6-9190** → Run workflow → `main`. Chạy trên commit mới; Re-run job cũ dùng mã cũ.
4. Sau khi tất cả bước thành công, tải artifact **personal-v6-9190-Sideloadly-test**.
5. Theo hướng dẫn assembly tạo IPA mới có extension rồi ký bằng Sideloadly. Không inject thêm cùng `.deb`/dylib vào IPA đã assembly.

Bộ ZIP hiện tại là mã nguồn; kiểm tra Apple và quảng cáo âm thanh trên thiết bị chưa có kết quả cho v6.
