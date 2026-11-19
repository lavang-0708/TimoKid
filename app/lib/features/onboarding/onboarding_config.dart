/// Lựa chọn ở màn mở đầu (T2-03): giới tính, màu da, kiểu/màu tóc,
/// kiểu/màu mắt, kiểu miệng, váy (nữ bộ 1), tên, trứng.
///
/// Màu là giá trị ARGB (`Color.value`) để lưu gọn trong JSON hồ sơ.
/// Các kiểu (tóc/mắt/miệng) là mã manifest v1 (`assets/manifest.json`):
/// dáng nữ có 3 kiểu tóc, 3 kiểu mắt, 3 kiểu miệng; dáng nam vẽ sau
/// nên màn mở đầu tạm dùng chung bộ kiểu nữ cho xem trước (hình tạm,
/// xem `placeholder_layers.dart`).
///
/// Dáng nữ BỘ 1 (PR #18, chưa merge vào main lúc viết T2-03) chỉ còn
/// chọn màu tóc + váy: thân đã có sẵn mắt/miệng/giày/bộ đồ gốc nên
/// không chọn màu da, kiểu mắt, kiểu miệng; kiểu tóc cố định
/// `girl_hair_01`. Xem `onboardingGirlDresses` bên dưới.
library;

/// Độ dài tên tối đa (PLAN T2-03): 12 ký tự, không bắt buộc dấu.
const int onboardingMaxNameLength = 12;

/// Giới tính: `girl` (nữ) / `boy` (nam).
const List<String> onboardingGenders = <String>['girl', 'boy'];

/// Tên hiển thị của từng giới tính.
const Map<String, String> onboardingGenderNames = <String, String>{
  'girl': 'Bé gái',
  'boy': 'Bé trai',
};

/// 4 tông da cho bé chọn (màu nhân lên lớp thân xám).
const List<int> onboardingSkinColors = <int>[
  0xFFFFE3CE, // Sáng
  0xFFFFD9B0, // Vàng nhạt
  0xFFEFB98A, // Mật ong
  0xFFD99B6C, // Nâu nhạt
];

/// 5 màu tóc cho bé chọn (màu nhân lên lớp tóc xám).
const List<int> onboardingHairColors = <int>[
  0xFFFFB9D7, // Hồng
  0xFFA9715C, // Nâu
  0xFF3A3A44, // Đen
  0xFFF6C177, // Vàng
  0xFFA78BC9, // Tím
];

/// 4 màu mắt cho bé chọn (màu nhân lên lớp mắt xám).
const List<int> onboardingEyeColors = <int>[
  0xFF9B7EDE, // Tím
  0xFF35C4D8, // Xanh ngọc
  0xFF5B8DEF, // Xanh dương
  0xFF8B5E3C, // Nâu
];

/// Màu miệng cố định (PLAN chỉ cho chọn kiểu miệng, không chọn màu).
const int onboardingMouthColor = 0xFFE0787A;

/// 3 kiểu tóc dáng nữ trong manifest v1 (bộ `girl_hair_01..03`).
const List<String> onboardingHairStyles = <String>[
  'girl_hair_01',
  'girl_hair_02',
  'girl_hair_03',
];

/// Tên hiển thị của từng kiểu tóc (tạm: hình thật về sẽ có tên riêng).
const Map<String, String> onboardingHairStyleNames = <String, String>{
  'girl_hair_01': 'Kiểu 1',
  'girl_hair_02': 'Kiểu 2',
  'girl_hair_03': 'Kiểu 3',
};

/// 3 kiểu mắt dáng nữ trong manifest v1.
const List<String> onboardingEyeStyles = <String>[
  'girl_eyes_01',
  'girl_eyes_02',
  'girl_eyes_03',
];

/// Tên hiển thị của từng kiểu mắt (theo `name_vi` trong manifest).
const Map<String, String> onboardingEyeStyleNames = <String, String>{
  'girl_eyes_01': 'Mắt mi dài',
  'girl_eyes_02': 'Mắt mi dài 2',
  'girl_eyes_03': 'Mắt tròn',
};

/// 3 kiểu miệng dáng nữ trong manifest v1.
const List<String> onboardingMouthStyles = <String>[
  'girl_mouth_01',
  'girl_mouth_02',
  'girl_mouth_03',
];

/// Tên hiển thị của từng kiểu miệng (theo `name_vi` trong manifest).
const Map<String, String> onboardingMouthStyleNames = <String, String>{
  'girl_mouth_01': 'Miệng cười',
  'girl_mouth_02': 'Miệng cười hở',
  'girl_mouth_03': 'Miệng chữ O',
};

/// 3 lựa chọn váy cho dáng nữ bộ 1 (PR #18, `docs/ASSETS.md` mục
/// "Bộ nhân vật nữ 1"): null = mặc bộ đồ gốc trên thân (không chồng
/// lớp `top` nào); còn lại là mã manifest lớp `top` (màu thật,
/// không đổi màu được).
const List<String?> onboardingGirlDresses = <String?>[
  null,
  'girl_top_01',
  'girl_top_02',
];

/// Tên hiển thị của từng lựa chọn váy (theo `name_vi` trong manifest
/// của PR #18: "Váy hồng", "Váy tím").
const Map<String?, String> onboardingGirlDressNames = <String?, String>{
  null: 'Bộ đồ gốc',
  'girl_top_01': 'Váy hồng',
  'girl_top_02': 'Váy tím',
};

/// 3 loài trứng (DESIGN "Pet"): mã loài → tên hiển thị.
const Map<String, String> eggSpeciesNames = <String, String>{
  'dog': 'Chó Tinh Anh',
  'cat': 'Mèo Mũm Mĩm',
  'rabbit': 'Thỏ Bánh Bao',
};

/// Đường dẫn SVG trứng tạm của từng loài (xem `egg_assets.dart`).
const Map<String, String> eggSpeciesAssets = <String, String>{
  'dog': 'assets/temp/eggs/egg_dog.svg',
  'cat': 'assets/temp/eggs/egg_cat.svg',
  'rabbit': 'assets/temp/eggs/egg_rabbit.svg',
};

/// Đường dẫn SVG pet mới nở tạm của từng loài.
const Map<String, String> newbornSpeciesAssets = <String, String>{
  'dog': 'assets/temp/pets/dog_newborn.svg',
  'cat': 'assets/temp/pets/cat_newborn.svg',
  'rabbit': 'assets/temp/pets/rabbit_newborn.svg',
};

/// Cách gọi pet mới nở trong câu chào ở màn nở trứng.
const Map<String, String> newbornSpeciesNames = <String, String>{
  'dog': 'cún Tinh Anh',
  'cat': 'mèo Mũm Mĩm',
  'rabbit': 'thỏ Bánh Bao',
};
