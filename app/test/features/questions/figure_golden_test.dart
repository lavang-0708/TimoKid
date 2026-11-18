import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/features/questions/figure_svg.dart';
import 'package:timokid/features/questions/question.dart';

import '../../goldens/figure_golden_data.dart';

/// Golden test cho hình vẽ của từng dạng có hình: countsq, countrect,
/// counttri, matches (1 hàng và 2 hàng), shapeperim, gridpath.
///
/// Làm theo mẫu `golden_test.dart` của T1-02: widget test mặc định không có
/// font nên test này nạp DejaVu Sans của máy làm font 'Roboto' và
/// 'sans-serif' (chữ A/B trong lưới đường đi dùng font-family sans-serif
/// của `gen.py`) để chữ trong ảnh chụp đọc được. File font nằm ở đường dẫn
/// chuẩn của Ubuntu (gói fonts-dejavu-core), máy chạy CI cũng có.
///
/// Ảnh kỳ vọng nhúng base64 trong `goldens/figure_golden_data.dart`: trước
/// khi so sánh, test giải mã và ghi ra file PNG trong `test/goldens/`, vì
/// file PNG không đẩy lên GitHub qua MCP được.
void _restoreGoldens() {
  const goldens = {
    'test/goldens/figure_countsq_2x3.png': figureCountsq2x3Base64,
    'test/goldens/figure_countrect_1x4.png': figureCountrect1x4Base64,
    'test/goldens/figure_counttri_fan3.png': figureCounttriFan3Base64,
    'test/goldens/figure_matches_1x4.png': figureMatches1x4Base64,
    'test/goldens/figure_matches_2x3.png': figureMatches2x3Base64,
    'test/goldens/figure_shapeperim_1x3.png': figureShapeperim1x3Base64,
    'test/goldens/figure_gridpath_2x2.png': figureGridpath2x2Base64,
  };
  for (final entry in goldens.entries) {
    File(entry.key).writeAsBytesSync(base64Decode(entry.value));
  }
}

Future<void> _loadTestFonts() async {
  final bytes = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
      .readAsBytesSync();
  for (final family in const ['Roboto', 'sans-serif']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

/// (Tên hiển thị, tham số hình, tên file golden) cho từng dạng có hình.
const _cases = <(String, FigureSpec, String)>[
  (
    'countsq lưới 2x3',
    FigureSpec.grid(rows: 2, cols: 3),
    'figure_countsq_2x3.png',
  ),
  (
    'countrect lưới 1x4',
    FigureSpec.grid(rows: 1, cols: 4),
    'figure_countrect_1x4.png',
  ),
  (
    'counttri quạt 3 đoạn',
    FigureSpec.fan(segments: 3),
    'figure_counttri_fan3.png',
  ),
  (
    'matches 1 hàng 4 ô',
    FigureSpec.grid(rows: 1, cols: 4, cell: 40),
    'figure_matches_1x4.png',
  ),
  (
    'matches 2 hàng 3 ô',
    FigureSpec.grid(rows: 2, cols: 3, cell: 40),
    'figure_matches_2x3.png',
  ),
  (
    'shapeperim 1 hàng 3 ô',
    FigureSpec.grid(rows: 1, cols: 3, cell: 45),
    'figure_shapeperim_1x3.png',
  ),
  (
    'gridpath lưới 2x2',
    FigureSpec.pathGrid(rows: 2, cols: 2),
    'figure_gridpath_2x2.png',
  ),
];

void main() {
  setUpAll(() async {
    await _loadTestFonts();
    _restoreGoldens();
  });

  for (final (name, spec, file) in _cases) {
    testWidgets('hình $name', (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: const Key('figure'),
                  child: FigureView(figure: spec),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('figure')),
        matchesGoldenFile('../../goldens/$file'),
      );
    });
  }
}
