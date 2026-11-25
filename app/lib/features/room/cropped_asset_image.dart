/// Hiện MỘT PHẦN của ảnh (hộp bao nhìn thấy) cho món nội thất lớn: sprite
/// 1024x1024 của lô 15 có viền trong suốt rất rộng, nên trong Phòng, ô
/// chọn biến thể và thẻ Cửa hàng chỉ vẽ phần [crop] (tỉ lệ 0..1) lấp đầy
/// hộp của widget (hộp cùng tỉ lệ với [crop] — xem [RoomArt]).
library;

import 'package:material_ui/material_ui.dart';

class CroppedAssetImage extends StatelessWidget {
  const CroppedAssetImage({
    super.key,
    required this.asset,
    required this.crop,
    this.errorBuilder,
  });

  final String asset;

  /// Phần ảnh được hiện (tỉ lệ 0..1 trên ảnh gốc).
  final Rect crop;

  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -crop.left / crop.width * w,
                top: -crop.top / crop.height * h,
                width: w / crop.width,
                height: h / crop.height,
                child: Image.asset(
                  asset,
                  fit: BoxFit.fill,
                  errorBuilder: errorBuilder,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
