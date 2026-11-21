/// Ảnh nhân vật toàn thân (E, lô 1 + lô 2 của Muse, xem
/// `docs/E_IMAGES.md`).
///
/// Mỗi bé (gái/trai) có 3 bộ đồ, mỗi bộ 2 dáng (đứng nghỉ và vẫy tay),
/// khung 1024x1536, PNG trong suốt; chân ở y 1429 và người cao 1287 px
/// trong khung ở cả 12 ảnh. Mắt nhắm là một miếng vá đặt đè lên ảnh
/// (mỗi ảnh một rect riêng nếu đầu vẽ lệch), phụ kiện đầu là lớp phủ
/// cùng khung.
///
/// Trong app chỉ có MỘT nhân vật (bé chọn gái hoặc trai ở màn mở đầu).
/// Bộ đồ lưu ở `CharacterProfile.dress` (mã kết thúc bằng số bộ 1–3).
library;

import 'package:material_ui/material_ui.dart';

/// Khung ảnh nhân vật.
const double kidFrameWidth = 1024;
const double kidFrameHeight = 1536;

/// Chân nhân vật trong khung (y) và chiều cao người (px khung).
const double kidFeetY = 1429;
const double kidBodyHeight = 1287;

/// Tỉ lệ vị trí chân theo chiều cao khung (0..1).
const double kidFeetFraction = kidFeetY / kidFrameHeight;

/// Mã bộ đồ theo dáng, đúng thứ tự bộ 1–3.
const Map<String, List<String>> kidOutfitIds = <String, List<String>>{
  'girl': <String>['girl_top_01', 'girl_top_02', 'girl_top_03'],
  'boy': <String>['boy_outfit_01', 'boy_outfit_02', 'boy_outfit_03'],
};

/// Tên hiển thị của từng bộ đồ.
const Map<String, String> kidOutfitNames = <String, String>{
  'girl_top_01': 'Váy hồng',
  'girl_top_02': 'Váy tím',
  'girl_top_03': 'Váy hồng tạp dề',
  'boy_outfit_01': 'Áo xanh, quần short',
  'boy_outfit_02': 'Áo hoodie xanh lá',
  'boy_outfit_03': 'Áo đỏ, quần jean',
};

/// Phụ kiện đầu theo dáng: mã → (tên hiển thị, tên file không đuôi).
const Map<String, Map<String, (String, String)>> kidHeadAccessories =
    <String, Map<String, (String, String)>>{
      'girl': <String, (String, String)>{
        'hat': ('Mũ beret', 'girl_hat_01'),
        'bow': ('Nơ cài tóc', 'girl_bow_01'),
      },
      'boy': <String, (String, String)>{
        'hat': ('Mũ lưỡi trai', 'boy_hat_01'),
        'bow': ('Kẹp tóc ngôi sao', 'boy_clip_01'),
      },
    };

/// Dáng hợp lệ: `boy` hoặc `girl` (giá trị lạ coi như `girl`).
String kidGender(String gender) => gender == 'boy' ? 'boy' : 'girl';

/// Số bộ đồ 1–3 từ mã đã lưu (`girl_top_02` → 2). Null, mã lạ hoặc
/// số ngoài 1–3 thì về bộ 1 (máy cũ lưu `dress: null` = bộ đồ gốc).
int kidOutfitNumber(String? dress) {
  if (dress == null) return 1;
  final match = RegExp(r'(\d+)$').firstMatch(dress);
  final n = match == null ? 1 : int.parse(match.group(1)!);
  return (n >= 1 && n <= 3) ? n : 1;
}

/// Đường dẫn ảnh toàn thân. [backpack] = biến thể đeo balo (Muse vẽ
/// cả người đeo balo vì balo lớp rời không khớp người).
String kidFullAsset(
  String gender,
  int outfit, {
  bool wave = false,
  bool backpack = false,
}) {
  final g = kidGender(gender);
  return 'assets/images/character/$g/${g}_full_0$outfit'
      '${wave ? '_wave' : ''}${backpack ? '_backpack' : ''}.png';
}

