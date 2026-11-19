/// Test chọn trứng + nở trứng đúng một lần (T2-03).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/features/onboarding/egg_service.dart';

void main() {
  late AppDatabase db;
  late String childId;
  late EggService service;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    service = EggService(db: db);
  });

  test('ban đầu: chưa chọn trứng, chưa nở, không có lần chờ', () async {
    expect(await service.selectedEgg(childId), isNull);
    expect(await service.isHatched(childId), isFalse);
    expect(await service.isHatchPending(childId), isFalse);
  });

  test('chọn trứng lưu đúng loài; loài lạ thì ném lỗi', () async {
    await service.selectEgg(childId: childId, species: 'rabbit');
    expect(await service.selectedEgg(childId), 'rabbit');
    expect(
      () => service.selectEgg(childId: childId, species: 'fox'),
      throwsArgumentError,
    );
  });

  test('chưa chọn trứng thì xong chặng không đặt cờ chờ nở', () async {
    expect(await service.noteStageCompleted(childId), isFalse);
    expect(await service.isHatchPending(childId), isFalse);
  });

  test(
    'đã chọn trứng: xong chặng đầu đặt cờ chờ, xong chặng sau không đặt lại',
    () async {
      await service.selectEgg(childId: childId, species: 'dog');
      expect(await service.noteStageCompleted(childId), isTrue);
      expect(await service.isHatchPending(childId), isTrue);
      // Gọi lại (vd chặng tiếp theo xong khi bé chưa xem màn nở):
      // cờ đã chờ rồi nên không đặt lại.
      expect(await service.noteStageCompleted(childId), isFalse);
    },
  );

  test(
    'xem xong màn nở: đã nở, hết chờ; xong chặng sau không nở lại',
    () async {
      await service.selectEgg(childId: childId, species: 'cat');
      await service.noteStageCompleted(childId);
      await service.consumeHatchCelebration(childId);
      expect(await service.isHatched(childId), isTrue);
      expect(await service.isHatchPending(childId), isFalse);
      expect(await service.noteStageCompleted(childId), isFalse);
      // Gọi lại cũng an toàn.
      await service.consumeHatchCelebration(childId);
      expect(await service.isHatched(childId), isTrue);
    },
  );

  test('trứng lạ đã lưu trong DB thì selectedEgg trả null', () async {
    await db.settingsDao.setValue(
      childId: childId,
      key: EggService.selectedEggKey,
      value: 'fox',
    );
    expect(await service.selectedEgg(childId), isNull);
  });
}
