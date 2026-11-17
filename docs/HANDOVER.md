# HANDOVER — TimoKid

Cập nhật cuối: 17/11/2026 (nhiệm vụ T1-04, nhánh `task/T1-04-db`).

## Trạng thái hiện tại

- `main` đang ở commit `04dfe35` — PR #1 (T1-01) và PR #2 (T1-02) đã merge.
- T1-01 **Xong**, T1-02 **Xong** (khung app Flutter, package `vn.timokid.app`, 3 màn trống, mở đầu vào Thị trấn).
- T1-03 **Chờ xác nhận**: PR #3 (https://github.com/lavang-0708/TimoKid/pull/3) — CI và phát hành APK. CI chính đã xanh, APK debug đúng `vn.timokid.app`; integration test máy ảo đang chạy lại sau khi Claude sửa (build APK trước, cache AVD, API 30, `--use-application-binary`). Nhánh T1-04 này tách từ `main` trước khi PR #3 merge nên chưa có CI; rebase sau khi PR #3 vào `main`.
- T1-04 **Đang làm**: Drift với 7 bảng, hồ sơ bé mặc định lớp 2, test trên DB trong bộ nhớ + test tắt/mở lại app. PR: (điền số PR sau khi mở).
- Các nhiệm vụ còn lại của bản 0.1 (T1-05 đến T1-14): **Chưa bắt đầu**. T1-05 làm song song với T1-04 trên nhánh riêng.

## Điểm cần biết khi tiếp tục

- **Muse không đẩy được file nhị phân lên GitHub qua MCP** (kênh push-files chỉ nhận file text UTF-8; thử đẩy base64 qua `push_files` thì file lên sai dạng text). Vì vậy T1-02 có 2 chỗ làm khác thường, ghi trong `docs/DECISIONS.md`: (1) ảnh golden nhúng base64 trong `app/test/goldens/golden_data.dart`, test tự giải mã ra PNG trước khi so sánh; (2) chưa có icon launcher riêng — `AndroidManifest.xml` bỏ `android:icon`, app dùng icon mặc định của hệ thống, icon thật làm ở T1-12.
- **Gradle wrapper tự sinh, không cần commit jar**: `flutter build apk` tự copy `gradle-wrapper.jar` từ cache SDK khi thiếu (đã xác minh trong mã flutter_tools ở T1-03). T1-03 không tải hay commit jar.
- **Muse không đẩy được file trong `.github/workflows/`** (GitHub App không có quyền `workflows`, lỗi 403). 3 file workflow của T1-03 do Claude commit giúp bằng git. T1-04 không có file workflow.
- **Database T1-04**: Drift 2.35.4 + drift_flutter 0.3.1, schema v1, 7 bảng (`children`, `attempts`, `skill_progress`, `review_queue`, `daily_sets`, `wallet_ledger`, `settings`). File sinh bởi build_runner (`app_database.g.dart`, `daos.g.dart`) được commit cùng code vì CI chưa có bước build_runner. Chi tiết schema và các quyết định xem `docs/DECISIONS.md` (mục 17/11/2026 — T1-04).
- **Clock**: mọi code lấy thời gian qua lớp `Clock` (`lib/core/time/clock.dart`); giờ Việt Nam = UTC+7 cố định, không cần gói `timezone`. Test dùng `FakeClock`.
- Flutter SDK của Muse: `~/workspace/flutter-sdk/flutter`, bản 3.50.0 stable, Dart 3.14.0. Build APK và máy ảo chỉ qua GitHub Actions (T1-03).

## Cách build và chạy test

- Ngân hàng câu hỏi (không cần Flutter):

  ```sh
  python3 tools/question_bank/check.py
  # kỳ vọng: questions: 267 | bad: 0 | unchecked: []
  ```

- Flutter SDK của Muse nằm ở `~/workspace/flutter-sdk/flutter` (bản stable, cài theo mục (j) trong PLAN). Chạy `flutter analyze`, unit test và widget test local; build APK và test máy ảo chạy trên GitHub Actions.
- Test database (`app/test/database_test.dart`) chạy bằng `flutter test` trên máy Muse, không cần Android SDK: dùng `NativeDatabase.memory()` và DB file tạm, nhờ máy có sẵn `libsqlite3.so.0`.
- Sau khi sửa bảng Drift phải chạy lại `dart run build_runner build` để sinh lại file `.g.dart`, rồi commit cả file sinh.

## Điểm cần biết khi tiếp tục

- "Dạng bài" = một `form` trong `gen.py`: 48 form. Chỉ **17 form** đủ cả 3 mức (Dễ/Vừa/Khó); các form còn lại chỉ sinh ở mức nó hỗ trợ, không tự soạn mức mới (mục (a)).
- Thành thạo tính ở mức cao nhất dạng hỗ trợ, không thấp hơn Vừa nếu dạng có Vừa (mục (b)). Nhờ vậy cả 48 dạng đều thành thạo được.
- Thứ tự thưởng xu: xu gốc → chia đôi làm tròn lên nếu đúng sau gợi ý → nhân đôi nếu là câu ôn tập (mục (c)).
- "Đúng" luôn là đúng ngay lần đầu cho lên/xuống bậc và thành thạo (mục (f)).
- Đề ngày: thiếu dạng thì được lặp (ưu tiên dạng ít gặp nhất 7 ngày gần đây); câu ôn tập dùng bậc lưu trong `review_queue`, được ưu tiên khi trùng dạng (mục (g)).
- T1-04 tạo 7 bảng; `inventory` ở T2-05, `pets` ở T2-07 (migration); `families`, `messages`, `custom_questions`, `content_packs` thuộc bản 0.3/0.5 (mục (e)).
- CI: workflow chính (analyze, test, build APK debug) dưới 15 phút; integration test máy ảo tách workflow riêng, ngân sách 25 phút (mục (h)).
- Tag phát hành do Muse tạo sau khi Claude kết luận Đạt. Ký APK chờ anh Điệp nạp keystore vào GitHub Secrets.
- Menu QA: nhấn giữ 5 giây ở góc trên bên trái. `Clock` trả ngày theo `Asia/Ho_Chi_Minh`. Bản 0.1 mở app vào thẳng màn Thị trấn tạm với bé mặc định (mục (i)).
- Sửa sai trong review trước của Muse: số form đủ 3 mức là 17, không phải 30 như Muse viết lúc đầu. Kết luận review không đổi.
