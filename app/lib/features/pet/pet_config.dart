/// Cấu hình pet (D, spec 23/11): MỌI con số và cờ hình của phần chăm
/// pet nằm ở file này (một chỗ duy nhất) để chủ dự án chỉnh sau.
///
/// - Ngưỡng lớn: số câu đúng ngay lần đầu tích lũy khi pet đi theo.
/// - Giá trứng pet mua bằng kim cương + độ hiếm.
/// - Cờ hình: `petUiArtReady` (emoji/bong bóng/suất ăn), `newPetArtReady`
///   (hình từng loài mới; chưa có thì loài đó "Sắp có", không mua được).
library;

/// Số câu đúng ngay lần đầu để lên tuổi nhỡ / trưởng thành.
const int petTeenXp = 80;
const int petAdultXp = 250;

/// Máy cũ chuyển sang bảng `pets`: xp khởi điểm = số ngày xong đề × số này
/// (nhưng không thấp hơn ngưỡng của giai đoạn bé đã đạt, để không tụt).
const int petMigrationXpPerDay = 20;

/// Ngày cũ (T2-07 F): ngưỡng số ngày xong đề của luật cũ, chỉ dùng khi
/// chuyển dữ liệu (migration v3 → v4).
const int legacyPetTeenDays = 3;
const int legacyPetAdultDays = 8;

/// Mỗi ngày pet cần bao nhiêu lần ăn / chơi để vui.
const int petFeedsPerDay = 1;
const int petPlaysPerDay = 1;

/// Số suất ăn nhận cho mỗi chặng xong (chặng ngày, tầng tháp, đấu trường).
const int petMealsPerStage = 1;

/// "Vuốt ve" chỉ tính khi bé xong ít nhất bấy nhiêu chặng hôm nay.
const int petPatMinStagesToday = 1;

/// Mã suất ăn (món miễn phí trong kho thức ăn, khóa
/// `pet_food_count.meal`).
const String petMealId = 'meal';
const String petMealName = 'Suất ăn';

/// Loài khởi đầu (chọn ở mở đầu và khi pet trưởng thành).
const List<String> starterSpecies = <String>['dog', 'cat', 'rabbit'];

/// Độ hiếm của loài mua bằng kim cương.
enum PetRarity {
  common('Thường'),
  rare('Hiếm'),
  epic('Siêu hiếm');

  const PetRarity(this.label);
  final String label;
}

/// Một loài pet bán trong Cửa hàng bằng kim cương.
class PetShopSpecies {
  const PetShopSpecies({
    required this.species,
    required this.name,
    required this.rarity,
    required this.priceGems,
  });

  final String species;
  final String name;
  final PetRarity rarity;
  final int priceGems;
}

/// Pet bán bằng kim cương (spec D): sóc 20, capybara 60, rồng con 150.
const List<PetShopSpecies> petShopSpecies = <PetShopSpecies>[
  PetShopSpecies(
    species: 'squirrel',
    name: 'Sóc',
    rarity: PetRarity.common,
    priceGems: 20,
  ),
  PetShopSpecies(
    species: 'capybara',
    name: 'Capybara',
    rarity: PetRarity.rare,
    priceGems: 60,
  ),
  PetShopSpecies(
    species: 'dragon',
    name: 'Rồng con',
    rarity: PetRarity.epic,
    priceGems: 150,
  ),
];

/// Đã có hình (Muse lô 12) của loài mới chưa. `false` → "Sắp có",
/// không mua được. Khi có hình: thêm PNG `assets/images/pets/` + manifest
/// rồi đổi cờ loài đó thành `true`.
const Map<String, bool> newPetArtReady = <String, bool>{
  'squirrel': true,
  'capybara': true,
  'dragon': true,
};

/// Đã có hình emote (đói/buồn/vui) + suất ăn (Muse lô 13) chưa.
/// `false` → dùng icon Material/emoji vẽ code.
const bool petUiArtReady = false;

/// Tên hiển thị của mọi loài (khởi đầu + mua).
const Map<String, String> petSpeciesDisplayNames = <String, String>{
  'dog': 'Chó Tinh Anh',
  'cat': 'Mèo Mũm Mĩm',
  'rabbit': 'Thỏ Bánh Bao',
  'squirrel': 'Sóc',
  'capybara': 'Capybara',
  'dragon': 'Rồng con',
};

/// Tên ngắn gọi pet trong câu ("cún Tinh Anh").
const Map<String, String> petSpeciesShortNames = <String, String>{
  'dog': 'cún Tinh Anh',
  'cat': 'mèo Mũm Mĩm',
  'rabbit': 'thỏ Bánh Bao',
  'squirrel': 'sóc',
  'capybara': 'capybara',
  'dragon': 'rồng con',
};

/// Loài [species] mua được chưa (có hình).
bool isPetSpeciesBuyable(String species) => newPetArtReady[species] ?? false;

/// Thông tin bán của loài mua bằng kim cương; null nếu không bán.
PetShopSpecies? petShopSpeciesById(String species) {
  for (final s in petShopSpecies) {
    if (s.species == species) return s;
  }
  return null;
}

/// Tên hiển thị của [species] (mã lạ trả lại chính mã).
String petDisplayName(String species) =>
    petSpeciesDisplayNames[species] ?? species;

/// Hình Muse lô 13 (khi `petUiArtReady` = true): `ui_emote_hungry|sad|happy`
/// và `ui_pet_meal` ở `assets/images/ui/`.
String petEmoteAsset(String mood) => 'assets/images/ui/ui_emote_$mood.png';
const String petMealAsset = 'assets/images/ui/ui_pet_meal.png';

/// Ảnh trứng của [species] (loài mới theo đúng quy ước tên file).
String petEggAsset(String species) => 'assets/images/pets/${species}_egg.png';

/// Pháo giấy ăn mừng: số mảnh, thời gian chạy một đợt (ms) và bảng màu.
const int petConfettiCount = 60;
const int petConfettiMillis = 3200;
const List<int> petConfettiColors = <int>[
  0xFFFF6B8A,
  0xFFFFC94D,
  0xFF5DC3A8,
  0xFF5DB7F0,
  0xFFA07BE0,
  0xFFFF9E5E,
];

/// Mã mục "Vuốt ve" trong bảng Chơi (không phải món trong kho).
const String petPatId = 'pat';
