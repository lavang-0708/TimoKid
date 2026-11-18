import 'package:flutter_test/flutter_test.dart';

import 'package:timokid/features/questions/figure_svg.dart';
import 'package:timokid/features/questions/question.dart';

/// Chuỗi SVG sinh ra phải khớp từng ký tự với các hàm `svg_*`
/// trong `gen.py` cho cùng tham số. Chuỗi kỳ vọng dưới đây lấy
/// trực tiếp từ `gen.py` (chạy thử các hàm `svg_grid`/`svg_fan`/
/// `svg_path_grid` trên bản sao, không import `gen.py`).
void main() {
  group('buildFigureSvg khớp từng ký tự với gen.py', () {
    test('countsq lưới 2x3', () {
      expect(
        buildFigureSvg(const FigureSpec.grid(rows: 2, cols: 3)),
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 162 112" width="162" height="112"><g fill="none" stroke="#333" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"><line x1="6" y1="6" x2="156" y2="6"/><line x1="6" y1="56" x2="156" y2="56"/><line x1="6" y1="106" x2="156" y2="106"/><line x1="6" y1="6" x2="6" y2="106"/><line x1="56" y1="6" x2="56" y2="106"/><line x1="106" y1="6" x2="106" y2="106"/><line x1="156" y1="6" x2="156" y2="106"/></g></svg>',
      );
    });

    test('countrect lưới 1x4', () {
      expect(
        buildFigureSvg(const FigureSpec.grid(rows: 1, cols: 4)),
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 212 62" width="212" height="62"><g fill="none" stroke="#333" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"><line x1="6" y1="6" x2="206" y2="6"/><line x1="6" y1="56" x2="206" y2="56"/><line x1="6" y1="6" x2="6" y2="56"/><line x1="56" y1="6" x2="56" y2="56"/><line x1="106" y1="6" x2="106" y2="56"/><line x1="156" y1="6" x2="156" y2="56"/><line x1="206" y1="6" x2="206" y2="56"/></g></svg>',
      );
    });

    test('counttri quạt 3 đoạn', () {
      expect(
        buildFigureSvg(const FigureSpec.fan(segments: 3)),
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 260 180" width="260" height="180"><g fill="none" stroke="#333" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"><polygon points="130.0,10 10,170 250,170"/><line x1="130.0" y1="10" x2="70.0" y2="170"/><line x1="130.0" y1="10" x2="130.0" y2="170"/><line x1="130.0" y1="10" x2="190.0" y2="170"/></g></svg>',
      );
    });

    test('matches 1 hàng 4 ô 40px', () {
      expect(
        buildFigureSvg(const FigureSpec.grid(rows: 1, cols: 4, cell: 40)),
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 172 52" width="172" height="52"><g fill="none" stroke="#333" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"><line x1="6" y1="6" x2="166" y2="6"/><line x1="6" y1="46" x2="166" y2="46"/><line x1="6" y1="6" x2="6" y2="46"/><line x1="46" y1="6" x2="46" y2="46"/><line x1="86" y1="6" x2="86" y2="46"/><line x1="126" y1="6" x2="126" y2="46"/><line x1="166" y1="6" x2="166" y2="46"/></g></svg>',
      );
    });

    test('matches 2 hàng 3 ô 40px', () {
      expect(
        buildFigureSvg(const FigureSpec.grid(rows: 2, cols: 3, cell: 40)),
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 132 92" width="132" height="92"><g fill="none" stroke="#333" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"><line x1="6" y1="6" x2="126" y2="6"/><line x1="6" y1="46" x2="126" y2="46"/><line x1="6" y1="86" x2="126" y2="86"/><line x1="6" y1="6" x2="6" y2="86"/><line x1="46" y1="6" x2="46" y2="86"/><line x1="86" y1="6" x2="86" y2="86"/><line x1="126" y1="6" x2="126" y2="86"/></g></svg>',
      );
    });

    test('shapeperim 1 hàng 3 ô 45px', () {
      expect(
        buildFigureSvg(const FigureSpec.grid(rows: 1, cols: 3, cell: 45)),
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 147 57" width="147" height="57"><g fill="none" stroke="#333" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"><line x1="6" y1="6" x2="141" y2="6"/><line x1="6" y1="51" x2="141" y2="51"/><line x1="6" y1="6" x2="6" y2="51"/><line x1="51" y1="6" x2="51" y2="51"/><line x1="96" y1="6" x2="96" y2="51"/><line x1="141" y1="6" x2="141" y2="51"/></g></svg>',
      );
    });

    test('gridpath lưới 2x2', () {
      expect(
        buildFigureSvg(const FigureSpec.pathGrid(rows: 2, cols: 2)),
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 148 148" width="148" height="148"><g fill="none" stroke="#333" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"><line x1="24" y1="24" x2="124" y2="24"/><line x1="24" y1="74" x2="124" y2="74"/><line x1="24" y1="124" x2="124" y2="124"/><line x1="24" y1="24" x2="24" y2="124"/><line x1="74" y1="24" x2="74" y2="124"/><line x1="124" y1="24" x2="124" y2="124"/></g><g font-family="sans-serif" font-size="18" fill="#c0392b"><circle cx="24" cy="124" r="6"/><text x="4" y="144">A</text><circle cx="124" cy="24" r="6"/><text x="130" y="16">B</text></g></svg>',
      );
    });
  });

  group('figureSvgSize', () {
    test('lưới 2x3 ô 50px là 162x112', () {
      expect(figureSvgSize(const FigureSpec.grid(rows: 2, cols: 3)), (
        width: 162,
        height: 112,
      ));
    });

    test('quạt là 260x180', () {
      expect(figureSvgSize(const FigureSpec.fan(segments: 3)), (
        width: 260,
        height: 180,
      ));
    });

    test('lưới đường đi 2x2 là 148x148', () {
      expect(figureSvgSize(const FigureSpec.pathGrid(rows: 2, cols: 2)), (
        width: 148,
        height: 148,
      ));
    });
  });
}
