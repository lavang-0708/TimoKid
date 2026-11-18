/// Unit test cho T1-11: RewardConfig đọc từ settings.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/rewards/reward_config.dart';

AppDatabase openMemoryDb({Clock? clock}) => AppDatabase(
  executor: NativeDatabase.memory(),
  clock: clock ?? const SystemClock(),
);

void main() {
  group('RewardConfig', () {
    test('mặc định khớp JSON đã seed, fromJson rỗng bằng mặc định', () {
      final config = RewardConfig.defaults();
      expect(config.easy, 2);
      expect(config.medium, 3);
      expect(config.hard, 5);
      expect(config.stageCompleteBonusXu, 5);
      expect(config.dailySetCompleteBonusXu, 20);
      expect(config.dailySetCompleteBonusGems, 1);
      expect(config.masteryGem, 2);
      expect(RewardConfig.fromJson({}), config);
    });

    test('xu cơ số theo bậc', () {
      final config = RewardConfig.defaults();
      expect(config.baseXuForRung(1), 2);
      expect(config.baseXuForRung(2), 2);
      expect(config.baseXuForRung(3), 3);
      expect(config.baseXuForRung(4), 3);
      expect(config.baseXuForRung(5), 5);
      expect(config.baseXuForRung(6), 5);
    });

    test('xuForQuestion: đúng ngay, sau gợi ý, ôn tập', () {
      final config = RewardConfig.defaults();
      // Đúng ngay bậc 3–4: 3 xu.
      expect(
        config.xuForQuestion(rung: 3, correctFirstTry: true, isReview: false),
        3,
      );
      // Đúng sau gợi ý: 3 → 2 (làm tròn lên).
      expect(
        config.xuForQuestion(rung: 3, correctFirstTry: false, isReview: false),
        2,
      );
      // Câu ôn tập: gấp đôi.
      expect(
        config.xuForQuestion(rung: 3, correctFirstTry: true, isReview: true),
        6,
      );
      // Ôn tập + sau gợi ý: chia đôi làm tròn lên RỒI nhân đôi.
      // Bậc 3–4: 3 → 2 → 4 xu.
      expect(
        config.xuForQuestion(rung: 3, correctFirstTry: false, isReview: true),
        4,
      );
      // Bậc 5–6: 5 → 3 → 6 xu.
      expect(
        config.xuForQuestion(rung: 5, correctFirstTry: false, isReview: true),
        6,
      );
      expect(
        config.xuForQuestion(rung: 5, correctFirstTry: true, isReview: true),
        10,
      );
    });

    test('fromJson thiếu khóa thì lấy mặc định từng khóa', () {
      final config = RewardConfig.fromJson({'easy': 10});
      expect(config.easy, 10);
      expect(config.medium, 3);
      expect(config.hard, 5);
      expect(config.stageCompleteBonusXu, 5);
      expect(config.dailySetCompleteBonusXu, 20);
      expect(config.dailySetCompleteBonusGems, 1);
      expect(config.masteryGem, 2);
    });

    test('fromJson khóa không phải số thì lấy mặc định', () {
      final config = RewardConfig.fromJson({
        'easy': 'nhiều',
        'medium': 2.5,
        'daily_complete_gem': null,
      });
      expect(config.easy, 2);
      expect(config.medium, 3);
      expect(config.dailySetCompleteBonusGems, 1);
    });

    test('load đọc từ settings, đổi settings thì bảng đổi theo', () async {
      final db = openMemoryDb();
      addTearDown(db.close);
      await db.ensureSeeded();
      expect(await RewardConfig.load(db), RewardConfig.defaults());

      await db.settingsDao.setValue(
        key: 'rewards',
        value: jsonEncode({
          'easy': 1,
          'medium': 2,
          'hard': 4,
          'stage_complete': 7,
          'daily_complete_xu': 30,
          'daily_complete_gem': 2,
          'mastery_gem': 3,
        }),
      );
      final loaded = await RewardConfig.load(db);
      expect(loaded.easy, 1);
      expect(loaded.baseXuForRung(4), 2);
      expect(loaded.stageCompleteBonusXu, 7);
      expect(loaded.dailySetCompleteBonusXu, 30);
      expect(loaded.dailySetCompleteBonusGems, 2);
      expect(loaded.masteryGem, 3);
    });

    test('load settings thiếu hoặc JSON hỏng thì dùng mặc định', () async {
      final db = openMemoryDb();
      addTearDown(db.close);
      // Chưa seed: không có khóa rewards.
      expect(await RewardConfig.load(db), RewardConfig.defaults());

      await db.settingsDao.setValue(key: 'rewards', value: 'không phải json{');
      expect(await RewardConfig.load(db), RewardConfig.defaults());

      await db.settingsDao.setValue(key: 'rewards', value: '[1, 2]');
      expect(await RewardConfig.load(db), RewardConfig.defaults());
    });
  });
}
