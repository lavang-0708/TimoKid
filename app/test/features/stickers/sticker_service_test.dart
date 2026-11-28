/// Sổ sticker (T4-03): mỗi dạng thành thạo một sticker + 2 kim cương, cấp
/// một lần (idempotent), chúc mừng một lần; mọi dạng có tên ngắn.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/features/questions/question_registry.dart';
import 'package:timokid/features/stickers/form_labels.dart';
import 'package:timokid/features/stickers/sticker_config.dart';
import 'package:timokid/features/stickers/sticker_service.dart';

void main() {
  late AppDatabase db;
  late String childId;
  late StickerService service;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    service = StickerService(db: db);
  });

  Future<void> master(String formId) => db.skillProgressDao.setFormMastered(
    childId: childId,
    formId: formId,
    mastered: true,
  );

  Future<int> gems() =>
      db.walletDao.balance(childId: childId, currency: Currency.gem);

  test('mọi dạng bài đều có tên ngắn trên sticker', () {
    for (final g in allQuestionGenerators) {
      expect(formLabels.containsKey(g.formId), isTrue, reason: g.formId);
      expect(
        formLabels[g.formId]!.length,
        lessThanOrEqualTo(maxFormLabelLength),
      );
    }
    // Không có tên thừa cho dạng không tồn tại.
    final known = allQuestionGenerators.map((g) => g.formId).toSet();
    expect(formLabels.keys.toSet().difference(known), isEmpty);
  });

  test('90 dạng chia theo 5 mảng khớp bảng đếm của ngân hàng câu hỏi', () {
    expect(allFormIds, hasLength(90));
    for (final s in Strand.all) {
      expect(formIdsOfStrand(s), hasLength(generatorCountByTopic[s]!));
      expect(formIdsOfStrand(s).every((f) => strandOfForm(f) == s), isTrue);
    }
  });

  test(
    'chưa thành thạo dạng nào thì chưa có sticker, chưa có kim cương',
    () async {
      expect(await service.awardPending(childId), isEmpty);
      expect((await service.progress(childId)).total, 0);
      expect(await gems(), 0);
    },
  );

  test(
    'thành thạo một dạng: một sticker + 2 kim cương, ledger có refId',
    () async {
      await master('logic.age');
      final awarded = await service.awardPending(childId);
      expect(awarded, ['logic.age']);
      expect(await service.earned(childId), {'logic.age'});
      expect(await gems(), StickerConfig.gemsPerSticker);
      expect(
        await db.walletDao.hasEntryWithRefId(
          childId: childId,
          refId: 'sticker:logic.age',
        ),
        isTrue,
      );
    },
  );

  test('idempotent: gọi lại nhiều lần không cộng kim cương thêm', () async {
    await master('geo.perim');
    await master('comb.flag');
    expect(await service.awardPending(childId), hasLength(2));
    expect(await gems(), 4);
    for (var i = 0; i < 3; i++) {
      expect(await service.awardPending(childId), isEmpty);
    }
    expect(await gems(), 4);
    final entries = await db.walletDao.getEntries(childId);
    expect(
      entries.where((e) => e.reason == StickerConfig.ledgerReason),
      hasLength(2),
    );
  });

  test(
    'mất khóa settings mà ví còn dòng: cấp lại sticker nhưng không cộng trùng',
    () async {
      await master('number.kth');
      await service.awardPending(childId);
      await db.settingsDao.deleteSetting(
        childId: childId,
        key: StickerConfig.earnedKey('number.kth'),
      );
      expect(await service.earned(childId), isEmpty);
      expect(await service.awardPending(childId), ['number.kth']);
      expect(await gems(), 2);
    },
  );

  test('dạng lạ (không còn trong ngân hàng) bị bỏ qua', () async {
    await master('khong.ton.tai');
    expect(await service.awardPending(childId), isEmpty);
    expect(await gems(), 0);
  });

  test('sticker của bé này không lẫn sang bé khác', () async {
    await master('logic.age');
    await service.awardPending(childId);
    final other = (await db.childrenDao.createChild(name: 'Bé hai')).id;
    expect(await service.earned(other), isEmpty);
    expect(
      await db.walletDao.balance(childId: other, currency: Currency.gem),
      0,
    );
  });

  test('tiến độ theo mảng N/M', () async {
    for (final f in ['logic.age', 'logic.queue', 'geo.perim']) {
      await master(f);
    }
    await service.awardPending(childId);
    final p = await service.progress(childId);
    expect(p.total, 3);
    expect(p.earnedInStrand(Strand.logic), 2);
    expect(p.totalInStrand(Strand.logic), 19);
    expect(p.earnedInStrand(Strand.geo), 1);
    expect(p.earnedInStrand(Strand.comb), 0);
  });

  test(
    'chúc mừng: chưa mừng thì có trong danh sách, mừng rồi thì hết',
    () async {
      await master('logic.queue');
      await master('logic.age');
      await service.awardPending(childId);
      // Theo thứ tự trong sổ (age trước queue).
      expect(await service.pendingCelebrations(childId), [
        'logic.age',
        'logic.queue',
      ]);
      await service.markSeen(childId, ['logic.age']);
      expect(await service.pendingCelebrations(childId), ['logic.queue']);
      await service.markSeen(childId, ['logic.queue']);
      expect(await service.pendingCelebrations(childId), isEmpty);
      // Sticker mới sau đó lại có trong danh sách.
      await master('arith.quick');
      await service.awardPending(childId);
      expect(await service.pendingCelebrations(childId), ['arith.quick']);
    },
  );
}
