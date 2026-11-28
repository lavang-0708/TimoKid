/// Dịch vụ mùa (T5-02): mùa nào đang diễn ra, món nào thuộc mùa, giá giảm,
/// và xu thưởng thêm của đề ngày. Dart thuần; ngày lấy từ [Clock] (giờ Việt
/// Nam) nên test dùng `FakeClock` với ngày cố định.
library;

import '../../core/database/app_database.dart';
import '../../core/database/tables.dart' show Currency;
import '../../core/time/clock.dart';
import '../shop/shop_catalog.dart';
import 'season_config.dart';

/// Lý do dòng ví thưởng thêm của mùa.
const String seasonBonusReason = 'season_bonus';

class SeasonService {
  const SeasonService._();

  /// CHỈ menu QA ("Giả lập mùa"): ép một mùa bất kể ngày. Giữ trong bộ
  /// nhớ, tắt app là hết. Null = theo ngày thật.
  static String? forcedSeasonId;

  /// CHỈ test: tắt hẳn mùa (đặt trong `flutter_test_config.dart`) để các
  /// ảnh golden không đổi theo ngày chạy test. Test về mùa đặt lại `false`.
  static bool debugDisabled = false;

  /// Mùa đang diễn ra theo [clock], hoặc null. Mùa bị ép ([forcedSeasonId])
  /// thắng ngày thật.
  static SeasonDef? active(Clock clock) {
    if (debugDisabled && forcedSeasonId == null) return null;
    final forced = forcedSeasonId;
    if (forced != null) return SeasonConfig.byId(forced);
    return activeOn(clock.today());
  }

  /// Mùa có trong ngày [date] (`YYYY-MM-DD`), bỏ qua QA.
  static SeasonDef? activeOn(String date) {
    for (final s in SeasonConfig.all) {
      if (s.isActiveOn(date)) return s;
    }
    return null;
  }

  /// Món [item] có thuộc [season] không.
  static bool belongs(ShopItem item, SeasonDef season) {
    if (season.itemIds.contains(item.id)) return true;
    if (item.kind == ShopItemKind.roomTheme ||
        item.kind == ShopItemKind.roomThemeItem) {
      return season.roomThemeIds.contains(item.roomThemeId);
    }
    if (item.kind == ShopItemKind.outfit) {
      return season.outfitNumbers.contains(item.outfit);
    }
    return false;
  }

  /// Giá sau giảm [percent]% (làm tròn gần nhất, tối thiểu 1).
  static int discounted(int price, int percent) {
    if (price <= 0) return price;
    final v = (price * (100 - percent) + 50) ~/ 100;
    return v < 1 ? 1 : v;
  }

  /// Gắn nhãn và giá giảm cho món thuộc [season]; món khác (hoặc [season]
  /// null) giữ nguyên.
  static ShopItem decorate(
    ShopItem item,
    SeasonDef? season, {
    int discountPercent = SeasonConfig.discountPercent,
  }) {
    if (season == null || !belongs(item, season)) return item;
    return item.withSeason(
      seasonId: season.id,
      priceXu: discounted(item.priceXu, discountPercent),
      priceGems: discounted(item.priceGems, discountPercent),
      listPrice: item.usesGems ? item.priceGems : item.priceXu,
    );
  }

  /// Danh sách đã gắn nhãn/giảm giá theo [season].
  static List<ShopItem> decorateAll(List<ShopItem> items, SeasonDef? season) =>
      season == null ? items : [for (final i in items) decorate(i, season)];

  /// Các món thuộc [season] (đã giảm giá), mọi nhóm hàng.
  static List<ShopItem> itemsOf(List<ShopItem> items, SeasonDef season) => [
    for (final i in items)
      if (belongs(i, season)) decorate(i, season),
  ];

  /// Xu thưởng thêm cho [baseXu] xu của đề ngày (làm tròn gần nhất).
  static int bonusFor(
    int baseXu, {
    int percent = SeasonConfig.questBonusPercent,
  }) => baseXu <= 0 ? 0 : (baseXu * percent + 50) ~/ 100;

  /// Ghi thưởng thêm của mùa vào ví nếu đang trong mùa. Trả số xu đã
  /// cộng (0 nếu không có mùa hoặc [baseXu] <= 0).
  static Future<int> awardBonus({
    required AppDatabase db,
    required String childId,
    required int baseXu,
    String? refId,
  }) async {
    final season = active(db.clock);
    if (season == null) return 0;
    final bonus = bonusFor(baseXu);
    if (bonus <= 0) return 0;
    await db.walletDao.addEntry(
      childId: childId,
      currency: Currency.xu,
      amount: bonus,
      reason: seasonBonusReason,
      refId: refId,
    );
    return bonus;
  }
}
