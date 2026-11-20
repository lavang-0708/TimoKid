/// Test đơn vị cho [loadBuildingStats] (PR (B)): thống kê chặng
/// hôm nay của một mảng — trạng thái, số câu đúng, xu nhận, bậc,
/// chặng tự chọn đã làm hôm nay.
///
/// Xu theo bảng thưởng mặc định: đúng ngay lần đầu ở bậc 1–2 là
/// 2 xu/câu, xong chặng +5 xu; câu ôn tập gấp đôi (không có ở đề
/// mới vì sổ ôn tập rỗng). Bậc chỉ đổi khi cửa sổ đủ 10 câu
/// (xem `LadderConfig.windowSize`) nên làm xong 1 chặng (5 câu)
/// bậc vẫn là 1.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/building/building_stats.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';

import 'play_stage_helper.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  late String setId;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 18, 8, 0));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    final service = DailySetService(
      dailySetsDao: db.dailySetsDao,
      reviewQueueDao: db.reviewQueueDao,
      ladderService: LadderService(
        attemptsDao: db.attemptsDao,
        skillProgressDao: db.skillProgressDao,
      ),
      clock: clock,
      random: Random(42),
    );
    final set = await service.getOrCreateTodaySet(childId: childId);
    setId = set.id;
  });

  Future<List<DailySetQuestion>> stageQuestions(int stageIndex) async {
    final set = await db.dailySetsDao.getDailySet(childId, clock.today());
    return db.dailySetsDao
        .readQuestions(set!)
        .sublist(stageIndex * 5, (stageIndex + 1) * 5);
  }

  Future<DailySetService> dailySetService() async => DailySetService(
    dailySetsDao: db.dailySetsDao,
    reviewQueueDao: db.reviewQueueDao,
    ladderService: LadderService(
      attemptsDao: db.attemptsDao,
      skillProgressDao: db.skillProgressDao,
    ),
    clock: clock,
    random: Random(7),
  );

  test('chưa làm: trạng thái chưa làm, đúng 0, xu 0, bậc 1', () async {
    final stats = await loadBuildingStats(
      db: db,
      childId: childId,
      stageIndex: 0,
    );

    expect(stats.status, StageStatus.notStarted);
    expect(stats.correctCount, 0);
    expect(stats.xuEarned, 0);
    expect(stats.rung, 1);
    expect(stats.extraStagesDone, 0);
    expect(stats.extraStageInProgress, isFalse);
  });

  test('làm xong chặng 0: đúng 5/5, xu 15, chặng 1 đang làm dở', () async {
    // Làm xong chặng 0 đúng ngay lần đầu cả 5 câu: 5 × 2 xu + 5 xu
    // xong chặng = 15 xu. Cho đồng hồ trôi 5 phút rồi làm dở 2 câu
    // chặng 1 để khóa cửa sổ thời gian không chồng lên nhau.
    await playStageCorrectly(
      db: db,
      childId: childId,
      questions: await stageQuestions(0),
      dailySetId: setId,
      stageIndex: 0,
    );
    clock.advance(const Duration(minutes: 5));
    await playStagePartially(
      db: db,
      childId: childId,
      questions: await stageQuestions(1),
      count: 2,
      dailySetId: setId,
      stageIndex: 1,
    );

    final stats0 = await loadBuildingStats(
      db: db,
      childId: childId,
      stageIndex: 0,
    );
    expect(stats0.status, StageStatus.done);
    expect(stats0.correctCount, 5);
    expect(stats0.xuEarned, 15);
    expect(stats0.rung, 1);

    final stats1 = await loadBuildingStats(
      db: db,
      childId: childId,
      stageIndex: 1,
    );
    expect(stats1.status, StageStatus.inProgress);
    expect(stats1.correctCount, 2);
    expect(stats1.xuEarned, 4);
    expect(stats1.rung, 1);
  });

  test('chặng tự chọn: 1 xong + 1 dở, không lẫn vào chặng ngày', () async {
    // Làm xong chặng ngày 0 trước để có số liệu đối chiếu.
    await playStageCorrectly(
      db: db,
      childId: childId,
      questions: await stageQuestions(0),
      dailySetId: setId,
      stageIndex: 0,
    );
    clock.advance(const Duration(minutes: 5));
    // Chặng tự chọn 1: làm hết 5 câu (đúng ngay) → 1 chặng xong.
    final service = await dailySetService();
    final extra1 = await service.buildExtraStage(
      childId: childId,
      strand: 'logic',
    );
    await playStageCorrectly(
      db: db,
      childId: childId,
      questions: extra1,
      clock: clock,
      advance: const Duration(minutes: 1),
    );
    clock.advance(const Duration(minutes: 5));
    // Chặng tự chọn 2: làm dở 2 câu → đang làm dở 1 chặng.
    final extra2 = await service.buildExtraStage(
      childId: childId,
      strand: 'logic',
    );
    await playStagePartially(
      db: db,
      childId: childId,
      questions: extra2,
      count: 2,
    );

    final stats = await loadBuildingStats(
      db: db,
      childId: childId,
      stageIndex: 0,
    );
    expect(stats.extraStagesDone, 1);
    expect(stats.extraStageInProgress, isTrue);
    // Xu chặng tự chọn (refId null) không lẫn vào chặng ngày:
    // chặng ngày 0 vẫn đúng 5, xu 15.
    expect(stats.status, StageStatus.done);
    expect(stats.correctCount, 5);
    expect(stats.xuEarned, 15);

    // Mảng khác không có chặng tự chọn nào.
    final other = await loadBuildingStats(
      db: db,
      childId: childId,
      stageIndex: 1,
    );
    expect(other.extraStagesDone, 0);
    expect(other.extraStageInProgress, isFalse);
  });

  test('vào lại chặng đang làm dở: chỉ tính lượt làm gần nhất', () async {
    // Làm dở 2 câu chặng 0, cho đồng hồ trôi, rồi làm lại từ đầu
    // chặng và làm xong cả 5 câu: thống kê chỉ tính lượt làm sau
    // (5 đúng, 15 xu), không cộng 2 câu đúng của lượt trước.
    await playStagePartially(
      db: db,
      childId: childId,
      questions: await stageQuestions(0),
      count: 2,
      dailySetId: setId,
      stageIndex: 0,
    );
    clock.advance(const Duration(minutes: 5));
    await playStageCorrectly(
      db: db,
      childId: childId,
      questions: await stageQuestions(0),
      dailySetId: setId,
      stageIndex: 0,
    );

    final stats = await loadBuildingStats(
      db: db,
      childId: childId,
      stageIndex: 0,
    );
    expect(stats.status, StageStatus.done);
    expect(stats.correctCount, 5);
    expect(stats.xuEarned, 15);
  });
}
