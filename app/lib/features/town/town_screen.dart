import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart';
import '../building/building_screen.dart';
import '../character/character_bounce.dart';
import '../character/kid_assets.dart';
import '../character/kid_look_service.dart';
import '../character/kid_sprite.dart';
import '../daily_set/daily_set_config.dart';
import '../daily_set/daily_set_service.dart';
import '../ladder/ladder_service.dart';
import '../onboarding/onboarding_model.dart';
import '../onboarding/onboarding_service.dart';
import '../rewards/reward_config.dart';
import '../rewards/reward_service.dart';
import '../room/room_screen.dart';
import 'town_map.dart';

/// Màn Thị trấn — màn chính của bản 0.1 (T1-12).
///
/// Bản đồ phong cách v2 (A2): nền thị trấn + 10 lớp động + 5 công
/// trình là vùng bấm (mỗi khu một công trình, xem [townAreas] trong
/// `town_assets.dart`), nhà hồng về Phòng (xem [TownMap]). Bấm công
/// trình thì vào màn Tòa nhà của khu đó (PR (B)) — chưa vào làm bài
/// ngay; nút "Thử thách" ở màn Tòa nhà mới vào màn toán. Mỗi nhãn
/// dán trên công trình hiện tên khu + trạng thái chặng hôm nay (chưa
/// làm / đang làm / xong); hàng đầu vẫn là số xu, kim cương, thanh
/// tiến độ đề ngày như trước.
///
/// Từ T2-03, nhân vật bé đã tạo hiện ở cột trái (tên bên dưới):
/// nữ dùng bộ nhân vật nữ 1 thật (PR #18), nam tạm dùng lớp xám
/// như ở màn mở đầu. Chưa tạo nhân vật (máy 0.1 cũ) thì không có
/// cột nhân vật. Nhân vật thở nhẹ kiểu squash/stretch (xem
/// `CharacterView`), bấm vào thì nhảy lên + lấp lánh (xem
/// [CharacterBounce]); cổng [AnimationGate] tắt hiệu ứng khi chạy
/// test để `pumpAndSettle` dừng được.
///
/// Lớp động trên bản đồ (mây trôi, xe chạy, người đi bộ, đài phun
/// nước nhấp nhô, cây đung đưa) cũng tắt bằng cổng [AnimationGate]
/// khi chạy test (xem [TownMap]).
///
/// Số dư đọc qua [RewardService.balances] của T1-11 (đã merge, tổng
/// `wallet_ledger` của bé), bảng thưởng đọc từ settings như màn làm
/// toán nên đổi settings thì mức thưởng đổi theo.
class TownScreen extends ConsumerStatefulWidget {
  const TownScreen({super.key});

  static const String route = '/';

  @override
  ConsumerState<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends ConsumerState<TownScreen> {
  List<String>? _statuses;
  int _xu = 0;
  int _gems = 0;
  bool _loading = true;
  String? _error;
  CharacterProfile? _profile;
  String? _headAccessory;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant TownScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Quay lại từ màn làm toán/kết quả chặng (kể cả nút Về của hệ
    // thống): tải lại trạng thái chặng và số dư để nút khu hiện đúng.
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final db = ref.read(databaseProvider);
      final childId = await db.ensureSeeded();
      final service = DailySetService(
        dailySetsDao: db.dailySetsDao,
        reviewQueueDao: db.reviewQueueDao,
        ladderService: LadderService(
          attemptsDao: db.attemptsDao,
          skillProgressDao: db.skillProgressDao,
        ),
        clock: db.clock,
      );
      final set = await service.getOrCreateTodaySet(childId: childId);
      final statuses = db.dailySetsDao.readStageStatus(set);
      final rewardService = RewardService(
        db: db,
        config: await RewardConfig.load(db),
      );
      final balances = await rewardService.balances(childId);
      final profile = await OnboardingService(db: db).loadProfile(childId);
      final accessory = await KidLookService(db: db).headAccessory(childId);
      if (!mounted) return;
      setState(() {
        _statuses = statuses;
        _xu = balances[Currency.xu] ?? 0;
        _gems = balances[Currency.gem] ?? 0;
        _profile = profile;
        _headAccessory = accessory;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _statuses;
    if (_loading && statuses == null) {
      return const Scaffold(
        key: Key('town-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (statuses == null) {
      return Scaffold(
        key: const Key('town-screen'),
        appBar: AppBar(
          title: const Text('Thị trấn Diệu Kỳ'),
          actions: [
            TextButton.icon(
              key: const Key('town-room-button'),
              onPressed: () => context.go(RoomScreen.route),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Phòng'),
            ),
          ],
        ),
        body: Center(child: Text('Không tải được Thị trấn: $_error')),
      );
    }
    final done = statuses.where((s) => s == StageStatus.done).length;
    final total = DailySetConfig.stagesPerDay;
    final profile = _profile;
    return Scaffold(
      key: const Key('town-screen'),
      appBar: AppBar(
        title: const Text('Thị trấn Diệu Kỳ'),
        actions: [
          TextButton.icon(
            key: const Key('town-room-button'),
            onPressed: () => context.go(RoomScreen.route),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Phòng'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '$_xu xu',
                  key: const Key('town-xu-balance'),
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 16),
                Text(
                  '◆ $_gems',
                  key: const Key('town-gem-balance'),
                  style: const TextStyle(fontSize: 22),
                ),
                const Spacer(),
                // Co lại + cắt `...` khi hẹp (vd: phông test Ahem
                // rộng, màn 608x248, đề đã xong): cùng cách sửa
                // header màn Phòng ở T2-04.
                Flexible(
                  child: Text(
                    done == total
                        ? 'Xong đề ngày hôm nay!'
                        : 'Đề ngày: $done/$total chặng',
                    key: const Key('town-progress-text'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Canh phải để khi đủ chỗ thì chữ vẫn nằm ở mép
                    // phải như trước khi bọc Flexible (Flexible chia
                    // chỗ trống với Spacer nên chữ mặc định sẽ dồn trái).
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              key: const Key('town-progress-bar'),
              value: done / total,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nhân vật đã tạo đứng ở cột trái (chỉ khi đã có hồ
                  // sơ); tên bên dưới. Không có hồ sơ (máy 0.1 cũ)
                  // thì 5 nút khu chiếm hết chiều rộng như trước.
                  if (profile != null) ...[
                    SizedBox(
                      width: 120,
                      child: Column(
                        children: [
                          Expanded(
                            child: CharacterBounce(
                              // Thở/chớp mắt bật (kiểu game); cổng
                              // AnimationGate tắt khi chạy test.
                              child: KidSprite(
                                key: const Key('town-character'),
                                gender: profile.gender,
                                outfit: kidOutfitNumber(profile.dress),
                                headAccessory: _headAccessory,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.name,
                            key: const Key('town-character-name'),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: TownMap(
                      statuses: statuses,
                      onAreaTap: (i) => context.go(
                        BuildingScreen.route,
                        extra: BuildingScreenArgs(stageIndex: i),
                      ),
                      onRoomTap: () => context.go(RoomScreen.route),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
