/// Trang trí màn làm toán sinh động (T1-15, PLAN điểm (m)).
///
/// Màu nền theo mảng, họa tiết SVG nhẹ, pet mèo SVG và các màu chữ/
/// băng phản hồi đã chốt. Pet vẽ mới cùng phong cách pastel mềm,
/// viền trắng kiểu sticker của các tấm trong `assets/concept/`
/// (PLAN điểm (k)): Muse không tải được PNG nhị phân qua MCP nên
/// không cắt được pet từ tấm `pet_*.png`; pet SVG ở đây vẽ theo đúng
/// tông đó (mèo Mũm Mĩm — phần thú cưng trong tấm nhân vật nữ chỉ có
/// mèo, xem `assets/concept/README.md`).
///
/// Họa tiết và pet là chuỗi SVG nội tuyến (không phải file asset) để
/// không cần khai báo pubspec và test nào cũng vẽ được.
library;

import 'package:material_ui/material_ui.dart';

/// Màu của màn làm toán sinh động (PLAN điểm (m)).
class MathColors {
  MathColors._();

  /// Chữ đề chính trên thẻ trắng.
  static const Color questionText = Color(0xFF3B2E5A);

  /// Dòng tiếng Anh dưới đề (chữ phụ, nhạt hơn).
  static const Color englishText = Color(0xFF8A7FA6);

  /// Số trên nút đáp án.
  static const Color buttonNumber = Color(0xFF4B2E83);

  /// Nút bị vô hiệu: pastel rất nhạt (xám pha tím nhạt).
  /// Mặc định của theme là `onSurface` mờ 12% — trên viền đào của
  /// nút nổi nó thành nâu đất trông bẩn (review PR #14). Chữ số
  /// trên nút vẫn giữ màu tím đậm nên vẫn đọc được (tương phản
  /// khóa trong `math_contrast_test.dart`).
  static const Color disabledButtonBg = Color(0xFFF2EEF7);

  /// Băng phản hồi đúng: nền xanh nhạt, viền xanh, chữ xanh đậm.
  static const Color bannerGreenBg = Color(0xFFE3F7E6);
  static const Color bannerGreenBorder = Color(0xFF43A047);
  static const Color bannerGreenText = Color(0xFF1B5E20);

  /// Băng phản hồi sai lần đầu: nền cam nhạt, viền cam, chữ cam đậm
  /// (không dùng đỏ gắt).
  static const Color bannerOrangeBg = Color(0xFFFFF3E0);
  static const Color bannerOrangeBorder = Color(0xFFF57C00);
  static const Color bannerOrangeText = Color(0xFFBF360C);

  /// Băng lời giải sau sai hai lần: nền xanh dương nhạt, viền xanh
  /// dương, chữ xanh đậm (cùng tông với hộp lời giải cũ ở T1-09).
  static const Color bannerBlueBg = Color(0xFFE3F2FD);
  static const Color bannerBlueBorder = Color(0xFF1976D2);
  static const Color bannerBlueText = Color(0xFF0D47A1);

  /// Đồng xu trong ô vàng của băng "Đúng rồi!".
  static const Color coinYellow = Color(0xFFFFD166);
  static const Color coinYellowDark = Color(0xFFE8A93D);

  /// Thanh tiến độ 5 ô: ô đã xong, ô hiện tại, ô chưa làm.
  static const Color progressDone = Color(0xFF43A047);
  static const Color progressCurrent = Color(0xFF4B2E83);
  static const Color progressUpcomingBorder = Color(0xFFD8D2E0);

  /// Nền màn theo mảng: tông pastel nhạt dần từ màu khu của Thị trấn
  /// (xem `TownArea.color`), đủ nhạt để thẻ trắng nổi hẳn lên.
  static Color strandBackground(String strand) {
    switch (strand) {
      case 'logic':
        return const Color(0xFFE9E2FA);
      case 'arith':
        return const Color(0xFFFFEAD9);
      case 'number':
        return const Color(0xFFDFEFFC);
      case 'geo':
        return const Color(0xFFE0F2E6);
      case 'comb':
        return const Color(0xFFFFF0BE);
      default:
        return const Color(0xFFFFF6E8);
    }
  }
}

