/// Test câu hỏi tự soạn (T5-03) với cờ BẬT: kiểm tra dòng, chọn câu, trộn
/// vào đề ngày (tối đa 1 câu mỗi chặng, đúng mảng và bậc, child_id null =
/// mọi bé), trả lời (điền số và trắc nghiệm) với formId của attempts là
/// `custom:<id>`, không vào sổ ôn tập, và tải về từ server theo mốc. Cờ tắt
/// thì đề ngày y như cũ.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/models.dart';
import 'package:timokid/core/database/tables.dart' hide AnswerType;
import 'package:timokid/core/sync/session_store.dart';
import 'package:timokid/core/sync/sync_config.dart';
import 'package:timokid/core/sync/sync_engine.dart';
import 'package:timokid/core/time/clock.dart';
import 'package:timokid/features/custom_questions/custom_question_service.dart';
import 'package:timokid/features/daily_set/daily_set_config.dart';
import 'package:timokid/features/daily_set/daily_set_service.dart';
import 'package:timokid/features/ladder/ladder_service.dart';
import 'package:timokid/features/math/math_session.dart';
import 'package:timokid/features/questions/question.dart';

import '../../core/sync/fake_neon.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late FakeClock clock;
  late AppDatabase db;
  late String childId;
  var seq = 0;

  setUp(() async {
    clock = FakeClock(DateTime(2027, 3, 10, 8));
    db = AppDatabase(executor: NativeDatabase.memory(), clock: clock);
    addTearDown(db.close);
    childId = await db.ensureSeeded();
  });

  Future<String> addQ({
    String strand = Strand.arith,
    int rung = 1,
    String? child,
    String text = 'Hai cộng ba bằng mấy?',
    String answer = '5',
    List<String>? choices,
    bool active = true,
    String expl = '',
    String? en,
  }) async {
    final id = 'cq${++seq}';
    clock.advance(const Duration(seconds: 1));
    await db.customQuestionsDao.upsertFromServer(
      CustomQuestionsCompanion.insert(
        id: id,
        childId: Value(child),
        strand: strand,
        rung: rung,
        textVi: text,
        textEn: Value(en),
        answer: answer,
        choicesJson: Value(choices == null ? null : jsonEncode(choices)),
        explanationVi: Value(expl),
        active: Value(active),
        createdAt: clock.now(),
        updatedAt: clock.now(),
      ),
    );
    return id;
  }

  DailySetService daily({bool custom = true, Random? random}) =>
      DailySetService(
        dailySetsDao: db.dailySetsDao,
        reviewQueueDao: db.reviewQueueDao,
        ladderService: LadderService(
          attemptsDao: db.attemptsDao,
          skillProgressDao: db.skillProgressDao,
        ),
        clock: clock,
        random: random,
        customQuestionsDao: db.customQuestionsDao,
        customQuestions: custom,
      );

  Future<List<DailySetQuestion>> todayQuestions({bool custom = true}) async {
    final set = await daily(custom: custom)
        .getOrCreateTodaySet(childId: childId);
    return db.dailySetsDao.readQuestions(set);
  }

  group('cờ và cấu hình', () {
    test('cờ customQuestionsEnabled mặc định TẮT (chờ chạy SQL 0003)', () {
      expect(customQuestionsEnabled, isFalse);
    });
  });

  group('kiểm tra dòng đã tải', () {
    CustomQuestion row({
      String answer = '5',
      String? choices,
      String text = 'Đề',
    }) => CustomQuestion(
      id: 'x',
      childId: null,
      strand: 'arith',
      rung: 1,
      grade: 2,
      textVi: text,
      textEn: null,
      answer: answer,
      choicesJson: choices,
      explanationVi: '',
      active: true,
      createdAt: DateTime(2027),
      updatedAt: DateTime(2027),
    );

    test('điền số: số nguyên không âm tối đa 6 chữ số', () {
      expect(snapshotFromRow(row()), isNotNull);
      for (final a in ['', '-1', '1.5', 'abc', '1234567']) {
        expect(snapshotFromRow(row(answer: a)), isNull, reason: a);
      }
    });

    test('trắc nghiệm: 2-6 lựa chọn khác nhau, đáp án là một trong số đó', () {
      expect(
        snapshotFromRow(row(answer: 'Chim', choices: '["Cá","Chim"]')),
        isNotNull,
      );
      expect(
        snapshotFromRow(row(answer: 'Gà', choices: '["Cá","Chim"]')),
        isNull,
      );
      expect(snapshotFromRow(row(answer: 'Cá', choices: '["Cá"]')), isNull);
      expect(
        snapshotFromRow(row(answer: 'Cá', choices: '["Cá","Cá"]')),
        isNull,
      );
      expect(
        snapshotFromRow(row(answer: 'a', choices: '[1,2,3,4,5,6,7]')),
        isNull,
      );
      expect(
        snapshotFromRow(row(answer: 'a', choices: 'không phải json')),
        isNull,
      );
      expect(snapshotFromRow(row(text: '  ')), isNull);
    });
  });

  group('chọn câu', () {
    test('đúng mảng, đúng bậc, đang bật, đúng bé', () async {
      final other = (await db.childrenDao.createChild(name: 'Bé hai')).id;
      final good = await addQ(rung: 2);
      await addQ(rung: 3); // sai bậc
      await addQ(rung: 2, strand: Strand.geo); // sai mảng
      await addQ(rung: 2, active: false); // đã tắt
      await addQ(rung: 2, child: other); // của bé khác
      final svc = CustomQuestionService(db: db, random: Random(1));
      final pick = await svc.pickForStage(
        childId: childId,
        strand: Strand.arith,
        rung: 2,
      );
      expect(pick!.id, good);
      expect(
        await svc.pickForStage(childId: childId, strand: Strand.arith, rung: 1),
        isNull,
      );
    });

    test('child_id null dùng cho mọi bé; câu riêng chỉ cho bé đó', () async {
      final other = (await db.childrenDao.createChild(name: 'Bé hai')).id;
      final all = await addQ();
      final mine = await addQ(child: childId, text: 'Câu riêng');
      final svc = CustomQuestionService(db: db);
      Future<Set<String>> seen(String kid) async {
        final out = <String>{};
        for (var i = 0; i < 30; i++) {
          final p = await CustomQuestionService(
            db: db,
            random: Random(i),
          ).pickForStage(childId: kid, strand: Strand.arith, rung: 1);
          if (p != null) out.add(p.id);
        }
        return out;
      }

      expect(await seen(childId), {all, mine});
      expect(await seen(other), {all});
      expect(svc, isNotNull);
    });

    test('ưu tiên câu bé đã làm ít nhất', () async {
      final a = await addQ(text: 'A');
      final b = await addQ(text: 'B');
      for (var i = 0; i < 2; i++) {
        await db.attemptsDao.recordAttempt(
          childId: childId,
          formId: customFormId(a),
          strand: Strand.arith,
          level: 1,
          rung: 1,
          answerType: AnswerType.number.name,
          correctFirstTry: true,
          attemptsCount: 1,
          durationMs: 500,
        );
      }
      for (var i = 0; i < 20; i++) {
        final p = await CustomQuestionService(
          db: db,
          random: Random(i),
        ).pickForStage(childId: childId, strand: Strand.arith, rung: 1);
        expect(p!.id, b);
      }
    });
  });

  group('trộn vào đề ngày', () {
    test('cờ tắt: không có câu tự soạn dù có dữ liệu', () async {
      await addQ();
      final qs = await todayQuestions(custom: false);
      expect(qs, hasLength(DailySetConfig.totalQuestions));
      expect(qs.any((q) => q.isCustom), isFalse);
    });

    test('không có câu nào: đề không đổi (25 câu, không custom)', () async {
      final qs = await todayQuestions();
      expect(qs, hasLength(25));
      expect(qs.any((q) => q.isCustom), isFalse);
    });

    test(
      'mảng có câu đúng bậc 1 thì chặng đó có đúng 1 câu tự soạn ở câu 3',
      () async {
        // Bé mới: bậc 1 mọi mảng. Nhiều câu cùng mảng vẫn chỉ 1 câu mỗi chặng.
        for (var i = 0; i < 4; i++) {
          await addQ(strand: Strand.arith, text: 'Số học $i');
        }
        final geo = await addQ(strand: Strand.geo, answer: '4');
        final qs = await todayQuestions();
        expect(qs, hasLength(25));
        final customs = qs.where((q) => q.isCustom).toList();
        expect(customs, hasLength(2));
        for (final strand in Strand.all) {
          final stage = qs.where((q) => q.strand == strand).toList();
          expect(stage, hasLength(5));
          final n = stage.where((q) => q.isCustom).length;
          expect(n, (strand == Strand.arith || strand == Strand.geo) ? 1 : 0);
          if (n == 1) {
            expect(stage[DailySetConfig.customSlotIndex].isCustom, isTrue);
            // Không đụng câu ôn tập (câu 4) hay các câu khác.
            expect(stage[DailySetConfig.reviewSlotIndex].isCustom, isFalse);
          }
        }
        final g = customs.firstWhere((q) => q.strand == Strand.geo);
        expect(g.formId, customFormId(geo));
        expect(g.rung, 1);
        expect(g.answerType, 'number');
        expect(g.level, 1);
      },
    );

    test('câu bậc khác bậc hiện tại của bé thì không được trộn', () async {
      await addQ(rung: 4);
      expect((await todayQuestions()).any((q) => q.isCustom), isFalse);
    });

    test('theo bậc hiện tại: bé bậc 3 ở Số học nhận câu bậc 3', () async {
      await db.skillProgressDao.setStrandRung(
        childId: childId,
        strand: Strand.arith,
        rung: 3,
      );
      await addQ(rung: 1, text: 'bậc 1');
      final id3 = await addQ(rung: 3, text: 'bậc 3', answer: '9');
      final qs = await todayQuestions();
      final c = qs.singleWhere((q) => q.isCustom);
      expect(c.formId, customFormId(id3));
      expect(c.rung, 3);
    });

    test(
      'đề đã lưu tự đủ: đọc lại vẫn có nội dung, sửa câu sau đó không đổi đề',
      () async {
        final id = await addQ(
          text: 'Gốc',
          en: 'Original',
          answer: 'Chim',
          choices: ['Cá', 'Chim'],
          expl: 'Chim bay.',
        );
        final first = (await todayQuestions()).singleWhere((q) => q.isCustom);
        expect(first.answerType, 'choice');
        // Bố sửa rồi tắt câu trên server.
        await db.customQuestionsDao.upsertFromServer(
          CustomQuestionsCompanion.insert(
            id: id,
            strand: Strand.arith,
            rung: 1,
            textVi: 'Đã sửa',
            answer: 'Cá',
            choicesJson: Value(jsonEncode(['Cá', 'Chim'])),
            active: const Value(false),
            createdAt: clock.now(),
            updatedAt: clock.now().add(const Duration(hours: 1)),
          ),
        );
        final again = (await todayQuestions()).singleWhere((q) => q.isCustom);
        expect(again.custom!.textVi, 'Gốc');
        expect(again.custom!.textEn, 'Original');
        expect(again.custom!.answer, 'Chim');
        expect(again.custom!.choices, ['Cá', 'Chim']);
        expect(again.custom!.explanationVi, 'Chim bay.');
        // Ngày sau: câu đã tắt không được trộn nữa.
        clock.set(DateTime(2027, 3, 11, 8));
        expect((await todayQuestions()).any((q) => q.isCustom), isFalse);
      },
    );

    test('JSON của DailySetQuestion giữ nội dung câu tự soạn', () {
      const q = DailySetQuestion(
        formId: 'custom:z',
        strand: 'arith',
        level: 1,
        rung: 1,
        answerType: 'choice',
        seed: 7,
        custom: CustomQuestionSnapshot(
          id: 'z',
          textVi: 'Đề',
          answer: 'B',
          choices: ['A', 'B'],
        ),
      );
      final back = DailySetQuestion.fromJson(
        jsonDecode(jsonEncode(q.toJson())) as Map<String, Object?>,
      );
      expect(back.isCustom, isTrue);
      expect(back.custom!.choices, ['A', 'B']);
      expect(back.formId, 'custom:z');
      // Câu thường không có khóa custom (đề cũ đọc lại như cũ).
      expect(
        const DailySetQuestion(
          formId: 'logic.age',
          strand: 'logic',
          level: 1,
          rung: 1,
          answerType: 'choice',
        ).toJson().containsKey('custom'),
        isFalse,
      );
    });
  });

  group('trả lời câu tự soạn', () {
    Future<StageSession> sessionFor(
      List<DailySetQuestion> stage, {
      String? setId,
      int index = -1,
    }) async {
      final s = StageSession(
        db: db,
        childId: childId,
        dailySetId: setId,
        stageIndex: index,
        questions: stage,
      );
      return s;
    }

    DailySetQuestion spec(String id, {Random? r}) {
      return CustomQuestionService(db: db, random: r ?? Random(3)).build(
        custom: CustomQuestionSnapshot(
          id: id,
          textVi: 'Hai cộng ba bằng mấy?',
          answer: '5',
        ),
        strand: Strand.arith,
        rung: 1,
      );
    }

    test(
      'điền số: đúng ngay lần đầu, ghi attempts với formId custom:<id>',
      () async {
        final s = await sessionFor([spec('n1')]);
        final r = s.resolved.single;
        expect(r.displayType, AnswerType.number);
        expect(r.question.answer, 5);
        expect(r.question.questionVi, 'Hai cộng ba bằng mấy?');
        expect(r.question.questionEn, '');
        s.appendDigit('5');
        expect(await s.submitNumber(), isTrue);
        final a = (await db.attemptsDao.getAttemptsForChild(childId)).single;
        expect(a.formId, 'custom:n1');
        expect(a.correctFirstTry, isTrue);
        expect(a.strand, Strand.arith);
        expect(a.answerType, AnswerType.number.name);
        expect(s.xuEarned, greaterThan(0));
      },
    );

    test('điền số sai hai lần: hiện gợi ý rồi lời giải mặc định, không vào sổ ôn tập', () async {
      final s = await sessionFor([spec('n2')]);
      s.appendDigit('4');
      expect(await s.submitNumber(), isFalse);
      expect(s.state, QuestionState.hint);
      s.deleteDigit();
      s.appendDigit('6');
      expect(await s.submitNumber(), isFalse);
      expect(s.state, QuestionState.solution);
      expect(s.current.question.explanationVi, 'Đáp án đúng là 5.');
      final a = (await db.attemptsDao.getAttemptsForChild(childId)).single;
      expect(a.formId, 'custom:n2');
      expect(a.correctFirstTry, isFalse);
      expect(await db.select(db.reviewQueue).get(), isEmpty);
      expect(
        await db
            .select(db.skillProgress)
            .get()
            .then((l) => l.where((p) => p.scope == 'form')),
        isEmpty,
      );
    });

    test(
      'trắc nghiệm: đúng vị trí sau khi trộn; lời giải của bố hiện khi sai',
      () async {
        final custom = CustomQuestionSnapshot(
          id: 'c1',
          textVi: 'Con vật nào biết bay?',
          textEn: 'Which animal can fly?',
          answer: 'Chim',
          choices: const ['Cá', 'Chim', 'Mèo', 'Chó'],
          explanationVi: 'Chim có cánh.',
        );
        final specChoice = CustomQuestionService(
          db: db,
          random: Random(9),
        ).build(custom: custom, strand: Strand.logic, rung: 1);
        expect(specChoice.answerType, 'choice');
        final s = await sessionFor([specChoice]);
        final r = s.resolved.single;
        expect(r.displayType, AnswerType.choice);
        expect(r.choiceTextsVi.toSet(), {'Cá', 'Chim', 'Mèo', 'Chó'});
        expect(r.choiceTextsVi[r.correctDisplayIndex], 'Chim');
        expect(r.question.questionEn, 'Which animal can fly?');
        // Chọn sai hai lần.
        final wrong = (r.correctDisplayIndex + 1) % 4;
        expect(await s.submitChoice(wrong), isFalse);
        expect(await s.submitChoice(wrong), isFalse);
        expect(s.current.question.explanationVi, 'Chim có cánh.');
        final a = (await db.attemptsDao.getAttemptsForChild(childId)).single;
        expect(a.formId, 'custom:c1');
        expect(a.answerType, AnswerType.choice.name);
      },
    );

    test('trắc nghiệm đúng ngay: tính đúng ngay lần đầu', () async {
      final specChoice = CustomQuestionService(db: db, random: Random(2)).build(
        custom: const CustomQuestionSnapshot(
          id: 'c2',
          textVi: 'Chọn số lớn nhất',
          answer: '9',
          choices: ['3', '9', '4'],
        ),
        strand: Strand.number,
        rung: 1,
      );
      final s = await sessionFor([specChoice]);
      expect(await s.submitChoice(s.current.correctDisplayIndex), isTrue);
      expect(s.firstTryCorrectCount, 1);
    });

    test('cả chặng đề ngày có câu tự soạn chạy trọn tới hết', () async {
      await addQ(text: 'Câu tự soạn', answer: '8');
      final set = await daily().getOrCreateTodaySet(childId: childId);
      final qs = db.dailySetsDao
          .readQuestions(set)
          .sublist(
            Strand.all.indexOf(Strand.arith) * 5,
            Strand.all.indexOf(Strand.arith) * 5 + 5,
          );
      expect(qs.where((q) => q.isCustom), hasLength(1));
      final s = await sessionFor(
        qs,
        setId: set.id,
        index: Strand.all.indexOf(Strand.arith),
      );
      await s.markStageInProgress();
      for (var i = 0; i < 5; i++) {
        final r = s.current;
        if (r.displayType == AnswerType.choice) {
          await s.submitChoice(r.correctDisplayIndex);
        } else {
          for (final ch in '${r.question.answer}'.split('')) {
            s.appendDigit(ch);
          }
          await s.submitNumber();
        }
        await s.next();
      }
      expect(s.finished, isTrue);
      final attempts = await db.attemptsDao.getAttemptsForChild(childId);
      expect(attempts, hasLength(5));
      expect(
        attempts.where((a) => a.formId.startsWith('custom:')),
        hasLength(1),
      );
    });
  });

  group('tải về từ server', () {
    late FakeNeon neon;
    SyncEngine engine({bool custom = true}) => SyncEngine(
      db: db,
      client: neon.signedInClient(MemorySessionStore()),
      customQuestions: custom,
      nowUtc: () => DateTime.utc(2027, 3, 10, 9),
    );

    Map<String, Object?> serverRow(
      String id,
      String stamp, {
      String answer = '5',
      Object? choices,
      bool active = true,
      String? child,
    }) => {
      'id': id,
      'child_id': child,
      'strand': 'arith',
      'rung': 2,
      'grade': 2,
      'text_vi': 'Đề $id',
      'text_en': null,
      'answer': answer,
      'choices': choices,
      'explanation_vi': '',
      'active': active,
      'created_at': stamp,
      'updated_at': stamp,
    };

    setUp(() => neon = FakeNeon());

    test('cờ tắt: không gọi bảng custom_questions', () async {
      neon.table('custom_questions')['a'] = serverRow(
        'a',
        '2027-03-10T08:00:00+00:00',
      );
      final r = await engine(custom: false).syncOnce();
      expect(r.pulledCustomQuestions, 0);
      expect(neon.log.where((l) => l.table == 'custom_questions'), isEmpty);
      expect(await db.customQuestionsDao.getAll(), isEmpty);
    });

    test(
      'cờ bật: tải theo mốc updated_at, lần sau chỉ tải dòng mới hơn',
      () async {
        neon.table('custom_questions')['a'] = serverRow(
          'a',
          '2027-03-10T08:00:00.5+00:00',
          child: childId,
        );
        neon.table('custom_questions')['b'] = serverRow(
          'b',
          '2027-03-10T08:01:00+00:00',
          answer: 'Chim',
          choices: ['Cá', 'Chim'],
        );
        final r1 = await engine().syncOnce();
        expect(r1.pulledCustomQuestions, 2);
        final rows = {
          for (final q in await db.customQuestionsDao.getAll()) q.id: q,
        };
        expect(rows['a']!.childId, childId);
        expect(rows['b']!.choicesJson, jsonEncode(['Cá', 'Chim']));
        expect(
          await db.settingsDao.getValue(key: customQuestionsMarkKey),
          '"2027-03-10T08:01:00+00:00"',
        );
        neon.log.clear();
        expect((await engine().syncOnce()).pulledCustomQuestions, 0);
        expect(
          neon.log
              .where((l) => l.method == 'GET' && l.table == 'custom_questions')
              .single
              .query['updated_at'],
          'gt.2027-03-10T08:01:00+00:00',
        );
        // Bố tắt câu a: máy nhận active = false.
        neon.table('custom_questions')['a'] = {
          ...serverRow('a', '2027-03-10T09:00:00+00:00', child: childId),
          'active': false,
        };
        expect((await engine().syncOnce()).pulledCustomQuestions, 1);
        expect((await db.customQuestionsDao.getById('a'))!.active, isFalse);
      },
    );

    test(
      'dòng thiếu trường bắt buộc bị bỏ qua, không làm hỏng lượt đồng bộ',
      () async {
        neon.table('custom_questions')['bad'] = {
          ...serverRow('bad', '2027-03-10T08:00:00+00:00'),
          'text_vi': null,
        };
        neon.table('custom_questions')['ok'] = serverRow(
          'ok',
          '2027-03-10T08:00:01+00:00',
        );
        final r = await engine().syncOnce();
        expect(r.outcome, SyncOutcome.ok);
        expect((await db.customQuestionsDao.getAll()).map((q) => q.id), ['ok']);
      },
    );

    test('đồng bộ không gửi custom_questions lên server', () async {
      await addQ();
      await engine().syncOnce();
      expect(
        neon.log.where(
          (l) => l.table == 'custom_questions' && l.method != 'GET',
        ),
        isEmpty,
      );
    });
  });
}
