# Phát hành APK TimoKid

Mỗi lần gắn tag `v*` (ví dụ `v0.1.0`) lên `main`, workflow `.github/workflows/release.yml`
tự build APK release đã ký bằng keystore riêng và tạo GitHub Release kèm file APK.

## Chuẩn bị một lần: keystore và 4 secrets

### 1. Tạo keystore (máy Windows)

Cần Java. Nếu chưa có thì cài bằng PowerShell: `winget install Microsoft.OpenJDK.17`.

Mở thư mục sẽ chứa keystore (để **ngoài** repo, ví dụ `D:\Work\TimoKid\keystore`),
chuột phải chọn **Open in Terminal**, rồi chạy (một dòng, Enter xong mới nhập mật khẩu):

```powershell
& "C:\Program Files\Microsoft\jdk-17.0.21.102-hotspot\bin\keytool.exe" -genkeypair -v -keystore timokid-release.keystore -alias timokid -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=TimoKid, C=VN"
```

(Đường dẫn `jdk-17...` có thể khác số phiên bản; vừa cài xong thì mở cửa sổ mới là gõ `keytool` được.)

keytool hỏi **một** mật khẩu (nhập 2 lần). Keystore kiểu PKCS12 dùng chung mật khẩu
này cho cả keystore và key. Thấy `[Storing timokid-release.keystore]` là xong.

Chép mã base64 của keystore vào clipboard:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\timokid-release.keystore")) | Set-Clipboard
```

Script `tools/android/create_keystore.ps1` làm cùng việc trên nếu chạy từ repo.

### 2. Nạp 4 secrets

Vào repo trên GitHub: **Settings > Secrets and variables > Actions > New repository secret**,
tạo 4 secrets (tên phải đúng từng chữ):

| Secret | Giá trị |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Mã base64 vừa chép (Ctrl+V, một dòng dài khoảng 3.000 ký tự) |
| `ANDROID_KEYSTORE_PASSWORD` | Mật khẩu đã nhập ở bước 1 |
| `ANDROID_KEY_ALIAS` | `timokid` |
| `ANDROID_KEY_PASSWORD` | **Cùng** mật khẩu ở bước 1 |

### 3. Sao lưu keystore

Copy file `timokid-release.keystore` ra nơi an toàn (ổ đĩa riêng, USB).
**Mất file này thì không ký được bản cập nhật cho app đã phát hành bằng
keystore này nữa.** Không commit file keystore hay `key.properties` lên repo
(cả hai đã có trong `.gitignore`).

## Phát hành một bản mới

1. Kiểm tra version trong `app/pubspec.yaml` (ví dụ `0.1.0+1`): `versionName`
   của APK lấy từ đó. Tag nên trùng số version, dạng `v0.1.0`.
2. Tạo tag: trên GitHub vào **Releases > Draft a new release**, ô **Tag** gõ `v0.1.0`
   rồi chọn **Create new tag on publish**, Target `main`, bấm **Publish release**
   (bản thử thì tích **Set as a pre-release**). Hoặc dùng git:
   `git tag v0.1.0 && git push origin v0.1.0`. Claude không tạo tag được (proxy chặn).
3. Chờ workflow `Release` chạy xong (tab **Actions** của repo), rồi vào
   **Releases** tải file `TimoKid-vX.Y.Z.apk` về cài lên máy.

Bản thử đầu tiên sau khi nạp secrets sẽ dùng tag `v0.0.1`.

## Sự cố thường gặp

- **Thiếu secrets**: job dừng ngay với thông báo `Thiếu secrets ký APK: ...`
  (thường do gõ sai tên secret). Sửa secret rồi bấm **Re-run all jobs** trên lần chạy lỗi,
  không cần tạo lại tag.
  Nạp đủ 4 secrets rồi gắn tag lại (xóa tag cũ: `git tag -d vX.Y.Z` rồi
  `git push origin :vX.Y.Z`, sau đó tạo lại tag).
- **Sai alias hoặc mật khẩu**: bước build lỗi, kiểm tra lại giá trị 4 secrets.
- **Tag đã tồn tại**: GitHub không chạy lại workflow cho tag cũ. Xóa tag cũ
  như trên rồi tạo lại.
- **Muốn đổi keystore**: tạo keystore mới và cập nhật lại 4 secrets. Lưu ý
  app đã cài từ keystore cũ không cập nhật được bằng APK ký keystore mới
  (Android coi là app khác).

## Bản debug (không cần keystore)

Mỗi PR và mỗi lần push lên `main` đều build sẵn APK debug, tải ở tab
**Actions** > lần chạy CI > **Artifacts** > `timokid-debug-apk`.
APK debug chỉ để kiểm thử, không phát hành cho người dùng.


## Bản thử và bản chính thức (24/11/2026)

- Tag dạng `v0.0.x` là **bản thử**: workflow build với
  `--dart-define=TEST_UNLOCKS=true --dart-define=QA_MENU=true`. App mở hết
  tính năng (không cần xong đề ngày), tặng 10.000 xu + 10.000 kim cương một
  lần (nạp lại khi dưới 1.000), có menu QA (đặt mốc pet, tua ngày…) và nhãn
  "BẢN THỬ" ở góc Thị trấn.
- Từ `v0.2.0` trở đi là bản chính thức: build không cờ, mọi luật như cũ.
- Cờ nằm ở `app/lib/core/test_build.dart`; mọi chỗ khóa hỏi
  `TestUnlocks.enabled`.
