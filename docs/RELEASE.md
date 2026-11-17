# Phát hành APK TimoKid

Mỗi lần gắn tag `v*` (ví dụ `v0.1.0`) lên `main`, workflow `.github/workflows/release.yml`
tự build APK release đã ký bằng keystore riêng và tạo GitHub Release kèm file APK.

## Chuẩn bị một lần: keystore và 4 secrets

### 1. Tạo keystore (máy Windows)

Mở PowerShell, chạy từ thư mục gốc của repo:

```powershell
.\tools\android\create_keystore.ps1
```

Script hỏi 2 mật khẩu (mật khẩu keystore, mật khẩu key) rồi in mã base64 của
keystore. **Ghi nhớ 2 mật khẩu** — script không lưu chúng ở đâu cả.

Nếu không chạy được script (chưa có keytool), cài Android Studio rồi chạy lại.

### 2. Nạp 4 secrets

Vào repo trên GitHub: **Settings > Secrets and variables > Actions > New repository secret**,
tạo 4 secrets:

| Secret | Giá trị |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Mã base64 mà script in ra (copy hết, một dòng dài) |
| `ANDROID_KEYSTORE_PASSWORD` | Mật khẩu keystore đã nhập ở bước 1 |
| `ANDROID_KEY_ALIAS` | `timokid` (alias mặc định của script) |
| `ANDROID_KEY_PASSWORD` | Mật khẩu key đã nhập ở bước 1 |

### 3. Sao lưu keystore

Copy file `timokid-release.keystore` ra nơi an toàn (ổ đĩa riêng, USB).
**Mất file này thì không ký được bản cập nhật cho app đã phát hành bằng
keystore này nữa.** Không commit file keystore hay `key.properties` lên repo
(cả hai đã có trong `.gitignore`).

## Phát hành một bản mới

1. Kiểm tra version trong `app/pubspec.yaml` (ví dụ `0.1.0+1`): `versionName`
   của APK lấy từ đó. Tag nên trùng số version, dạng `v0.1.0`.
2. Tạo tag và đẩy lên GitHub (Muse tạo tag khi Claude kết luận Đạt, hoặc tự tạo):
   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```
3. Chờ workflow `Release` chạy xong (tab **Actions** của repo), rồi vào
   **Releases** tải file `app-release.apk` về cài lên máy.

Bản thử đầu tiên sau khi nạp secrets sẽ dùng tag `v0.0.1`.

## Sự cố thường gặp

- **Thiếu secrets**: job dừng ngay với thông báo `Thiếu secrets ký APK: ...`.
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
