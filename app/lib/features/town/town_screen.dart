import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database_provider.dart';
import '../../core/database/models.dart';
import '../../core/database/tables.dart';
import '../daily_set/daily_set_config.dart';
import '../daily_set/daily_set_service.dart';
import '../ladder/ladder_service.dart';
import '../math/math_screen.dart';
import '../rewards/reward_config.dart';
import '../rewards/reward_service.dart';
import 'town_assets.dart';

/// Màn Thị trấn — màn chính của bản 0.1 (T1-12).
///
/// 5 nút lớn cho 5 khu theo DESIGN, mỗi nút hiện trạng thái chặng hôm
/// nay (chưa làm / đang làm / xong), thanh tiến độ đề ngày, số xu và
/// kim cương. Chưa có bản đồ hay cư dân (theo PLAN mục T1-12).
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
      if (!mounted) return;
      setState(() {
        _statuses = statuses;
        _xu = balances[Currency.xu] ?? 0;
        _gems = balances[Currency.gem] ?? 0;
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
        appBar: AppBar(title: const Text('Thị trấn Diệu Kỳ')),
        body: Center(child: Text('Không tải được Thị trấn: $_error')),
      );
    }
    final done = statuses.where((s) => s == StageStatus.done).length;
    final total = DailySetConfig.stagesPerDay;
    return Scaffold(
      key: const Key('town-screen'),
      appBar: AppBar(title: const Text('Thị trấn Diệu Kỳ')),
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
                Text(
                  done == total
                      ? 'Xong đề ngày hôm nay!'
                      : 'Đề ngày: $done/$total chặng',
                  key: const Key('town-progress-text'),
                  style: const TextStyle(fontSize: 22),
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
                  for (var i = 0; i < townAreas.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _AreaButton(
                        area: townAreas[i],
                        status: statuses[i],
                        stageIndex: i,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một nút khu: biểu tượng SVG, tên khu, nhãn trạng thái chặng hôm nay.
class _AreaButton extends StatelessWidget {
  const _AreaButton({
    required this.area,
    required this.status,
    required this.stageIndex,
  });

  final TownArea area;
  final String status;
  final int stageIndex;

  @override
  Widget build(BuildContext context) {
    final (label, chipColor) = switch (status) {
      StageStatus.done => ('Xong ✓', Colors.green.shade600),
      StageStatus.inProgress => ('Đang làm', Colors.amber.shade700),
      _ => ('Chưa làm', Colors.grey.shade600),
    };
    return SizedBox(
      child: ElevatedButton(
        key: Key('town-stage-$stageIndex-button'),
        onPressed: () => context.go(
          MathScreen.route,
          extra: MathScreenArgs(stageIndex: stageIndex),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(area.color),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        // Icon chiếm phần còn lại của nút (Expanded): tên khu (tối đa
        // 2 dòng; font DejaVu trong test rộng hơn Roboto nên tính dư)
        // + nhãn trạng thái giữ chiều cao cố định, icon co theo chỗ
        // còn lại nên không bao giờ tràn — ở màn 640x320 icon còn
        // ~40 dp, ở màn lớn cũng không phình vô hạn vì nút cao hữu hạn.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SvgPicture.asset(area.asset),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              area.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
