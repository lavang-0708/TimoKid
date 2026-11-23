package vn.timokid.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

/// Vẽ Flutter bằng TextureView thay vì SurfaceView: trên máy tính bảng
/// (góp ý 22/11 và 24/11), khung đầu của SurfaceView giữ cỡ dọc khi cửa
/// sổ đã ngang nên màn chờ chỉ phủ một nửa, nửa còn lại trắng.
/// TextureView đổi cỡ theo cửa sổ ngay.
class MainActivity : FlutterActivity() {
    override fun getRenderMode(): RenderMode = RenderMode.texture
}
