import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chạy script kiểm tra hình (tools/assets/check_assets.py) trong lúc
/// chạy `flutter test`, để CI kiểm tra manifest mà không cần sửa
/// workflow (xem docs/ASSETS.md mục "Nối CI").
void main() {
  test('manifest hình hợp lệ (tools/assets/check_assets.py)', () async {
    final root = findRepoRoot();
    final script = File('${root.path}/tools/assets/check_assets.py');
    expect(
      script.existsSync(),
      isTrue,
      reason: 'không tìm thấy tools/assets/check_assets.py',
    );
    final result = await Process.run('python3', <String>[
      script.path,
      '--root',
      root.path,
    ]);
    expect(
      result.exitCode,
      0,
      reason: 'check_assets.py báo lỗi:\n${result.stdout}\n${result.stderr}',
    );
    // Script chỉ giải lọc phần cần thiết của PNG nên chạy chừng 1-2 giây.
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Directory findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/tools/assets/check_assets.py').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  fail('không tìm thấy gốc repo (tools/assets/check_assets.py)');
}
