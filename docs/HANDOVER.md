# HANDOVER — TimoKid

Cập nhật cuối: 19/11/2026 (nhiệm vụ T2-01, nhánh `task/T2-01-quy-trinh-nap-hinh`).

## Trạng thái hiện tại

- `main` đang ở commit `5f5104d` — PR #1 (T1-01), #2 (T1-02), #3 (T1-03), #4 (T1-04), #5 (T1-05), #7 (T1-06), #8 (T1-07), #9 (T1-08), #10 (T1-10), #11 (T1-09), #12 (T1-11) đã merge. PR #6 đóng vì trùng T1-04. PLAN.md có mục "Làm rõ ngày 17/11" (a–k), ghi đè mọi chỗ khác trong kế hoạch; thêm điểm (l) (đề song ngữ + hai cột cân nhau, 18/11) và điểm (m) (màn làm toán sinh động: âm thanh + phông Nunito + giao diện, 18/11).
- T1-01 đến T1-04 **Xong**. CI chính và integration test máy ảo (API 30, ~8 phút) đều xanh. Phần ký APK chờ anh Điệp nạp 4 secrets theo `docs/RELEASE.md`, rồi tag thử `v0.0.1`.
- T1-05 **Xong**: Bộ sinh câu hỏi — chuyển 48/48 dạng bài trong `gen.py` sang Dart (`lib/features/questions/`), test 500 seed × 103 cặp form×mức. PR #5 đã merge.
- T1-06 **Xong**: Hình vẽ cho câu hình học — sinh SVG từ `FigureSpec` (`lib/features/questions/figure_svg.dart`, gói `flutter_svg` 2.4.0), golden test 7 hình, Claude đã đếm lại 7 ảnh bằng mắt: đúng hết. PR #7 đã merge.
- T1-07 **Xong** (PR #8 đã merge): Thang ải và thành thạo — bậc 1–6 theo mảng + thành thạo dạng bài (`lib/features/ladder/`, `LadderService` dùng DAO T1-04), 22 unit test mới (thêm 1 test thành thạo dính sau review PR #8, commit `d08ac67`). PR: #8 (https://github.com/lavang-0708/TimoKid/pull/8).
- T1-08 **Xong** (PR #9 đã merge): Đề ngày — mỗi ngày một đề 25 câu, 5 chặng theo 5 mảng (`lib/features/daily_set/`, `DailySetService` dùng `LadderService` + DAO T1-04), 27 unit test mới. PR: #9 (https://github.com/lavang-0708/TimoKid/pull/9).
- T1-10 **Xong** (PR #10 đã merge): Sổ ôn tập — vòng mốc 1–3–7 ngày, đúng ngay đủ 3 lần thì ra khỏi sổ (`lib/features/review_book/`, `ReviewBookService` dùng `ReviewQueueDao` + `Clock`), mốc hỏi lại 0h ngày VN (sửa sau review, commit `f9fdb4b`). PR: #10 (https://github.com/lavang-0708/TimoKid/pull/10).
- T1-09 **Xong** (PR #11 đã merge, main `a2906c3`): Màn làm toán — đề VI/EN, từ khóa song ngữ, trắc nghiệm trộn đáp án, bàn phím số, gợi ý/lời giải, xu theo bảng (c), ghi `attempts` + cập nhật bậc/thành thạo + ghi sổ ôn tập (`lib/features/math/`, `lib/features/rewards/`, `lib/features/stage_result/`), bố cục 2 cột vừa 640x320/800x360/1280x800, nút ≥ 56x56 dp. PR: #11 (https://github.com/lavang-0708/TimoKid/pull/11). Claude sửa thêm trên nhánh trước khi merge: bỏ `convertFlutterSurfaceToImage` gọi lặp trong `takeShot`, bọc `SingleChildScrollView` cho màn Kết quả chặng (tràn 27 px ở 640x320).
- T1-11 **Xong** (PR #12 đã merge): Ví xu — `RewardConfig` đọc từ `settings`, `RewardService` cộng thưởng (câu/chặng/đề ngày) và đọc số dư từ `wallet_ledger` (`lib/features/rewards/`), 14 unit test mới gồm nghiệm thu (c) 120 xu + 1 kim cương. PR: #12 (https://github.com/lavang-0708/TimoKid/pull/12).
- T1-12 **Đang làm**: Màn Thị trấn tạm — 5 nút khu theo DESIGN hiện trạng thái chặng hôm nay + thanh tiến độ đề ngày + số xu/kim cương qua `RewardService.balances` (`lib/features/town/`), icon app thật (adaptive icon mặt thỏ), đề song ngữ + hai cột căn giữa (PLAN điểm (l)), âm thanh 4 file WAV qua `SoundService` + `audioplayers` và phông Nunito toàn app (PLAN điểm (m), chỉ phần âm thanh + phông; phần giao diện của (m) là T1-15). PR: #13 (https://github.com/lavang-0708/TimoKid/pull/13).
- Các nhiệm vụ còn lại của bản 0.1 (T1-13, T1-14): **Chưa bắt đầu**. T1-15 "Màn làm toán sinh động" (phần giao diện của PLAN điểm (m)): **Chưa bắt đầu**, làm sau khi PR T1-12 mở.
- T2-01 **Đang làm**: Quy trình nạp hình — `assets/manifest.json` (72 mục: 5 icon khu đã có + 67 mục `planned`) định "hợp đồng" file cho bộ hình 0.2 (10 mã lớp, 8 bậc chồng, khung nhân vật 1024x1536, pet/đồ vật 512x512, tên `<dáng>_<lớp>_<tên món>.png`, lớp đổi màu tô xám, file `_line` riêng), script kiểm tra `tools/assets/check_assets.py` (Python, chỉ dùng thư viện chuẩn) + 18 test + tài liệu hợp đồng `docs/ASSETS.md` + test Dart gọi script trong `flutter test`. PR: #15 (https://github.com/lavang-0708/TimoKid/pull/15).
- **Claude merge PR** (anh Điệp giao).

## Điểm cần biết khi tiếp tục

- **Muse không đẩy được file nhị phân lên GitHub qua MCP** (kênh push-files chỉ nhận file text UTF-8; thử đẩy base64 qua `push_files` thì file lên sai dạng text). Quy tắc từ nay (Claude chốt sau review PR #2): Muse liệt kê file nhị phân cần có trong mục "Việc còn lại" của PR (đường dẫn, cách sinh), Claude commit bằng git lên nhánh PR. Áp dụng ở T1-02: (1) ảnh golden nhúng base64 trong `app/test/goldens/golden_data.dart`, test tự giải mã ra PNG trước khi so sánh; (2) chưa có icon launcher riêng — `AndroidManifest.xml` bỏ `android:icon`, app dùng icon mặc định của hệ thống, icon thật làm ở T1-12. Đính chính 19/11: `get_file_contents` qua `call-read-tool` TẢI ĐƯỢC file nhị phân (`content[1].resource.blob` là base64) — chỉ có ĐẨY nhị phân là không được. Từ 19/11, ảnh PNG đẩy qua đường vòng base64: mỗi ảnh thành file text `.b64` vào `app/assets/_incoming/` trên nhánh PR, tên `<đường dẫn đích>.b64`; Claude có script giải mã thành PNG đúng đường dẫn, xóa file `.b64` và commit lên cùng nhánh (`tools/assets/decode_incoming.py`, anh Điệp chốt 19/11, Muse làm hết phần cắt/vẽ hình từ T2-01 trở đi).
- **`gradle-wrapper.jar` không cần commit**: file này nằm trong `app/android/.gitignore` của template vì flutter tool tự sinh khi build (`injectGradleWrapperIfNeeded` trong flutter_tools). T1-03 KHÔNG tải jar hay commit bằng Actions như dự định ban đầu. Tương tự, `gradlew`/`gradlew.bat` cũng tự sinh, nhưng đã commit kèm ở T1-02 nên cứ để đó.
- CI chạy trên GitHub Actions, ghim Flutter 3.50.0. Máy Muse không có Android SDK nên không chạy được `flutter build apk` hay máy ảo ở local — CI là nơi kiểm chứng. Workflow release cần 4 secrets ký APK (xem `docs/RELEASE.md`); thiếu secrets thì job dừng với thông báo rõ ràng, không build bản ký debug.
- **Database T1-04**: Drift 2.35.4 + drift_flutter 0.3.1, schema v1, 7 bảng (`children`, `attempts`, `skill_progress`, `review_queue`, `daily_sets`, `wallet_ledger`, `settings`). File sinh bởi build_runner (`app_database.g.dart`, `daos.g.dart`) được commit cùng code vì CI chưa có bước build_runner. Chi tiết schema và các quyết định xem `docs/DECISIONS.md` (mục 17/11/2026 — T1-04).
- **Clock**: mọi code lấy thời gian qua lớp `Clock` (`lib/core/time/clock.dart`); giờ Việt Nam = UTC+7 cố định, không cần gói `timezone`. Test dùng `FakeClock`.
- Flutter SDK của Muse: `~/workspace/flutter-sdk/flutter`, bản 3.50.0 stable, Dart 3.14.0. Build APK và máy ảo chỉ qua GitHub Actions (T1-03).
- **Hình vẽ T1-06**: `flutter_svg` 2.4.0; `buildFigureSvg` sinh chuỗi SVG khớp từng ký tự với các hàm `svg_*` của `gen.py`; golden 7 hình nhúng base64 trong `app/test/goldens/figure_golden_data.dart` (test tự giải mã ra PNG trước khi so sánh); ảnh chụp 7 dạng ở `docs/screenshots-t1-06/` chỉ lưu local, không đẩy lên GitHub (file nhị phân).

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
- T1-05: bộ sinh câu nằm ở `app/lib/features/questions/` (model `question.dart`, 5 file generator theo mảng, `question_registry.dart` liệt kê đủ 48 dạng). Số cặp form×mức thật là **103**, không phải 89 như ghi lúc đầu — đếm lại từ `gen.py` và `questions.json` đều ra 103. Mỗi `Question` giữ `params` (tham số đã dùng) để test giải lại độc lập, và `figure` (`FigureSpec`) để T1-06 sinh SVG. Nhánh `task/T1-05-generator` tách từ main cũ (`04dfe35`); sau khi mở PR sẽ merge main mới (`fa956e4`, có CI) vào nhánh.
- T1-08: nhánh `task/T1-08-de-ngay` định tách từ `task/T1-07-thang-ai`, nhưng `create_branch` không nhận tên nhánh ở `from` nên nhánh mới rơi về main (`d965746`) — đã kiểm chứng bằng `call-read-tool` (nhánh mới không có `ladder_service.dart`, nhánh T1-07 thì có). Cách xử lý: lần push của T1-08 đẩy kèm toàn bộ file T1-07 (ladder + sửa `daos.dart` + docs) nên diff PR vẫn gồm cả T1-07 như chủ ý; sau khi PR #8 merge, Claude gộp main vào nhánh này như các lần trước (nội dung T1-07 trùng nhau nên gộp sạch). Đề ngày: `DailySetService` (`lib/features/daily_set/`) dùng `LadderService` + DAO T1-04 (`DailySetsDao`, `ReviewQueueDao` đã có sẵn từ T1-04, không cần viết DAO mới); `answerType` lưu trong đề là kiểu hiển thị (theo bậc, trừ dạng choiceOnly luôn trắc nghiệm).
- T1-10: nhánh `task/T1-10-so-on-tap` tách từ main mới (`005f3d2`), song song với T1-09 trên nhánh riêng; PR T1-10 mở trước PR T1-09. Sổ ôn tập: `ReviewBookService` (`lib/features/review_book/`) dùng `ReviewQueueDao` + `Clock` của T1-04, không đổi schema hay DAO; T1-09 sẽ gọi `recordAnswer`/`recordReviewAnswer` sau mỗi lượt trả lời.
- T2-01: hợp đồng hình nằm ở `assets/manifest.json` + `docs/ASSETS.md` (xem chi tiết trong `docs/DECISIONS.md` mục 19/11/2026 — T2-01). Thêm hình mới chỉ cần thả file đúng khung/tên/thư mục rồi thêm một dòng manifest, chạy `python3 tools/assets/check_assets.py` phải báo OK. Ảnh PNG đưa lên repo bằng đường vòng base64 (`app/assets/_incoming/<đường dẫn đích>.b64`, giải mã bằng `tools/assets/decode_incoming.py`); thư mục `_incoming/` không nằm trong diện kiểm tra của script. Bước CI trực tiếp chạy script chưa lên được (Muse không đẩy được file workflow, xem mục "Việc còn lại" của PR T2-01) — trong lúc chờ, test Dart `app/test/assets_manifest_test.dart` đã gọi script trong bước `flutter test` sẵn có.
