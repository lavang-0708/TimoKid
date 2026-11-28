/// Hằng số cấu hình của Đấu trường (T2-10): đề thi thử TIMO.
///
/// Mọi con số của đề nằm ở một chỗ này, không viết cứng rải rác. Định
/// dạng lấy theo đề TIMO thật (đã đối chiếu): vòng Chọn 25 câu điền số,
/// 5 phần x 5 câu theo thứ tự Tư duy logic, Số học, Lý thuyết số, Hình
/// học, Tổ hợp; mỗi câu 4 điểm, tổng 100 điểm, 90 phút, sai không bị
/// trừ điểm. [ArenaFormat.finalRound] (30 câu, mỗi phần 6 câu, 5 điểm,
/// 120 phút) là vòng Chung kết, mở khi bé có huy chương Bạc trở lên ở
/// vòng loại ([arenaFinalUnlockMedal]).
library;

import '../../core/database/tables.dart';

/// Cờ nghệ thuật: false thì dùng nền vẽ bằng code, icon Material cho
/// huy chương và khu tạm trên bản đồ Thị trấn; true thì dùng ảnh thật
/// (`arena_bg.webp`, `medal_*.webp`, `gem_chest.webp`, `arena_building.webp`)
/// khi họa sĩ vẽ xong và ảnh được thêm vào `assets/`.
const bool arenaArtReady = true;

/// Ảnh nền màn Đấu trường (1600x900), chỉ dùng khi [arenaArtReady].
const String arenaBackgroundAsset = 'assets/images/backgrounds/arena_bg.webp';

/// Ảnh công trình Đấu trường trên bản đồ Thị trấn, chỉ dùng khi
/// [arenaArtReady].
const String arenaBuildingAsset = 'assets/images/town/arena_building.webp';

/// Ảnh rương kim cương trên màn Kết quả, chỉ dùng khi [arenaArtReady].
const String arenaGemChestAsset = 'assets/images/items/gem_chest.webp';

/// Định dạng một vòng thi.
class ArenaFormat {
  const ArenaFormat({
    required this.code,
    required this.questionsPerSection,
    required this.pointsPerQuestion,
    required this.minutes,
    required this.title,
    required this.goldMin,
    required this.silverMin,
    required this.bronzeMin,
    required this.gemsGold,
    required this.gemsSilver,
    required this.gemsBronze,
    required this.gemsParticipant,
  });

  /// Tên vòng hiển thị ("Vòng loại").
  final String title;

  /// Ngưỡng số câu đúng để được Vàng / Bạc / Đồng.
  final int goldMin;
  final int silverMin;
  final int bronzeMin;

  /// Kim cương thưởng theo huy chương (bài đầu tiên trong ngày của vòng).
  final int gemsGold;
  final int gemsSilver;
  final int gemsBronze;
  final int gemsParticipant;

  /// Huy chương theo số câu đúng của vòng này.
  ArenaMedal medalFor(int correct) {
    if (correct >= goldMin) return ArenaMedal.gold;
    if (correct >= silverMin) return ArenaMedal.silver;
    if (correct >= bronzeMin) return ArenaMedal.bronze;
    return ArenaMedal.participant;
  }

  /// Kim cương thưởng của huy chương [medal] ở vòng này.
  int gemsFor(ArenaMedal medal) => switch (medal) {
    ArenaMedal.gold => gemsGold,
    ArenaMedal.silver => gemsSilver,
    ArenaMedal.bronze => gemsBronze,
    ArenaMedal.participant => gemsParticipant,
  };

  /// Đọc vòng từ mã đã lưu (`arena_attempts.mode`); mã lạ là vòng loại.
  static ArenaFormat fromCode(String code) =>
      code == finalRound.code ? finalRound : heat;

  /// Mã vòng, lưu vào `arena_attempts.mode`.
  final String code;

  /// Số câu mỗi phần (5 phần).
  final int questionsPerSection;

  /// Điểm mỗi câu đúng.
  final int pointsPerQuestion;

  /// Thời gian làm bài, phút.
  final int minutes;

  /// Số phần của đề (5 mảng TIMO).
  int get sections => arenaSections.length;

  /// Tổng số câu của đề.
  int get totalQuestions => sections * questionsPerSection;

  /// Tổng điểm tối đa.
  int get maxScore => totalQuestions * pointsPerQuestion;

  /// Thời gian làm bài.
  Duration get duration => Duration(minutes: minutes);

