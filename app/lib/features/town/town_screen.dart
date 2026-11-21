import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart';
import '../../core/widgets/game_ui.dart';
import '../building/building_screen.dart';
import '../character/character_bounce.dart';
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
      if (!mounted) return;
      setState(() {
        _statuses = statuses;
        _xu = balances[Currency.xu] ?? 0;
        _gems = balances[Currency.gem] ?? 0;
        _profile = profile;
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
    // Góp ý 21/11: bản đồ phủ kín màn hình, không còn cột nhân vật bên
    // cạnh; chỉ số là một dòng kiểu game ở trên cùng, nút về Phòng là
    // nút tròn có icon.
    return Scaffold(
      key: const Key('town-screen'),
      backgroundColor: const Color(0xFFDDEFD6),
      body: Stack(
        children: [
          Positioned.fill(
            child: TownMap(
              statuses: statuses,
              onAreaTap: (i) => context.go(
                BuildingScreen.route,
                extra: BuildingScreenArgs(stageIndex: i),
              ),
              onRoomTap: () => context.go(RoomScreen.route),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GameRoundButton(
                      key: const Key('town-room-button'),
                      icon: Icons.home_rounded,
                      color: const Color(0xFFFF9EB5),
                      label: 'Phòng',
                      tooltip: 'Về Phòng',
                      onPressed: () => context.go(RoomScreen.route),
                    ),
                    // Chỉ số dồn sang phải để không che Lâu đài ở góc trái.
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GameHudBar(
                          children: [
                            if (profile != null)
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    profile.name,
                                    key: const Key('town-character-name'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: gameOutlinedText(16),
                                  ),
                                ),
                              ),
                            GameStat(
                              icon: Icons.monetization_on_rounded,
                              color: const Color(0xFFF5B83D),
                              text: '$_xu',
                              textKey: const Key('town-xu-balance'),
                            ),
                            GameStat(
                              icon: Icons.diamond_rounded,
                              color: const Color(0xFFA07BE0),
                              text: '$_gems',
                              textKey: const Key('town-gem-balance'),
                            ),
                            GameStat(
                              icon: Icons.star_rounded,
                              color: const Color(0xFFFFC94D),
                              text: '$done/$total',
                              textKey: const Key('town-progress-text'),
                            ),
                            SizedBox(
                              width: 56,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  key: const Key('town-progress-bar'),
                                  value: done / total,
                                  minHeight: 8,
                                  backgroundColor: const Color(0x55FFFFFF),
                                  color: const Color(0xFFFFC94D),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
