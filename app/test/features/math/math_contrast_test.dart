/// Unit test tương phản cho T1-15 (PLAN điểm (m)): mọi chữ chính trên
/// màn làm toán đạt tối thiểu 4,5:1 (WCAG AA). Dòng tiếng Anh là chữ
/// phụ theo mẫu đã chốt với chủ dự án, tối thiểu 3:1.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/tables.dart';
import 'package:timokid/features/math/math_decor.dart';

/// Độ sáng tương đối theo WCAG 2.1 (kênh sRGB 0..255).
double _luminance(Color color) {
  double channel(int value) {
    final s = value / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((color.r * 255).round().clamp(0, 255)) +
      0.7152 * channel((color.g * 255).round().clamp(0, 255)) +
      0.0722 * channel((color.b * 255).round().clamp(0, 255));
}

/// Tỉ lệ tương phản WCAG giữa hai màu (1..21).
double _contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('chữ chính đạt tối thiểu 4,5:1', () {
    const white = Colors.white;
    // Chữ đề tím đậm và số trên nút đáp án, trên thẻ trắng.
    expect(
      _contrast(MathColors.questionText, white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(MathColors.buttonNumber, white),
      greaterThanOrEqualTo(4.5),
    );
    // Chữ trong băng xanh / băng cam / băng lời giải xanh dương,
    // trên nền băng của nó.
    expect(
      _contrast(MathColors.bannerGreenText, MathColors.bannerGreenBg),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(MathColors.bannerOrangeText, MathColors.bannerOrangeBg),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(MathColors.bannerBlueText, MathColors.bannerBlueBg),
      greaterThanOrEqualTo(4.5),
    );
    // Nút Tiếp: chữ xanh lá đậm trên nền trắng.
    expect(
      _contrast(MathColors.bannerGreenText, white),
      greaterThanOrEqualTo(4.5),
    );
    // Nút bị vô hiệu (review PR #14): chữ số tím đậm trên nền
    // pastel rất nhạt thay cho nâu đất.
    expect(
      _contrast(MathColors.buttonNumber, MathColors.disabledButtonBg),
      greaterThanOrEqualTo(4.5),
    );
    // Chữ tím đậm trên nền từng mảng (AppBar + tiêu đề).
    for (final strand in Strand.all) {
      expect(
        _contrast(MathColors.questionText, MathColors.strandBackground(strand)),
        greaterThanOrEqualTo(4.5),
        reason: 'chữ đề trên nền $strand',
      );
    }
  });

  test('dòng tiếng Anh là chữ phụ, tối thiểu 3:1', () {
    // Theo mẫu đã chốt: dòng EN nhạt hơn, chỉ cần đạt 3:1.
    expect(
      _contrast(MathColors.englishText, Colors.white),
      greaterThanOrEqualTo(3.0),
    );
  });

  test('nền màn khác hẳn thẻ trắng', () {
    for (final strand in Strand.all) {
      expect(
        MathColors.strandBackground(strand),
        isNot(Colors.white),
        reason: 'nền $strand phải khác thẻ trắng',
      );
      expect(
        _contrast(Colors.white, MathColors.strandBackground(strand)),
        greaterThan(1.05),
        reason: 'nền $strand phải nhìn khác thẻ trắng',
      );
    }
  });
}