/// Miếng vá mắt nhắm: đường dẫn + rect trong khung 1024x1536.
class KidEyePatch {
  const KidEyePatch(this.asset, this.rect);

  final String asset;
  final Rect rect;
}

/// Miếng vá mắt nhắm cho một ảnh. Bé gái: một patch dùng chung cả 6
/// ảnh (đã kiểm khít cả bản vẫy). Bé trai: patch chung cho 3 ảnh nghỉ,
/// mỗi ảnh vẫy một patch riêng (đầu vẽ lại lệch vài px).
KidEyePatch kidEyePatch(String gender, int outfit, {bool wave = false}) {
  if (kidGender(gender) == 'girl') {
    return const KidEyePatch(
      'assets/images/character/girl/girl_eyes_closed_patch.png',
      Rect.fromLTWH(300, 490, 410, 140),
    );
  }
  if (!wave) {
    return const KidEyePatch(
      'assets/images/character/boy/boy_eyes_closed_patch.png',
      Rect.fromLTWH(291, 506, 432, 205),
    );
  }
  const rects = <int, Rect>{
    1: Rect.fromLTWH(297, 493, 427, 245),
    2: Rect.fromLTWH(280, 502, 441, 243),
    3: Rect.fromLTWH(295, 495, 432, 250),
  };
  return KidEyePatch(
    'assets/images/character/boy/boy_eyes_closed_patch_0${outfit}_wave.png',
    rects[outfit]!,
  );
}

/// Đường dẫn lớp phụ kiện đầu (`hat`/`bow`), null nếu không có.
String? kidHeadAccessoryAsset(String gender, String? accessory) {
  if (accessory == null) return null;
  final g = kidGender(gender);
  final entry = kidHeadAccessories[g]![accessory];
  if (entry == null) return null;
  return 'assets/images/character/$g/${entry.$2}.png';
}

/// Dáng đã có khung đi bộ (lô 4 của Muse): cả bé gái và bé trai.
const Set<String> kidGendersWithWalkFrames = <String>{'boy', 'girl'};

/// 4 khung đi bộ (a–d) của một bộ đồ; [up] = đi lên (xa dần, `ur`),
/// ngược lại đi xuống/ngang (`dr`). Hướng phải; app lật ngang khi đi
/// sang trái. Null nếu dáng chưa có khung đi bộ.
List<String>? kidWalkFrames(String gender, int outfit, {required bool up}) {
  final g = kidGender(gender);
  if (!kidGendersWithWalkFrames.contains(g)) return null;
  final dir = up ? 'ur' : 'dr';
  return <String>[
    for (final f in const ['a', 'b', 'c', 'd'])
      'assets/images/character/$g/${g}_full_0${outfit}_walk_${dir}_$f.png',
  ];
}

/// Lớp phủ kính tròn (cùng khung, khớp ảnh đứng và vẫy).
String kidGlassesAsset(String gender) {
  final g = kidGender(gender);
  return 'assets/images/character/$g/${g}_glasses_01.png';
}

/// Lớp phủ giày trắng thay giày màu của bộ đồ (cùng khung).
String kidWhiteShoesAsset(String gender) {
  final g = kidGender(gender);
  return 'assets/images/character/$g/${g}_shoes_02.png';
}

/// Ảnh khung nhân vật 1024x1536 giải mã ở bề ngang [kidDecodeWidth]
/// (đủ nét cho nhân vật cao tới ~770 px vật lý) — nhỏ hơn 4 lần bộ nhớ
/// so với ảnh gốc. Dùng chung cho hiển thị và nạp trước để trùng khóa
/// bộ đệm ảnh.
ImageProvider<Object> kidImage(String asset) =>
    ResizeImage(AssetImage(asset), width: kidDecodeWidth);

/// Bề ngang giải mã ảnh khung nhân vật.
const int kidDecodeWidth = 512;
