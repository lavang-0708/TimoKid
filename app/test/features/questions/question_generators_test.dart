import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/questions/question.dart';
import 'package:timokid/features/questions/question_registry.dart';

import 'question_solvers.dart';

/// Test nghiệm thu T1-05 (theo PLAN.md và điểm chốt (d) ngày 17/11):
///
/// - Với mỗi dạng và mỗi mức hỗ trợ: sinh 500 câu bằng 500 seed khác nhau.
/// - Đáp án khớp với hàm giải độc lập trong `question_solvers.dart`
///   (tính lại từ tham số câu hỏi, không gọi code sinh câu).
/// - Câu điền số: đáp án là số dương; đúng 3 đáp án nhiễu, khác nhau và
///   khác đáp án.
/// - Câu trắc nghiệm (choiceOnly): chỉ số đáp án hợp lệ; đủ số lựa chọn
///   của dạng và các lựa chọn khác nhau; lựa chọn đúng khớp với hàm giải
///   độc lập, cả VI và EN.
/// - Chung: đề không còn ký tự mẫu như `{`, `null`, `NaN`; lời giải có
///   chứa đáp án.
void main() {
  group('registry', () {
    test('đủ 90 dạng bài, không trùng formId', () {
      expect(allQuestionGenerators.length, 90);
      final ids = allQuestionGenerators.map((g) => g.formId).toList();
      expect(ids.toSet().length, 90);
      for (final entry in generatorCountByTopic.entries) {
        expect(
          allQuestionGenerators.where((g) => g.topic == entry.key).length,
          entry.value,
          reason: 'mảng ${entry.key} phải có ${entry.value} dạng',
        );
      }
    });

    test('questionGeneratorFor tìm được mọi dạng', () {
      for (final generator in allQuestionGenerators) {
        expect(questionGeneratorFor(generator.formId), same(generator));
      }
      expect(questionGeneratorFor('logic.khong-co'), isNull);
    });

    test('mức không hỗ trợ thì báo lỗi', () {
      for (final generator in allQuestionGenerators) {
        for (var level = 1; level <= 3; level++) {
          if (generator.supportedLevels.contains(level)) continue;
          expect(
            () => generator.generate(level, Random(0)),
            throwsArgumentError,
            reason: '${generator.formId} không hỗ trợ mức $level',
          );
        }
      }
    });
  });

  group('sinh câu theo dạng và mức', () {
    for (final generator in allQuestionGenerators) {
      for (final level in generator.supportedLevels) {
        test('${generator.formId} mức $level: 500 seed', () {
          for (var seed = 0; seed < 500; seed++) {
            final reason = '${generator.formId} mức $level seed $seed';
            final q = generator.generate(level, Random(seed));
            expect(q.formId, generator.formId, reason: reason);
            expect(q.topic, generator.topic, reason: reason);
            expect(q.difficulty, level, reason: reason);
            expect(q.keywords, isNotEmpty, reason: reason);

            // Đề, gợi ý và lời giải không còn ký tự mẫu.
            for (final text in [
              q.questionVi,
              q.questionEn,
              q.hintVi,
              q.hintEn,
              q.explanationVi,
              q.explanationEn,
            ]) {
              expect(text.contains('{'), isFalse, reason: reason);
              expect(text.contains('null'), isFalse, reason: reason);
              expect(text.contains('NaN'), isFalse, reason: reason);
            }

            final expected = solveQuestion(q);
            if (q.isChoice) {
              _checkChoice(q, expected, reason);
            } else {
              _checkNumber(q, expected, reason);
            }
          }
        });
      }
    }
  });
}

/// Số lựa chọn kỳ vọng của từng dạng trắc nghiệm.
int _expectedChoiceCount(Question q) {
  switch (q.formId) {
    case 'logic.weekday':
      return 4;
    case 'number.parityrule':
      return 3;
    case 'logic.compare':
      // Số người trong chuỗi so sánh: mức 1 -> 3, mức 2 -> 4, mức 3 -> 5.
      return q.difficulty + 2;
    default:
      throw StateError('Dạng ${q.formId} không phải câu trắc nghiệm');
  }
}

void _checkNumber(Question q, int expected, String reason) {
  expect(q.answerType, AnswerType.number, reason: reason);
  expect(q.choices, isEmpty, reason: reason);
  // Đáp án khớp với hàm giải độc lập và là số dương.
  expect(q.answer, expected, reason: reason);
  expect(q.answer, greaterThan(0), reason: reason);
  // Đúng 3 đáp án nhiễu, khác nhau và khác đáp án, đều là số dương.
  expect(q.distractors.length, 3, reason: reason);
  expect(q.distractors.toSet().length, 3, reason: reason);
  for (final d in q.distractors) {
    expect(d, greaterThan(0), reason: reason);
    expect(d, isNot(q.answer), reason: reason);
  }
  // Lời giải có chứa đáp án.
  expect(q.explanationVi.contains('${q.answer}'), isTrue, reason: reason);
}

void _checkChoice(Question q, int expectedIndex, String reason) {
  expect(q.answerType, AnswerType.choice, reason: reason);
  expect(q.distractors, isEmpty, reason: reason);
  // Đủ số lựa chọn của dạng, các lựa chọn khác nhau.
  expect(q.choices.length, _expectedChoiceCount(q), reason: reason);
  expect(
    q.choices.map((c) => c.vi).toSet().length,
    q.choices.length,
    reason: reason,
  );
  expect(
    q.choices.map((c) => c.en).toSet().length,
    q.choices.length,
    reason: reason,
  );
  // Chỉ số đáp án hợp lệ và khớp với hàm giải độc lập (cả VI và EN,
  // vì hàm giải tìm chỉ số bằng cách so khớp cả hai ngôn ngữ).
  expect(q.answer, greaterThanOrEqualTo(0), reason: reason);
  expect(q.answer, lessThan(q.choices.length), reason: reason);
  expect(q.answer, expectedIndex, reason: reason);
  // Lời giải có chứa đáp án (tên ngày / tên người / "số lẻ" / "số chẵn").
  final correct = q.choices[q.answer].vi.toLowerCase();
  expect(
    q.explanationVi.toLowerCase().contains(correct),
    isTrue,
    reason: reason,
  );
}
