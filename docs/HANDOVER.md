# HANDOVER — TimoKid

Cập nhật cuối: 17/11/2026 (nhiệm vụ T1-04, nhánh `task/T1-04-db`).

## Trạng thái hiện tại

- `main` đang ở commit `fa956e4` — PR #3 (T1-03) đã merge squash; CI + 3 workflow đã có trên main.
- T1-01 **Xong**: PR #1 đã merge.
- T1-02 **Xong**: PR #2 đã merge (`04dfe35`). Claude đã rebase nhánh lên main và chạy lại trên máy mình: analyze sạch, 5/5 test pass.
- T1-03 **Xong**: PR #3 đã merge (`fa956e4`). CI chính xanh trong 11,5 phút, APK debug đúng `vn.timokid.app`; integration test máy ảo đã sửa (build APK trước, cache AVD, API 30, `--use-application-binary`) và chạy lại xanh trước khi merge. Anh Điệp chỉ cần nạp 4 secrets ký APK theo `docs/RELEASE.md`, rồi tag thử `v0.0.1` làm sau.
- T1-04 **Đang làm**: Drift với 7 bảng, hồ sơ bé mặc định lớp 2, test trên DB trong bộ nhớ + test tắt/mở lại app. PR: (điền số PR sau khi mở). Nhánh tách từ main cũ (`04dfe35`); sau khi mở PR sẽ merge main mới (`fa956e4`, có CI) vào nhánh.
- Các nhiệm vụ còn lại của bản 0.1 (T1-05 đến T1-14): **Chưa bắt đầu**. T1-05 làm song song với T1-04 trên nhánh riêng.
- **Từ nay Claude merge PR** (anh Điệp giao).

## Điểm cần biết khi tiếp tục

- **Muse không đẩy được file nhị phân lên GitHub qua MCP** (kênh push-files chỉ nhận file text UTF-8; thử đẩy base64 qua `push_files` thì file lên sai dạng text). Quy tắc từ nay (Claude chốt sau review PR #2): Muse liệt kê file nhị phân cần có trong mục "Việc còn lại" của PR (đường dẫn, cách sinh), Claude commit bằng git lên nhánh PR. Áp dụng ở T1-02: (1) ảnh golden nhúng base64 trong `app/test/goldens/golden_data.dart`, test tự giải mã ra PNG trước khi so sánh; (2) chưa có icon launcher riêng — `AndroidManifest.xml` bỏ `android:icon`, app dùng icon mặc định của hệ thống, icon thật làm ở T1-12.
- **`gradle-wrapper.jar` không cần commit**: file này nằm trong `app/android/.gitignore` của template vì flutter tool tự sinh khi build (`injectGradleWrapperIfNeeded` trong flutter_tools). T1-03 KHÔNG tải jar hay commit bằng Actions như dự định ban đầu. Tương tự, `gradlew`/`gradlew.bat` cũng tự sinh, nhưng đã commit kèm ở T1-02 nên cứ để đó.
- CI chạy trên GitHub Actions, ghim Flutter 3.50.0. Máy Muse không có Android SDK nên không chạy được `flutter build apk` hay máy ảo ở local — CI là nơi kiểm chứng. Workflow release cần 4 secrets ký APK (xem `docs/RELEASE.md`); thiếu secrets thì job dừng với thông báo rõ ràng, không build bản ký debug.
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
