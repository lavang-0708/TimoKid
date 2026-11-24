/// Cấu hình hiệu ứng rồng (siêu hiếm đầu tiên): MỌI con số, màu, cờ
/// hình và tên file hiệu ứng của rồng nằm ở file này (một chỗ duy nhất).
///
/// Hình Muse (artist) đang vẽ thêm cho rồng TRƯỞNG THÀNH (512x512, cùng
/// vị trí/cỡ `dragon_adult`, chân y ≈ 439):
/// - `dragon_fire_1..4` (phun lửa sang phải), `dragon_water_1..4` (phun
///   nước), `dragon_fly_a..d` (bay, thân nâng 40–60 px, không bóng đất),
///   `dragon_aura.png` (vầng sáng xanh bạc hà - vàng, tâm ≈ (256, 240)).
/// - Có đủ hình: thêm PNG vào `assets/images/pets/` + dòng manifest rồi
///   đổi [dragonFxArtReady] thành `true`. Chưa có thì mọi hiệu ứng vẽ
///   bằng code (CustomPainter hạt nhẹ), không phải sửa chỗ khác.
library;

import 'dart:ui';

/// Đã có hình hiệu ứng rồng của Muse chưa (`false` → vẽ bằng code).
const bool dragonFxArtReady = false;

/// Mã loài rồng.
const String dragonSpecies = 'dragon';

// --- Hình (chỉ dùng khi [dragonFxArtReady] = true) ---------------------

const String _petsDir = 'assets/images/pets';
const String dragonAuraAsset = '$_petsDir/dragon_aura.png';

/// 4 khung phun lửa.
const List<String> dragonFireAssets = <String>[
  '$_petsDir/dragon_fire_1.png',
  '$_petsDir/dragon_fire_2.png',
  '$_petsDir/dragon_fire_3.png',
  '$_petsDir/dragon_fire_4.png',
];

/// 4 khung phun nước.
const List<String> dragonWaterAssets = <String>[
  '$_petsDir/dragon_water_1.png',
  '$_petsDir/dragon_water_2.png',
  '$_petsDir/dragon_water_3.png',
  '$_petsDir/dragon_water_4.png',
];

/// 4 khung bay (lặp khi bay).
const List<String> dragonFlyAssets = <String>[
  '$_petsDir/dragon_fly_a.png',
  '$_petsDir/dragon_fly_b.png',
  '$_petsDir/dragon_fly_c.png',
  '$_petsDir/dragon_fly_d.png',
];

// --- Thời gian khung hình thật ----------------------------------------

/// Mỗi khung phun lửa/nước hiện bao lâu (ms), riêng khung số
/// [dragonFxHoldFrame] (0 = khung 1) giữ thêm [dragonFxHoldExtraMs].
const int dragonFxFrameMs = 120;
const int dragonFxHoldFrame = 2;
const int dragonFxHoldExtraMs = 450;

/// Khung bay đổi sau mỗi bấy nhiêu ms.
const int dragonFlyFrameMs = 110;

// --- Miệng + hình học trong khung 512 ---------------------------------

/// Miệng rồng (khung 512x512, rồng quay phải). TẠM đoán, sẽ cập nhật
/// khi Muse ghi tọa độ thật.
const Offset dragonMouth = Offset(360, 200);

/// Tâm vầng sáng trong khung 512 (khớp `dragon_aura.png`).
const Offset dragonAuraCenter = Offset(256, 240);

/// Chân rồng trong khung 512 (y).
const double dragonFeetY = 439;

// --- Vầng sáng ---------------------------------------------------------

const int dragonAuraPulseMs = 2800;

/// Bán kính vầng sáng code (tỉ lệ cạnh khung) và biên độ nhịp thở.
const double dragonAuraRadius = 0.52;
const double dragonAuraPulseAmount = 0.05;
const double dragonAuraMinOpacity = 0.75;

const Color dragonAuraMint = Color(0xFF7FE8C8);
const Color dragonAuraGold = Color(0xFFFFE08A);

/// Vị trí lấp lánh quanh rồng (tỉ lệ 0..1 của khung) + pha lệch.
const List<(double, double, double)> dragonAuraSparkles =
    <(double, double, double)>[
      (0.20, 0.30, 0.00),
      (0.80, 0.26, 0.35),
      (0.12, 0.62, 0.60),
      (0.88, 0.58, 0.15),
      (0.50, 0.08, 0.80),
    ];

// --- Hành động ----------------------------------------------------------

/// Tự ẩn bảng 3 nút sau bấy nhiêu ms.
const int dragonMenuHideMs = 5000;

/// Số hạt tối đa mỗi hiệu ứng (giữ nhẹ cho máy tablet tầm trung).
const int dragonFxMaxParticles = 40;

/// Bản đầy đủ (rồng trưởng thành) khi vẽ bằng code.
const int dragonFireMs = 1900;
const int dragonWaterMs = 1900;
const int dragonFireParticles = 34;
const int dragonWaterParticles = 30;

/// Tầm phun (khung 512) của bản đầy đủ / bản nhỏ.
const double dragonBreathReach = 250;
const double dragonBreathReachSmall = 70;

/// Bản nhỏ (mới nở/nhỡ): ít hạt, ngắn.
const int dragonSmallMs = 1100;
const int dragonSmallParticles = 10;

/// Phần thời gian (0..1) hạt còn được phát; sau đó là tàn lửa / tung
/// nước.
const double dragonEmitFraction = 0.6;

const List<Color> dragonFireColors = <Color>[
  Color(0xFFFF7A1A), // cam
  Color(0xFFFFD23F), // vàng
];
const Color dragonEmberColor = Color(0xFFFFB347);
const Color dragonWaterColor = Color(0xFF4DB6FF);
const Color dragonWaterLight = Color(0xFFBDE7FF);

/// Bay: nâng lên / treo / hạ xuống (ms) và độ cao (tỉ lệ cạnh hộp pet).
const int dragonFlyRiseMs = 650;
const int dragonFlyHoverMs = 1300;
const int dragonFlyLandMs = 600;
const double dragonFlyLift = 0.26;

/// Biên độ lắc lên xuống khi treo (tỉ lệ cạnh hộp).
const double dragonFlyBob = 0.012;

/// Bóng đất co lại khi bay: tỉ lệ nhỏ nhất ở độ cao tối đa.
const double dragonShadowMinScale = 0.55;
const double dragonShadowMinOpacity = 0.55;

/// Nhảy-vỗ cánh của rồng nhỏ (mới nở/nhỡ): thời gian + độ cao.
const int dragonHopMs = 1000;
const double dragonHopLift = 0.24;

/// Cánh vỗ lấp lánh (số hạt, bản code).
const int dragonFlutterSparkles = 6;

/// Rồng trưởng thành đi quãng dài hơn ngưỡng này (px khung Phòng
/// 1600x900) thì bay thay vì đi bộ.
const double dragonFlyWalkThreshold = 450;

/// Thời gian cất cánh / hạ cánh khi bay-đi (ms).
const int dragonCruiseLiftMs = 450;

/// Lời nhắc một lần cho rồng chưa lớn.
const String dragonHintText = 'Lớn lên rồng sẽ phun lửa thật!';

// --- Tên + biểu tượng nút ---------------------------------------------

const String dragonFireLabel = 'Phun lửa';
const String dragonWaterLabel = 'Phun nước';
const String dragonFlyLabel = 'Bay';
