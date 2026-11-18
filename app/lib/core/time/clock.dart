/// Đồng hồ của app: mọi code lấy thời gian và ngày đều đi qua đây thay vì
/// gọi [DateTime.now] trực tiếp, để test tái hiện được (dùng [FakeClock])
/// và menu QA nhảy ngày được (T1-13).
///
/// Giờ Việt Nam là UTC+7 cố định, không có giờ mùa hè, nên không cần gói
/// `timezone`: giờ địa phương = giờ UTC + 7 giờ.
library;

/// Múi giờ Việt Nam (Asia/Ho_Chi_Minh): UTC+7, không đổi quanh năm.
const vietnamUtcOffset = Duration(hours: 7);

/// Nguồn thời gian của app.
abstract class Clock {
  const Clock();

  /// Thời điểm hiện tại, theo giờ Việt Nam.
  DateTime now();

  /// Ngày hiện tại theo giờ Việt Nam, dạng `YYYY-MM-DD`
  /// (khớp cột `date` của bảng `daily_sets`).
  String today() {
    final now = this.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Đồng hồ thật: lấy giờ hệ thống rồi chuyển sang giờ Việt Nam.
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc().add(vietnamUtcOffset);
}

/// Đồng hồ giả cho test: thời gian do test đặt, không trôi trừ khi test
/// gọi [advance] hoặc [set].
class FakeClock extends Clock {
  FakeClock(DateTime initial) : _now = initial;

  DateTime _now;

  /// Đặt lại thời điểm hiện tại.
  void set(DateTime value) {
    _now = value;
  }

  /// Cho thời gian trôi thêm [duration].
  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  @override
  DateTime now() => _now;
}
