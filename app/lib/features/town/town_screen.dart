import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../sound/sound_service.dart';
import '../sound/sound_settings.dart';
import '../../core/sync/sync_status_icon.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart';
import '../../core/widgets/game_ui.dart';
import '../../core/widgets/test_build_badge.dart';
import '../arena/arena_lobby_screen.dart';
import '../building/building_screen.dart';
import '../character/character_bounce.dart';
import '../daily_set/daily_set_config.dart';
import '../daily_set/daily_set_service.dart';
import '../ladder/ladder_service.dart';
import '../onboarding/onboarding_model.dart';
import '../onboarding/onboarding_service.dart';
import '../quests/quest_service.dart';
import '../quests/quest_widgets.dart';
import '../stickers/sticker_widgets.dart';
import '../unlocks/unlock_config.dart';
import '../unlocks/unlock_service.dart';
import '../rewards/reward_config.dart';
import '../rewards/reward_service.dart';
import '../seasons/season_config.dart';
import '../seasons/season_service.dart';
import '../seasons/season_widgets.dart';
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
  bool _questDot = false;
  int _mastered = 0;
  SeasonDef? _season;

  bool get _hasTitle => _mastered >= UnlockConfig.titleThreshold;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _tap() => ref.read(soundServiceProvider).playTap();

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
        customQuestionsDao: db.customQuestionsDao,
        settingsDao: db.settingsDao,
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
      // Chấm đỏ nhiệm vụ ngày; lỗi ở đây không được làm hỏng Thị trấn.
      var questDot = false;
      try {
        questDot = await QuestService(db: db).hasClaimable(childId);
      } catch (_) {}
      // Số dạng thành thạo cho danh hiệu và đài phun nước (T4-04).
      var mastered = 0;
      try {
        mastered = await UnlockService(db: db).masteredCount(childId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _season = SeasonService.active(db.clock);
        _mastered = mastered;
        _questDot = questDot;
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
              onAreaTap: (i) {
                _tap();
                context.go(
                  BuildingScreen.route,
                  extra: BuildingScreenArgs(stageIndex: i),
                );
              },
              onRoomTap: () {
                _tap();
                context.go(RoomScreen.route);
              },
              onArenaTap: () {
                _tap();
                context.go(ArenaLobbyScreen.route);
              },
              showFountain: _mastered >= UnlockConfig.townDecorThreshold,
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
                    // Cột nút tròn bên trái: Phòng, rồi Đấu trường (T2-10,
                    // lối vào thứ hai ngoài khu trên bản đồ). Xếp dọc để
                    // nhãn "Đấu trường" không che tâm công trình Lâu đài.
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GameRoundButton(
                          key: const Key('town-room-button'),
                          icon: Icons.home_rounded,
                          image: '$uiArt/ui_icon_room.webp',
                          color: const Color(0xFFFFA65C),
                          label: 'Phòng',
                          tooltip: 'Về Phòng',
                          onPressed: () {
                            _tap();
                            context.go(RoomScreen.route);
                          },
                        ),
                        const SizedBox(height: 4),
                        GameRoundButton(
                          key: const Key('town-arena-button'),
                          icon: Icons.emoji_events,
                          color: const Color(0xFFF0A23B),
                          label: 'Đấu trường',
                          tooltip: 'Đấu trường TIMO',
                          onPressed: () {
                            _tap();
                            context.go(ArenaLobbyScreen.route);
                          },
                        ),
                        const SizedBox(height: 4),
                        StickerHudButton(
                          key: const Key('sticker-book-button'),
                          onPressed: () async {
                            await context.push('/stickers');
                            if (mounted) _refresh();
                          },
                        ),
                      ],
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
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        profile.name,
                                        key: const Key('town-character-name'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: gameOutlinedText(16),
                                      ),
                                      if (_hasTitle)
                                        const FittedBox(
                                          child: TitleChip(fontSize: 10),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            GameStat(
                              icon: Icons.monetization_on_rounded,
                              image: '$uiArt/ui_coin.webp',
                              color: const Color(0xFFF5B83D),
                              text: '$_xu',
                              textKey: const Key('town-xu-balance'),
                            ),
                            GameStat(
                              icon: Icons.diamond_rounded,
                              image: '$uiArt/ui_gem.webp',
                              color: const Color(0xFFA07BE0),
                              text: '$_gems',
                              textKey: const Key('town-gem-balance'),
                            ),
                            GameStat(
                              icon: Icons.star_rounded,
                              image: '$uiArt/ui_star.webp',
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
                            const SyncStatusIcon(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QuestHudButton(
                          key: const Key('town-quest-button'),
                          showDot: _questDot,
                          onPressed: () async {
                            _tap();
                            await showQuestBoardDialog(context);
                            if (mounted) _refresh();
                          },
                        ),
                        const SizedBox(height: 4),
                        const SoundHudButton(key: Key('sound-settings-button')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Biển mùa (T5-02): chỉ trong mùa, ở giữa cạnh dưới.
          if (_season case final season?)
            Positioned(
              left: 96,
              right: 96,
              bottom: 6,
              child: Center(
                child: SeasonBanner(
                  key: const Key('season-banner'),
                  season: season,
                ),
              ),
            ),
          // Bản thử: nhãn nhỏ ở góc dưới-trái (chỉ hiện khi bật cờ).
          const Positioned(left: 6, bottom: 4, child: TestBuildBadge()),
        ],
      ),
    );
  }
}
