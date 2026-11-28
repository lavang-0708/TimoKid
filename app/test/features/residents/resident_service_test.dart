/// Chọn lời thoại cư dân theo ngày (T4-02): xác định (cùng đầu vào cùng
/// câu), không phụ thuộc mã bé, đổi theo ngày/nhóm, có thay `{ten}`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/residents/resident_content.dart';
import 'package:timokid/features/residents/resident_service.dart';

void main() {
  final book = ResidentBook.fromJsonString(
    File('assets/content/residents.json').readAsStringSync(),
  );
  final knight = book.byId('hiep_si_sang')!;

  test('cùng ngày + cư dân + nhóm thì luôn cùng một câu', () {
    final a = pickResidentLine(
      knight,
      LineKind.ask,
      date: '2026-11-18',
      childName: 'An',
    );
    for (var i = 0; i < 20; i++) {
      expect(
        pickResidentLine(
          knight,
          LineKind.ask,
          date: '2026-11-18',
          childName: 'An',
        ),
        a,
      );
    }
  });

  test('giá trị cố định (khóa hạt giống, golden không đổi)', () {
    // FNV-1a của chuỗi hạt giống phải ổn định giữa các lần chạy/nền tảng.
    expect(stableHash('abc'), 0x1A47E90B);
    expect(
      residentSeed('2026-11-18', 'hiep_si_sang', LineKind.ask),
      '2026-11-18|hiep_si_sang|ask|',
    );
  });

  test('câu chọn thuộc đúng nhóm của cư dân và đã thay {ten}', () {
    for (final r in book.residents) {
      for (final kind in LineKind.values) {
        for (var day = 1; day <= 28; day++) {
          final date = '2026-11-${day.toString().padLeft(2, '0')}';
          final line = pickResidentLine(r, kind, date: date, childName: 'Mai');
          final candidates = r
              .linesOf(kind)
              .map((l) => fillChildName(l, 'Mai'))
              .toList();
          expect(candidates, contains(line));
          expect(line, isNot(contains('{ten}')));
        }
      }
    }
  });

  test('qua nhiều ngày thì đổi câu (không kẹt một câu)', () {
    final seen = <String>{};
    for (var day = 1; day <= 28; day++) {
      seen.add(
        pickResidentLine(
          knight,
          LineKind.ask,
          date: '2026-11-${day.toString().padLeft(2, '0')}',
        ),
      );
    }
    expect(seen.length, greaterThanOrEqualTo(4));
  });

  test('variant > 0 cho câu kế tiếp; phần phụ (chặng) đổi hạt giống', () {
    final base = pickResidentLine(
      knight,
      LineKind.greeting,
      date: '2026-11-18',
    );
    final next = pickResidentLine(
      knight,
      LineKind.greeting,
      date: '2026-11-18',
      variant: 1,
    );
    expect(next, isNot(base));
    // Quay đủ vòng thì về câu đầu.
    expect(
      pickResidentLine(
        knight,
        LineKind.greeting,
        date: '2026-11-18',
        variant: knight.linesOf(LineKind.greeting).length,
      ),
      base,
    );
  });

  test('nhóm rỗng thì trả chuỗi rỗng (không lỗi)', () {
    const empty = Resident(
      id: 'x',
      name: 'X',
      strand: 'logic',
      building: 'Y',
      bio: 'Z',
      lines: {},
    );
    expect(pickResidentLine(empty, LineKind.ask, date: '2026-11-18'), '');
  });
}