/// Họa tiết nền nhẹ: một ô 120x120 gồm sao, chấm, dấu cộng và vòng
/// tròn trắng. Màn hình lát ô này thành lưới, mờ đi (opacity ~0.5)
/// trên nền pastel theo mảng.
const String mathPatternSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">
  <g fill="#FFFFFF">
    <path d="M30,16 L33.5,25.5 L43,29 L33.5,32.5 L30,42 L26.5,32.5 L17,29 L26.5,25.5 Z" />
    <circle cx="92" cy="24" r="5" />
    <circle cx="62" cy="58" r="3" />
  </g>
  <g stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" fill="none">
    <path d="M82,76 L82,94 M73,85 L91,85" />
    <circle cx="26" cy="92" r="7" stroke-width="3" />
  </g>
</svg>
''';

/// Mặt mèo Mũm Mĩm (pet góc màn). Hai biểu cảm dùng chung tai, mặt,
/// râu và má hồng; chỉ khác mắt, miệng và giọt mồ hôi.
String _catFace({
  required String eyes,
  required String mouth,
  String extra = '',
}) {
  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">
  <g stroke="#FFFFFF" stroke-width="5" stroke-linejoin="round">
    <path d="M26,46 L32,12 L58,34 Z" fill="#FFF3DC" />
    <path d="M94,46 L88,12 L62,34 Z" fill="#FFF3DC" />
    <path d="M33,38 L36,22 L50,32 Z" fill="#FFB3C1" stroke="none" />
    <path d="M87,38 L84,22 L70,32 Z" fill="#FFB3C1" stroke="none" />
  </g>
  <circle cx="60" cy="68" r="38" fill="#FFF3DC" stroke="#FFFFFF" stroke-width="6" />
  <g stroke="#D8D2E0" stroke-width="2.5" stroke-linecap="round">
    <path d="M18,72 L36,74" />
    <path d="M18,82 L36,80" />
    <path d="M102,72 L84,74" />
    <path d="M102,82 L84,80" />
  </g>
  <ellipse cx="36" cy="78" rx="6" ry="4" fill="#FFB3C1" opacity="0.7" />
  <ellipse cx="84" cy="78" rx="6" ry="4" fill="#FFB3C1" opacity="0.7" />
  $eyes
  <path d="M56,74 L64,74 L60,80 Z" fill="#FF8A7A" />
  $mouth
  $extra
</svg>
''';
}

/// Pet vui khi đúng (mắt cười cong, miệng cười).
String get petCatHappySvg => _catFace(
  eyes: '''
  <g stroke="#3B2E5A" stroke-width="4" stroke-linecap="round" fill="none">
    <path d="M38,64 Q46,56 54,64" />
    <path d="M66,64 Q74,56 82,64" />
  </g>
  ''',
  mouth: '''
  <g stroke="#3B2E5A" stroke-width="3.5" stroke-linecap="round" fill="none">
    <path d="M60,80 Q60,86 54,86" />
    <path d="M60,80 Q60,86 66,86" />
  </g>
  ''',
);

/// Pet động viên khi sai (mắt tròn hiền, miệng cười nhẹ, giọt mồ hôi).
String get petCatEncouragingSvg => _catFace(
  eyes: '''
  <g fill="#3B2E5A">
    <circle cx="46" cy="62" r="4" />
    <circle cx="74" cy="62" r="4" />
  </g>
  ''',
  mouth: '''
  <path d="M50,82 Q60,90 70,82" stroke="#3B2E5A" stroke-width="3.5"
    stroke-linecap="round" fill="none" />
  ''',
  extra: '''
  <path d="M94,28 Q100,40 94,46 Q88,40 94,28 Z" fill="#7FB3D5" />
  ''',
);
