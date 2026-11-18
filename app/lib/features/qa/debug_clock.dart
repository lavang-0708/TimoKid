/// Đồng hồ gỡ lỗi cho menu QA (T1-13).
///
/// Bọc một [Clock] khác và cộng thêm một độ lệch, để menu QA "nhảy
/// sang ngày hôm sau" mà không phá ngữ nghĩa của [SystemClock] dùng
/// trong production: đồng hồ thật vẫn là nguồn duy nhất tính giờ,
/// [DebugClock] chỉ cộng thêm số ngày QA đã nhảy.
///
/// Độ lệch chỉ sống trong bộ nhớ: tắt/mở lại app là về ngày thật.
/// Mọi code đọc giờ qua `db.clock` (đề ngày, sổ ôn tập, mốc cửa sổ
/// 10 câu) đều thấy ngày ảo này vì chúng đều đọc cùng một [Clock]
/// của database — đó chính là cách menu kiểm tra được T1-08 (đề
/// mới khi sang ngày) và T1-10 (mục đến hạn khi sang ngày).
library;

import '../../core/time/clock.dart';

/// Đồng hồ QA: giờ thật cộng thêm một độ lệch ngày.
class DebugClock extends Clock {
  /// Bọc [base] (thường là [SystemClock] của database).
  DebugClock(this._base);

  final Clock _base;

  Duration _offset = Duration.zero;

  /// Độ lệch hiện tại so với giờ thật (0 nếu chưa nhảy ngày).
  Duration get offset => _offset;

  /// Có đang lệch khỏi ngày thật không.
  bool get isAdvanced => _offset != Duration.zero;

  /// Cho thời gian trôi thêm [duration] (menu QA dùng 1 ngày/lần bấm).
  void advanceBy(Duration duration) {
    _offset += duration;
  }

  /// Về lại ngày thật.
  void reset() {
    _offset = Duration.zero;
  }

  @override
  DateTime now() => _base.now().add(_offset);
}
