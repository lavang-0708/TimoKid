/// Widget vẽ nhân vật theo lớp (T2-02).
///
/// Chồng các lớp của [CharacterOutfit] theo z trong `manifest.json`,
/// tô màu lớp xám bằng phép nhân màu (multiply) rồi đặt lớp `_line`
/// lên trên lớp gốc. Dùng chung cho màn tạo nhân vật (T2-03), phòng
/// (T2-04) và tủ đồ (T2-05).
///
/// Hiệu ứng: thở nhẹ (toàn nhân vật phồng lên ~1,5% rồi xẹp, quanh
/// chân để chân không rời mặt đất) và chớp mắt (chỉ lớp mắt + viền
/// mắt co dọc trong ~0,3 giây, mỗi chu kỳ ~3,4 giây). Cả hai đều là
/// `Transform` rẻ trên GPU; ảnh mỗi lớp chỉ giải mã một lần rồi nằm
/// trong `ImageCache`, nên mỗi khung hình không làm lại việc nặng —
/// thiết kế để vẽ đủ lớp dưới 16 ms trên máy ảo tầm trung (chưa đo
/// trực tiếp ở local vì không có máy ảo; kiểm lại ở T2-09).
///
/// Bộ nạp lớp [loader] chèn được: mặc định `AssetImage` theo đường
/// dẫn trong manifest; trong test chèn `MemoryImage` từ fixture
/// nhúng base64 (xem `test/features/character/character_fixtures.dart`).
/// Khi hình thật về, chỉ cần thay file tại đúng đường dẫn manifest,
/// không sửa code. Lớp nào tải lỗi (thiếu file) thì bỏ qua lớp đó
/// thay vì vỡ cả nhân vật.
library;

import 'package:material_ui/material_ui.dart';

import 'character_model.dart';

/// Nạp một lớp thành [ImageProvider] từ đường dẫn asset.
/// Mặc định: [AssetImage]; test chèn `MemoryImage` từ fixture.
typedef CharacterLayerLoader = ImageProvider Function(String assetPath);

/// Nhân màu lên lớp xám bằng color matrix: R'=R*tr, G'=G*tg,
/// B'=B*tb, A'=A (tr/tg/tb là kênh màu tint chia 255).
///
/// KHÔNG dùng `ColorFilter.mode(màu, BlendMode.multiply)`: theo công
/// thức blend W3C, multiply với màu đặc sẽ lấp cả vùng trong suốt
/// bằng màu tint (đã kiểm chứng: nền khung thành màu đặc, chỉ còn
/// lớp trên cùng hiện hình). Matrix nhân đúng kênh màu mà giữ nguyên
/// alpha nên vùng trong suốt vẫn trong suốt, xám sáng ra đúng màu
/// tint còn xám đậm (bóng đổ) ra màu tint đậm hơn.
ColorFilter _multiplyTint(Color tint) => ColorFilter.matrix(<double>[
  tint.r,
  0,
  0,
  0,
  0,
  0,
  tint.g,
  0,
  0,
  0,
  0,
  0,
  tint.b,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

/// x = 0, y = (480 / 1536) * 2 - 1 = -0.375. Chớp mắt co dọc quanh
/// điểm này để mắt không bị lệch khi nhắm.
const _eyeCenter = Alignment(0.0, -0.375);

/// Widget vẽ một nhân vật theo bộ phối đồ [outfit].
class CharacterView extends StatefulWidget {
  const CharacterView({
    super.key,
    required this.outfit,
    this.loader,
    this.animationsEnabled = true,
    this.width,
  });

  /// Bộ phối đồ (danh sách lớp đã xếp theo z).
  final CharacterOutfit outfit;

  /// Bộ nạp lớp; null = `AssetImage` theo đường dẫn manifest.
  final CharacterLayerLoader? loader;

  /// Bật hiệu ứng thở + chớp mắt. Tắt trong golden test để ảnh
  /// chụp xác định (không phụ thuộc thời điểm chụp).
  final bool animationsEnabled;

  /// Chiều rộng hiển thị; null = rộng hết chỗ cha. Chiều cao suy ra
  /// theo tỉ lệ khung 1024:1536.
  final double? width;

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView>
    with TickerProviderStateMixin {
  AnimationController? _breathController;
  AnimationController? _blinkController;
  late final Animation<double> _breathScale;
  late final Animation<double> _blinkScaleY;

  @override
  void initState() {
    super.initState();
    if (!widget.animationsEnabled) return;
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _breathScale = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _breathController!, curve: Curves.easeInOut),
    );
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
    // Nhắm mắt chỉ chiếm ~10% cuối chu kỳ: mở 90%, khép 5%, mở 5%.
    _blinkScaleY = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 90),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.08), weight: 5),
      TweenSequenceItem(tween: Tween<double>(begin: 0.08, end: 1.0), weight: 5),
    ]).animate(_blinkController!);
  }

  @override
  void dispose() {
    _breathController?.dispose();
    _blinkController?.dispose();
    super.dispose();
  }

  ImageProvider _load(String assetPath) =>
      widget.loader?.call(assetPath) ?? AssetImage(assetPath);

  /// Một lớp thành widget ảnh; lớp đổi màu thì nhân màu lên trên.
  /// Bộ nạp lỗi (đồng bộ) hoặc file lỗi thì bỏ qua lớp đó.
  Widget _layerImage(CharacterLayerSpec spec) {
    final key = Key('character-layer-${spec.id}');
    ImageProvider imageProvider;
    try {
      imageProvider = _load(spec.assetPath);
    } catch (_) {
      return SizedBox.shrink(key: key);
    }
    final image = Image(
      key: key,
      image: imageProvider,
      fit: BoxFit.contain,
      // Thiếu file thì bỏ qua lớp đó, không vỡ cả nhân vật.
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    if (spec.tint == null) return image;
    return ColorFiltered(colorFilter: _multiplyTint(spec.tint!), child: image);
  }

  /// Bọc chớp mắt quanh một widget (chỉ dùng cho nhóm mắt).
  Widget _blinkWrap(Widget child) {
    if (!widget.animationsEnabled) return child;
    return AnimatedBuilder(
      animation: _blinkScaleY,
      builder: (context, child) => Transform.scale(
        key: const Key('character-blink'),
        scaleY: _blinkScaleY.value,
        alignment: _eyeCenter,
        child: child,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final layers = widget.outfit.layers;
    final children = <Widget>[];
    var i = 0;
    while (i < layers.length) {
      final spec = layers[i];
      if (spec.layer == 'eyes') {
        // Mắt + viền mắt chớp cùng nhau để không lệch nhau khi nhắm.
        final group = <Widget>[_layerImage(spec)];
        if (i + 1 < layers.length &&
            layers[i + 1].isLine &&
            layers[i + 1].layer == 'eyes') {
          group.add(_layerImage(layers[i + 1]));
          i++;
        }
        children.add(_blinkWrap(Stack(children: group)));
        i++;
        continue;
      }
      children.add(_layerImage(spec));
      i++;
    }

    Widget stack = Stack(children: children);
    if (widget.animationsEnabled) {
      stack = AnimatedBuilder(
        animation: _breathScale,
        builder: (context, child) => Transform.scale(
          key: const Key('character-breath'),
          scale: _breathScale.value,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
        child: stack,
      );
    }

    return SizedBox(
      key: const Key('character-view'),
      width: widget.width,
      child: AspectRatio(aspectRatio: 1024 / 1536, child: stack),
    );
  }
}
