# Tạo keystore để ký APK release TimoKid. Chạy trên Windows (PowerShell).
#
# Cách dùng (mở PowerShell, chạy từ thư mục gốc của repo):
#   .\tools\android\create_keystore.ps1
#
# Script hỏi mật khẩu trực tiếp trong cửa sổ keytool (không ghi mật khẩu ra
# file hay lịch sử lệnh), rồi in mã base64 của keystore để anh nạp vào GitHub
# Secret ANDROID_KEYSTORE_BASE64. Các bước tiếp theo xem docs/RELEASE.md.
#
# Tham số:
#   -KeystorePath : đường dẫn file keystore sẽ tạo (mặc định: timokid-release.keystore trong thư mục hiện tại)
#   -Alias        : tên alias của key (mặc định: timokid)
#   -ValidityDays : số ngày keystore có hiệu lực (mặc định: 10000, ~27 năm)
#   -Force        : ghi đè file keystore đã có (mặc định: không ghi đè)
param(
    [string]$KeystorePath = ".\timokid-release.keystore",
    [string]$Alias = "timokid",
    [int]$ValidityDays = 10000,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# --- Tìm keytool -----------------------------------------------------------
function Find-Keytool {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += "$env:JAVA_HOME\bin\keytool.exe" }
    $candidates += "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    $candidates += "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe"
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

$keytool = Find-Keytool
if (-not $keytool) {
    Write-Error "Không tìm thấy keytool. Cài Android Studio (kèm JDK) rồi chạy lại, hoặc thêm thư mục bin của JDK vào PATH."
    exit 1
}
Write-Host "Dùng keytool: $keytool"

# --- Kiểm tra file đích -----------------------------------------------------
$keystoreFullPath = [System.IO.Path]::GetFullPath($KeystorePath)
if ((Test-Path $keystoreFullPath) -and (-not $Force)) {
    Write-Error "File đã có: $keystoreFullPath. Muốn tạo lại thì xóa file cũ hoặc chạy kèm -Force. CẢNH BÁO: keystore cũ mà mất thì không ký được bản cập nhật cho app đã phát hành bằng keystore đó."
    exit 1
}

# --- Tạo keystore (keytool tự hỏi mật khẩu, không lưu mật khẩu ở đâu cả) -----
Write-Host ""
Write-Host "keytool sẽ hỏi 2 mật khẩu (mật khẩu keystore, mật khẩu key) và thông tin chứng chỉ."
Write-Host "Ghi nhớ 2 mật khẩu này — sẽ cần để nạp GitHub Secrets ở bước sau."
Write-Host ""
& $keytool -genkeypair -v `
    -keystore $keystoreFullPath `
    -alias $Alias `
    -keyalg RSA -keysize 2048 `
    -validity $ValidityDays `
    -dname "CN=TimoKid, O=FBP Studio, C=VN"

if (-not (Test-Path $keystoreFullPath)) {
    Write-Error "Tạo keystore thất bại (không thấy file $keystoreFullPath)."
    exit 1
}

# --- In mã base64 để nạp secret ---------------------------------------------
$base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($keystoreFullPath))

Write-Host ""
Write-Host "=== XONG. Nạp 4 secrets vào repo (Settings > Secrets and variables > Actions) ==="
Write-Host "  ANDROID_KEYSTORE_BASE64  = (mã dài dưới đây, copy hết)"
Write-Host "  ANDROID_KEYSTORE_PASSWORD = mật khẩu keystore anh vừa nhập"
Write-Host "  ANDROID_KEY_ALIAS         = $Alias"
Write-Host "  ANDROID_KEY_PASSWORD      = mật khẩu key anh vừa nhập"
Write-Host ""
Write-Host $base64
Write-Host ""
Write-Host "GIỮ KÍN mã trên và 2 mật khẩu. Sao lưu file keystore ở nơi an toàn:"
Write-Host "  $keystoreFullPath"
Write-Host "Mất file này thì không ký được bản cập nhật cho app đã phát hành. Xóa nội dung màn hình sau khi copy xong (lệnh: Clear-Host)."