  /// Vòng Chọn: 25 câu, 4 điểm, 100 điểm, 90 phút.
  static const ArenaFormat heat = ArenaFormat(
    code: 'heat',
    questionsPerSection: 5,
    pointsPerQuestion: 4,
    minutes: 90,
    title: 'Vòng loại',
    goldMin: 21,
    silverMin: 16,
    bronzeMin: 11,
    gemsGold: 5,
    gemsSilver: 3,
    gemsBronze: 2,
    gemsParticipant: 1,
  );

  /// Vòng Chung kết: 30 câu, 5 điểm, 150 điểm, 120 phút.
  static const ArenaFormat finalRound = ArenaFormat(
    code: 'final',
    questionsPerSection: 6,
    pointsPerQuestion: 5,
    minutes: 120,
    title: 'Chung kết',
    goldMin: 25,
    silverMin: 19,
    bronzeMin: 13,
    gemsGold: 8,
    gemsSilver: 5,
    gemsBronze: 3,
    gemsParticipant: 2,
  );
}

/// Một phần của đề theo thứ tự trên đề thật.
class ArenaSection {
  const ArenaSection({
    required this.strand,
    required this.name,
    required this.shortName,
  });

  /// Mảng của app ([Strand]).
  final String strand;

  /// Tên phần trên đề ("Tư duy logic").
  final String name;

  /// Tên ngắn cho bảng điểm ("Logic").
  final String shortName;
}

/// 5 phần theo thứ tự trên đề TIMO thật.
const List<ArenaSection> arenaSections = [
  ArenaSection(strand: Strand.logic, name: 'Tư duy logic', shortName: 'Logic'),
  ArenaSection(strand: Strand.arith, name: 'Số học', shortName: 'Số học'),
  ArenaSection(
    strand: Strand.number,
    name: 'Lý thuyết số',
    shortName: 'Lý thuyết số',
  ),
  ArenaSection(strand: Strand.geo, name: 'Hình học', shortName: 'Hình học'),
  ArenaSection(strand: Strand.comb, name: 'Tổ hợp', shortName: 'Tổ hợp'),
];

/// Huy chương theo số câu đúng. Kim cương ở [gems] là của vòng loại;
/// vòng Chung kết dùng [ArenaFormat.gemsFor].
enum ArenaMedal {
  gold('gold', 'Vàng', 5),
  silver('silver', 'Bạc', 3),
  bronze('bronze', 'Đồng', 2),
  participant('participant', 'Tham gia', 1);

  const ArenaMedal(this.code, this.label, this.gems);

  /// Mã lưu trong `arena_attempts.medal`.
  final String code;

  /// Tên huy chương hiển thị.
  final String label;

  /// Kim cương thưởng cho bài đầu tiên trong ngày.
  final int gems;

  /// Đọc từ mã đã lưu; mã lạ thì coi là tham gia.
  static ArenaMedal fromCode(String code) => ArenaMedal.values.firstWhere(
    (m) => m.code == code,
    orElse: () => ArenaMedal.participant,
  );
}

/// Huy chương theo số câu đúng của [format] (mặc định vòng loại:
/// Vàng từ 21, Bạc từ 16, Đồng từ 11; Chung kết: 25 / 19 / 13).
ArenaMedal arenaMedalFor(
  int correct, {
  ArenaFormat format = ArenaFormat.heat,
}) => format.medalFor(correct);

/// Huy chương tối thiểu ở vòng loại để mở vòng Chung kết.
const ArenaMedal arenaFinalUnlockMedal = ArenaMedal.silver;

/// Huy chương [a] có tốt hơn hoặc bằng [b] không (Vàng > Bạc > Đồng >
/// Tham gia).
bool arenaMedalAtLeast(ArenaMedal a, ArenaMedal b) => a.index <= b.index;

/// Khung bản đồ Thị trấn (1600x900): vị trí khu Đấu trường.
///
/// Khu đất có ao ở góc dưới phải, chưa có công trình nào. Hình chữ nhật
/// là cả khung ảnh `arena_building.webp` (1024x640, phần có hình
/// x 122–903, y 42–601) thu còn tỉ lệ 0,365: tòa rộng ~285 px khung,
/// đáy tòa ở y 755, mép phải tòa ~1520 để màn 16:10 (cắt hai bên)
/// vẫn thấy trọn. Đã ghép thử trên `town_v3.webp` (22/11).
const double arenaTownLeft = 1190;
const double arenaTownTop = 536;
const double arenaTownWidth = 374;
const double arenaTownHeight = 234;

/// Điểm đặt biển "Đấu trường" (tâm đáy biển, khung 1600x900).
const double arenaTownSignX = 1437;
const double arenaTownSignY = 668;
