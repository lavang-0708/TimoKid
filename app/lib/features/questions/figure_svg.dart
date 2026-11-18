import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import 'question.dart';

/// Sinh chuỗi SVG từ [FigureSpec], giữ đúng hình học của các hàm `svg_*`
/// trong `gen.py` (`svg_grid`, `svg_fan`, `svg_path_grid`).
///
/// Chuỗi trả về khớp từng ký tự với `gen.py` cho cùng tham số (kiểm bằng
/// test so sánh chuỗi trong `figure_svg_test.dart`): cùng số ô, cùng cách
/// chia quạt, cùng lưới đường đi; nét `#333`, dày 3, đầu tròn.
///
/// Nét dày 3 ở kích thước gốc đã đủ đậm và dễ nhìn trên màn hình nhỏ;
/// widget [FigureView] chỉ phóng to/thu nhỏ toàn bộ hình theo tỉ lệ nên
/// nét giữ nguyên tỉ lệ với hình.
String buildFigureSvg(FigureSpec figure) {
  return switch (figure.kind) {
    FigureKind.grid => _svgGrid(figure.rows, figure.cols, figure.cell),
    FigureKind.fan => _svgFan(figure.segments),
    FigureKind.pathGrid => _svgPathGrid(figure.rows, figure.cols, figure.cell),
  };
}

/// Kích thước tự nhiên (khung `viewBox`) của hình vẽ theo [FigureSpec].
({int width, int height}) figureSvgSize(FigureSpec figure) {
  return switch (figure.kind) {
    FigureKind.grid => (
      width: figure.cols * figure.cell + 12,
      height: figure.rows * figure.cell + 12,
    ),
    FigureKind.fan => (width: 260, height: 180),
    FigureKind.pathGrid => (
      width: figure.cols * figure.cell + 48,
      height: figure.rows * figure.cell + 48,
    ),
  };
}

String _svgWrap(int width, int height, String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height" '
    'width="$width" height="$height"><g fill="none" stroke="#333" '
    'stroke-width="3" stroke-linejoin="round" stroke-linecap="round">'
    '$body</g></svg>';

/// Lưới ô vuông [rows] x [cols], mỗi ô [cell] px — như `svg_grid` của
/// `gen.py` (lề 6 px, đường kẻ ngang rồi đường kẻ dọc).
String _svgGrid(int rows, int cols, int cell) {
  const pad = 6;
  final b = StringBuffer();
  for (var r = 0; r <= rows; r++) {
    b.write(
      '<line x1="$pad" y1="${pad + r * cell}" '
      'x2="${pad + cols * cell}" y2="${pad + r * cell}"/>',
    );
  }
  for (var c = 0; c <= cols; c++) {
    b.write(
      '<line x1="${pad + c * cell}" y1="$pad" '
      'x2="${pad + c * cell}" y2="${pad + rows * cell}"/>',
    );
  }
  return _svgWrap(cols * cell + 2 * pad, rows * cell + 2 * pad, b.toString());
}

/// Tam giác có đỉnh ở trên, [k] đoạn thẳng nối đỉnh xuống cạnh đáy — như
/// `svg_fan` của `gen.py` (khung 260x180, lề 10, đỉnh (130, 10), đáy
/// từ (10, 170) đến (250, 170), các điểm chia đáy cách đều, tọa độ x
/// làm tròn 1 chữ số thập phân).
String _svgFan(int k) {
  const width = 260;
  const height = 180;
  const pad = 10;
  const ax = 130.0; // W / 2
  const ay = pad;
  const bx0 = pad;
  const bx1 = width - pad;
  const by = height - pad;
  final b = StringBuffer()
    ..write('<polygon points="$ax,$ay $bx0,$by $bx1,$by"/>');
  for (var i = 1; i <= k; i++) {
    final x = bx0 + (bx1 - bx0) * i / (k + 1);
    b.write('<line x1="$ax" y1="$ay" x2="${x.toStringAsFixed(1)}" y2="$by"/>');
  }
  return _svgWrap(width, height, b.toString());
}

/// Lưới [rows] x [cols] có đánh dấu điểm A (góc dưới trái) và điểm B
/// (góc trên phải), dùng cho bài đường đi trên lưới — như `svg_path_grid`
/// của `gen.py` (lề 24 px, chấm đỏ r=6 và chữ A/B đỏ `#c0392b`, cỡ 18).
String _svgPathGrid(int rows, int cols, int cell) {
  const pad = 24;
  final b = StringBuffer();
  for (var r = 0; r <= rows; r++) {
    b.write(
      '<line x1="$pad" y1="${pad + r * cell}" '
      'x2="${pad + cols * cell}" y2="${pad + r * cell}"/>',
    );
  }
  for (var c = 0; c <= cols; c++) {
    b.write(
      '<line x1="${pad + c * cell}" y1="$pad" '
      'x2="${pad + c * cell}" y2="${pad + rows * cell}"/>',
    );
  }
  b.write('</g><g font-family="sans-serif" font-size="18" fill="#c0392b">');
  b.write('<circle cx="$pad" cy="${pad + rows * cell}" r="6"/>');
  b.write('<text x="${pad - 20}" y="${pad + rows * cell + 20}">A</text>');
  b.write('<circle cx="${pad + cols * cell}" cy="$pad" r="6"/>');
  b.write('<text x="${pad + cols * cell + 6}" y="${pad - 8}">B</text>');
  return _svgWrap(cols * cell + 2 * pad, rows * cell + 2 * pad, b.toString());
}

/// Widget hiển thị hình vẽ của một câu hỏi.
///
/// Vẽ bằng [SvgPicture.string] từ [buildFigureSvg]. Không đặt [width] thì
/// dùng kích thước tự nhiên của hình; đặt [width] thì chiều cao co theo
/// đúng tỉ lệ (nét vẽ co theo hình, không bị méo).
class FigureView extends StatelessWidget {
  const FigureView({super.key, required this.figure, this.width});

  final FigureSpec figure;

  /// Chiều rộng hiển thị (px logic). Bỏ trống: dùng kích thước tự nhiên.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final size = figureSvgSize(figure);
    final w = width ?? size.width.toDouble();
    final h = w * size.height / size.width;
    return SvgPicture.string(buildFigureSvg(figure), width: w, height: h);
  }
}
