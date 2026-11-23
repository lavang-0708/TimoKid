/// Cấu hình Nhiệm vụ ngày + chuỗi ngày (tuần 23/11, mục C): MỌI con số
/// và cờ hình nằm ở file này (một chỗ duy nhất) để chủ dự án chỉnh sau.
///
/// Luật:
/// - Mỗi ngày (giờ Việt Nam) [questsPerDay] nhiệm vụ chọn từ kho theo
///   seed (bé, ngày), không trùng loại; nhiệm vụ pet chỉ vào kho khi bé
///   có pet đã nở đang đi theo.
/// - Mỗi nhiệm vụ xong: bé bấm nhận [claimXu] xu. Nhận đủ cả 3: thêm
///   [allClaimedGems] kim cương.
/// - Chuỗi = số ngày liên tiếp xong đủ cả 3 nhiệm vụ. Ngày thứ
///   [streakChestEvery], 2×, 3×… của chuỗi: rương [streakChestGems] kim
///   cương (bé bấm nhận). Lỡ một ngày thì chuỗi về 0.
library;

/// Cờ ảnh: `ui_quest_board`, `ui_quest_check`, `ui_streak_flame`,
/// `ui_streak_chest` chưa có (Muse đang vẽ lô 13). Tắt thì dùng icon
/// Material tạm. Khi ảnh về: thêm file vào `assets/` + `manifest.json`,
/// đặt cờ `true`.
const bool questArtReady = false;

/// Loại nhiệm vụ trong kho.
enum QuestType {
  /// Đúng ngay lần đầu [QuestConfig.strandCorrectTarget] câu của mảng X.
  strandCorrect(needsStrand: true),

  /// Xong chặng ngày của tòa X.
  strandStage(needsStrand: true),

  /// Leo qua 1 tầng tháp (mảng nào cũng được).
  towerFloor,

  /// Làm đấu trường hôm nay.
  arena,

  /// Xong đề ngày (cả 5 chặng).
  dailyComplete,

  /// Làm lại đúng [QuestConfig.reviewRetryTarget] câu trong sổ ôn tập.
  reviewRetry,

  /// Cho pet ăn.
  feedPet(needsPet: true),

  /// Chơi với pet.
  playPet(needsPet: true);

  const QuestType({this.needsStrand = false, this.needsPet = false});

  /// Nhiệm vụ gắn với một mảng (tòa nhà).
  final bool needsStrand;

  /// Chỉ vào kho khi bé có pet đã nở đang đi theo.
  final bool needsPet;
}

/// Toàn bộ hằng số của nhiệm vụ ngày, ở một chỗ duy nhất.
class QuestConfig {
  const QuestConfig._();

  /// Số nhiệm vụ mỗi ngày.
  static const int questsPerDay = 3;

  /// Xu nhận khi bấm nhận một nhiệm vụ xong.
  static const int claimXu = 10;

  /// Kim cương thưởng thêm khi đã nhận đủ cả [questsPerDay] nhiệm vụ.
  static const int allClaimedGems = 1;

  /// Số câu đúng ngay lần đầu của "đúng N câu mảng X".
  static const int strandCorrectTarget = 5;

  /// Số câu ôn tập làm đúng ngay lần đầu của "làm lại N câu trong sổ".
  static const int reviewRetryTarget = 2;

  /// Cứ bấy nhiêu ngày liên tiếp thì có một rương chuỗi.
  static const int streakChestEvery = 7;

  /// Kim cương trong mỗi rương chuỗi.
  static const int streakChestGems = 5;

  /// Số ngày lùi tối đa khi đếm chuỗi (chặn vòng lặp vô hạn).
  static const int maxStreakLookbackDays = 400;

  /// Ảnh, chỉ dùng khi [questArtReady].
  static const String boardAsset = 'assets/images/ui/ui_quest_board.png';
  static const String checkAsset = 'assets/images/ui/ui_quest_check.png';
  static const String flameAsset = 'assets/images/ui/ui_streak_flame.png';
  static const String chestAsset = 'assets/images/ui/ui_streak_chest.png';
}
