/// Provider Riverpod cho database của app.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Database dùng chung toàn app. `main.dart` mở DB và gọi `ensureSeeded`
/// trước khi chạy app, rồi ghi đè provider bằng đúng instance đó.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
