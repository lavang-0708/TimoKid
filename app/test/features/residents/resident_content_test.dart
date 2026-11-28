/// Kiểm tra file nội dung cư dân `assets/content/residents.json` (T4-02):
/// đủ 5 cư dân (mỗi mảng một), đủ mọi nhóm lời thoại, không câu rỗng,
/// độ dài trong giới hạn, `{ten}` thay đúng.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/features/residents/resident_config.dart';
import 'package:timokid/features/residents/resident_content.dart';
import 'package:timokid/features/residents/resident_service.dart';
import 'package:timokid/features/town/town_assets.dart';

ResidentBook _realBook() => ResidentBook.fromJsonString(
  File('assets/content/residents.json').readAsStringSync(),
);

void main() {
  test('file nội dung hợp lệ (không lỗi nào)', () {
    expect(validateResidentBook(_realBook()), isEmpty);
  });

  test('5 cư dân, mỗi mảng đúng một, khớp tên tòa nhà ở Thị trấn', () {
    final book = _realBook();
    expect(book.residents, hasLength(5));
    for (final strand in Strand.all) {
      final r = book.forStrand(strand);
      expect(r, isNotNull, reason: strand);
      final area = townAreas.firstWhere((a) => a.strand == strand);
      expect(r!.building, area.name);
    }
    expect(book.residents.map((r) => r.name).toList(), [
      'Hiệp sĩ Sáng',
      'Cô Bông',
      'Cú Tròn',
      'Bác Vuông',
      'Chú Xoay',
    ]);
  });

  test(
    'mỗi cư dân đủ mọi nhóm: 5–8 câu (special 3–8), không rỗng, vừa dài',
    () {
      for (final r in _realBook().residents) {
        for (final kind in LineKind.values) {
          final lines = r.linesOf(kind);
          final min = kind == LineKind.special
              ? ResidentConfig.minSpecialVariants
              : ResidentConfig.minVariants;
          expect(
            lines.length,
            inInclusiveRange(min, ResidentConfig.maxVariants),
            reason: '${r.id}/${kind.key}',
          );
          for (final line in lines) {
            expect(line.trim(), isNotEmpty);
            expect(
              line.length,
              lessThanOrEqualTo(
                kind == LineKind.greeting
                    ? ResidentConfig.maxGreetingLength
                    : ResidentConfig.maxLineLength,
              ),
              reason: line,
            );
          }
        }
      }
    },
  );

  test('bộ kiểm tra bắt được lỗi: thiếu nhóm, câu rỗng, quá dài, trùng', () {
    final json = jsonDecode(
      File('assets/content/residents.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    ResidentBook mutate(void Function(Map<String, dynamic> first) edit) {
      final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      edit((copy['residents'] as List).first as Map<String, dynamic>);
      return ResidentBook.fromJson(copy);
    }

    expect(
      validateResidentBook(mutate((r) => (r['lines'] as Map).remove('thanks'))),
      isNotEmpty,
    );
    expect(
      validateResidentBook(
        mutate((r) => ((r['lines'] as Map)['ask'] as List)[0] = '  '),
      ),
      isNotEmpty,
    );
    expect(
      validateResidentBook(
        mutate((r) => ((r['lines'] as Map)['greeting'] as List)[0] = 'x' * 200),
      ),
      isNotEmpty,
    );
    expect(
      validateResidentBook(
        mutate((r) {
          final list = (r['lines'] as Map)['ask'] as List;
          list[1] = list[0];
        }),
      ),
      isNotEmpty,
    );
    expect(
      validateResidentBook(
        mutate((r) => ((r['lines'] as Map)['ask'] as List)[0] = 'Chào {tên}!'),
      ),
      isNotEmpty,
    );
    // Thiếu cư dân.
    final fewer = ResidentBook(_realBook().residents.take(4).toList());
    expect(validateResidentBook(fewer), isNotEmpty);
  });

  test('{ten} được thay bằng tên bé; không có tên thì "bé"; không sót { }', () {
    expect(
      fillChildName('Chào {ten}! {ten} giỏi quá.', 'Mai'),
      'Chào Mai! Mai giỏi quá.',
    );
    expect(fillChildName('Chào {ten}!', null), 'Chào bé!');
    expect(fillChildName('Chào {ten}!', '   '), 'Chào bé!');
    for (final r in _realBook().residents) {
      for (final kind in LineKind.values) {
        for (final line in r.linesOf(kind)) {
          final filled = fillChildName(line, 'Bảo Ngọc');
          expect(filled, isNot(contains('{')));
          expect(filled, isNot(contains('}')));
        }
      }
    }
  });

  test('pubspec khai báo thư mục nội dung', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/content/'),
    );
  });

  testWidgets('asset khai báo trong pubspec đọc được qua rootBundle', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final text = await rootBundle.loadString(ResidentConfig.contentAsset);
      expect(validateResidentBook(ResidentBook.fromJsonString(text)), isEmpty);
    });
  });
}
