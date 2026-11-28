/// Nội dung cư dân: mô hình, đọc file JSON và kiểm tra (T4-02).
///
/// Dart thuần ngoài hàm [ResidentBook.load] (đọc asset). Test kiểm tra
/// file thật bằng [validateResidentBook].
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/database/tables.dart';
import 'resident_config.dart';

/// Các nhóm lời thoại của một cư dân.
enum LineKind {
  /// Chào khi bé vào tòa nhà.
  greeting('greeting'),

  /// "Nhờ giúp": nói trước khi bé làm chặng.
  ask('ask'),

  /// Cảm ơn sau khi bé xong chặng.
  thanks('thanks'),

  /// Động viên khi bé làm chặng còn vất vả.
  encourage('encourage'),

  /// Lời đặc biệt, mở khóa khi bé thành thạo đủ nhiều dạng.
  special('special');

  const LineKind(this.key);

  /// Khóa trong file JSON.
  final String key;
}

class Resident {
  const Resident({
    required this.id,
    required this.name,
    required this.strand,
    required this.building,
    required this.bio,
    required this.lines,
  });

  factory Resident.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as Map?)?.cast<String, dynamic>() ?? {};
    return Resident(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      strand: json['strand'] as String? ?? '',
      building: json['building'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      lines: {
        for (final kind in LineKind.values)
          kind: [
            for (final line in (rawLines[kind.key] as List?) ?? const [])
              line as String,
          ],
      },
    );
  }

  final String id;
  final String name;

  /// Mảng của khu cư dân sống ([Strand.all]).
  final String strand;

  /// Tên tòa nhà (khớp `townAreas`).
  final String building;
  final String bio;
  final Map<LineKind, List<String>> lines;

  List<String> linesOf(LineKind kind) => lines[kind] ?? const [];
}

class ResidentBook {
  const ResidentBook(this.residents);

  factory ResidentBook.fromJson(Map<String, dynamic> json) => ResidentBook([
    for (final r in (json['residents'] as List?) ?? const [])
      Resident.fromJson((r as Map).cast<String, dynamic>()),
  ]);

  factory ResidentBook.fromJsonString(String source) =>
      ResidentBook.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final List<Resident> residents;

  /// Cư dân của mảng [strand]; null nếu không có.
  Resident? forStrand(String strand) {
    for (final r in residents) {
      if (r.strand == strand) return r;
    }
    return null;
  }

  Resident? byId(String id) {
    for (final r in residents) {
      if (r.id == id) return r;
    }
    return null;
  }

  static ResidentBook? _cached;

  /// Chỉ dùng trong test: nạp sẵn nội dung để khỏi đọc asset (widget test
  /// chạy trong FakeAsync nên đọc asset thật dễ treo). `null` để xóa.
  static ResidentBook? debugOverride;

  /// Đọc file nội dung (có nhớ lại). Lỗi đọc/phân tích thì ném ra; nơi gọi
  /// tự bỏ qua để màn vẫn chạy được không có cư dân.
  static Future<ResidentBook> load() async {
    final override = debugOverride;
    if (override != null) return override;
    final cached = _cached;
    if (cached != null) return cached;
    final text = await rootBundle.loadString(ResidentConfig.contentAsset);
    return _cached = ResidentBook.fromJsonString(text);
  }
}

/// Kiểm tra nội dung; trả danh sách lỗi (rỗng = hợp lệ).
List<String> validateResidentBook(ResidentBook book) {
  final errors = <String>[];
  if (book.residents.length != ResidentConfig.residentCount) {
    errors.add(
      'Cần ${ResidentConfig.residentCount} cư dân, đang có '
      '${book.residents.length}.',
    );
  }
  final strands = <String>{};
  final ids = <String>{};
  for (final r in book.residents) {
    final who = r.id.isEmpty ? '(thiếu id)' : r.id;
    if (r.id.isEmpty) errors.add('Cư dân không có id.');
    if (!ids.add(r.id)) errors.add('$who: trùng id.');
    if (!Strand.all.contains(r.strand)) {
      errors.add('$who: mảng "${r.strand}" không hợp lệ.');
    } else if (!strands.add(r.strand)) {
      errors.add('$who: mảng ${r.strand} đã có cư dân khác.');
    }
    if (r.name.trim().isEmpty) errors.add('$who: thiếu tên.');
    if (r.name.length > ResidentConfig.maxNameLength) {
      errors.add('$who: tên quá dài.');
    }
    if (r.building.trim().isEmpty) errors.add('$who: thiếu tòa nhà.');
    if (r.bio.trim().isEmpty) errors.add('$who: thiếu giới thiệu.');
    if (r.bio.length > ResidentConfig.maxBioLength) {
      errors.add('$who: giới thiệu dài ${r.bio.length} ký tự.');
    }
    for (final kind in LineKind.values) {
      final lines = r.linesOf(kind);
      final min = kind == LineKind.special
          ? ResidentConfig.minSpecialVariants
          : ResidentConfig.minVariants;
      if (lines.length < min || lines.length > ResidentConfig.maxVariants) {
        errors.add(
          '$who/${kind.key}: cần $min–${ResidentConfig.maxVariants} câu, '
          'đang có ${lines.length}.',
        );
      }
      final maxLen = kind == LineKind.greeting
          ? ResidentConfig.maxGreetingLength
          : ResidentConfig.maxLineLength;
      final seen = <String>{};
      for (final line in lines) {
        if (line.trim().isEmpty) {
          errors.add('$who/${kind.key}: có câu rỗng.');
          continue;
        }
        if (line != line.trim()) {
          errors.add('$who/${kind.key}: thừa khoảng trắng đầu/cuối "$line".');
        }
        if (line.length > maxLen) {
          errors.add(
            '$who/${kind.key}: câu dài ${line.length} > $maxLen: "$line".',
          );
        }
        if (!seen.add(line)) errors.add('$who/${kind.key}: trùng "$line".');
        final stripped = line.replaceAll(ResidentConfig.namePlaceholder, '');
        if (stripped.contains('{') || stripped.contains('}')) {
          errors.add('$who/${kind.key}: dấu { } lạ trong "$line".');
        }
      }
    }
  }
  return errors;
}
