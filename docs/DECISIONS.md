# DECISIONS — TimoKid

Mỗi quyết định: ngày, nội dung, lý do, ai quyết. Chi tiết đầy đủ nằm ở mục "Làm rõ ngày 17/11" trong `docs/PLAN.md`; file này chỉ ghi lại để tra cứu nhanh.

## 17/11/2026 — Các điểm làm rõ sau review kế hoạch (Claude chốt)

- (a) "Dạng bài" = một `form` trong `gen.py` (48 generator). Mỗi generator chỉ sinh ở mức nó hỗ trợ; không tự soạn mức mới. Lý do: số liệu thật là 48 form, 89 cặp form×mức; soạn mức mới là việc nội dung, không phải port code.
- (b) Thành thạo = đúng ngay lần đầu 4/5 câu gần nhất ở mức cao nhất dạng hỗ trợ, không thấp hơn Vừa nếu dạng có Vừa. Lý do: 11 form không có mức Khó vẫn thành thạo được.
- (c) Thứ tự thưởng: xu gốc → chia đôi làm tròn lên (đúng sau gợi ý) → nhân đôi (câu ôn tập). Test T1-11: bậc 3–4, sổ trống, đúng hết 25 câu = 120 xu. Lý do: khoảng 100–130 chỉ là mục tiêu thiết kế, không phải tiêu chí test cho mọi trường hợp.
- (d) Câu `choiceOnly` (compare, weekday, parityrule) có tiêu chí nghiệm thu riêng ở T1-05. Lý do: kiểm tra "số dương / 3 đáp án nhiễu" không áp dụng cho câu chọn.
- (e) T1-04 giữ 7 bảng. `inventory` tạo ở T2-05, `pets` ở T2-07 (migration). `families`, `messages`, `custom_questions`, `content_packs` thuộc bản 0.3/0.5. Ngoại lệ cột: `children` không có `child_id` (có `family_id` để trống tới 0.3); `settings` có `child_id` để trống cho cài đặt chung.
- (f) "Đúng" luôn là đúng ngay lần đầu cho lên bậc, xuống bậc và thành thạo. Giữ quy tắc tính lại từ 10 câu mới sau mỗi lần đổi bậc.
- (g) Đề ngày: thiếu dạng thì được lặp (ưu tiên dạng ít gặp nhất 7 ngày gần đây). Câu ôn tập dùng bậc lưu trong `review_queue`; trùng dạng thì giữ câu ôn tập, đổi dạng câu kia.
- (h) Integration test máy ảo tách workflow riêng (chạy khi đổi `app/lib/**` phần giao diện hoặc gắn nhãn `ui`), ngân sách 25 phút; workflow chính giữ dưới 15 phút. Tag phát hành do Muse tạo sau khi Claude kết luận Đạt. Ký APK chờ keystore của anh Điệp.
- (i) Nghiệm thu T1-01 là log chạy tay `check.py`. Menu QA ở góc trên bên trái. `Clock` theo `Asia/Ho_Chi_Minh`. Bản 0.1 vào thẳng Thị trấn tạm.
- (j) Muse được cài Flutter SDK trong workspace của mình để chạy `flutter create`, `analyze`, unit/widget test. Build APK và test máy ảo qua GitHub Actions.

Người quyết: Claude (review và chốt thay anh Điệp), sau câu hỏi review của Muse ngày 17/11/2026. Commit ghi nhận: `c0eca20`.

## 17/11/2026 — Sửa `.gitignore` cho keystore (góp ý review PR #1, Claude chốt)

Đổi `app/key.properties` thành `**/key.properties`, vì Flutter đặt file này ở `app/android/key.properties`, không phải `app/key.properties`. Sửa trong PR T1-02. Người quyết: Claude.

## 17/11/2026 — Cách xử lý file nhị phân vì MCP chỉ đẩy được file text (Muse quyết, ghi để Claude/anh Điệp biết)

Muse đẩy file lên GitHub qua MCP chỉ được file text UTF-8; thử đẩy PNG dạng base64 qua `push_files` thì file lên sai dạng text (đã thử và đã xóa). Vì vậy:
- Ảnh golden nhúng base64 trong `app/test/goldens/golden_data.dart`; `golden_test.dart` giải mã ra PNG trước khi so sánh. Ảnh nhúng là ảnh kỳ vọng thật nên phép so sánh vẫn có giá trị.
- Chưa có icon launcher riêng: bỏ `android:icon` khỏi `AndroidManifest.xml`, app dùng icon mặc định của hệ thống; icon thật làm ở T1-12 cùng art Thị trấn.
- Thiếu `app/android/gradle/wrapper/gradle-wrapper.jar` (file nhị phân): `flutter build apk` chưa chạy được; T1-03 bổ sung trong CI (tải jar chuẩn Gradle 9.5.0 trong workflow rồi commit bằng git của Actions, hoặc cài Gradle hệ thống). `flutter analyze` và `flutter test` không cần jar này.

## 17/11/2026 — Claude chốt sau review PR #2 (ghi đè phần gradle-wrapper.jar ở trên)

- **`gradle-wrapper.jar` tự sinh, không cần tải hay commit**: file nằm trong `app/android/.gitignore` của template vì flutter tool tự sinh khi build (`injectGradleWrapperIfNeeded`). Đính chính quyết định T1-02 ở trên: T1-03 KHÔNG tải jar, KHÔNG commit jar bằng Actions.
- **File nhị phân từ nay**: Muse liệt kê trong mục "Việc còn lại" của PR (đường dẫn, cách sinh), Claude commit bằng git lên nhánh PR của Muse.
- **Từ nay Claude merge PR** (anh Điệp giao việc merge cho Claude).

## 17/11/2026 — T1-04: schema 7 bảng và cách chặn sửa/xóa lịch sử (Muse thiết kế, chờ Claude duyệt trong PR #4)

DESIGN.md chỉ mô tả mỗi bảng bằng một dòng nên Muse tự thiết kế cột cụ thể, căn theo nhu cầu của T1-07 (thang ải), T1-08 (đề ngày), T1-09 (màn làm toán), T1-10 (sổ ôn tập), T1-11 (ví xu):

- `children`: `id` UUID, `name`, `grade` (mặc định 2), `family_id` nullable. Không có cột `child_id` (mục (e)).
- `attempts`: `child_id`, `form_id`, `strand`, `level` (1–3), `rung` (1–6), `answer_type` (`choice`/`number`), `correct_first_try`, `attempts_count`, `duration_ms`, `is_review`, `daily_set_id` nullable, `stage` nullable, `question_seed` nullable. `strand` lưu riêng (dù suy được từ tiền tố `form_id`) để T1-07 truy vấn theo mảng không phải tách chuỗi.
- `skill_progress`: một bảng, hai loại dòng theo `scope`: `strand` (`key` = mã mảng, `rung` bậc 1–6, `window_started_at` mốc bắt đầu cửa sổ 10 câu sau lần đổi bậc) và `form` (`key` = `form_id`, `mastered`, `mastered_at`). Unique (`child_id`, `scope`, `key`).
- `review_queue`: `child_id`, `form_id`, `rung` (bậc đã lưu, câu ôn tập dùng bậc này — mục (g)), `due_date`, `correct_streak` (0–3). Unique (`child_id`, `form_id`) — một dạng chỉ có một mục trong sổ.
- `daily_sets`: `child_id`, `date` (`YYYY-MM-DD` giờ Việt Nam, dạng text), `questions` (JSON 25 câu: `formId`, `strand`, `level`, `rung`, `answerType`, `isReview`, `seed`), `stage_status` (JSON 5 trạng thái chặng), `completed`, `completed_at`. Unique (`child_id`, `date`). Không tách bảng con vì PLAN chốt đúng 7 bảng.
- `wallet_ledger`: `child_id`, `currency` (`xu`/`gem`), `amount` có dấu (âm = trừ), `reason`, `ref_id` nullable. Số dư = `SUM(amount)` theo từng loại tiền.
- `settings`: `child_id` nullable (null = cài đặt chung), `key`, `value` (JSON để lưu mọi kiểu). Cài đặt riêng bé được ưu tiên hơn cài đặt chung (`getEffectiveValue`).

Các quyết định kèm theo:

- **Chặn sửa/xóa hai bảng append-only bằng trigger SQLite** (`attempts_no_update/delete`, `wallet_ledger_no_update/delete`, `RAISE(ABORT, ...)`), tạo trong `onCreate` cùng file DB nên còn hiệu lực sau khi tắt/mở app. DAO của hai bảng này cũng không có hàm sửa/xóa — hai lớp chặn độc lập, test kiểm tra cả hai (SQL thô bị chặn, dòng còn nguyên).
- **Commit cả file `.g.dart` sinh bởi build_runner** (`app_database.g.dart`, `daos.g.dart`): CI chưa có bước build_runner (PR #3 chưa merge) nên nếu không commit thì code trên CI không biên dịch được. Khi CI có bước build_runner thì xem lại.
- **`Clock` không dùng gói `timezone`**: giờ Việt Nam là UTC+7 cố định, không có giờ mùa hè, nên `SystemClock` = giờ UTC + 7 giờ. Test dùng `FakeClock` (đặt/giờ trôi tay).
- **Hồ sơ bé mặc định tên "Bé", lớp 2**: DESIGN chốt "bé tự đặt tên, app không có tên đặt sẵn" cho luồng tạo nhân vật (T2-03); tên "Bé" ở đây chỉ là chỗ giữ tạm cho bản 0.1 để màn Thị trấn và đề ngày có hồ sơ mà chạy, sẽ đổi khi có màn tạo nhân vật.
- **Hạt giống mặc định**: bậc 1 cho cả 5 mảng; cài đặt chung `rewards` theo bảng thưởng T1-11 (`easy:2, medium:3, hard:5, stage_complete:5, daily_complete_xu:20, daily_complete_gem:1, mastery_gem:2`), `sound_enabled`/`music_enabled` = true. `ensureSeeded()` gọi lại nhiều lần an toàn.
- **`insertOnConflictUpdate` của Drift chỉ nhắm vào khóa chính**: upsert theo unique (`child_id`, `scope`, `key`) bị lỗi `UNIQUE constraint failed` vì `id` UUID mới mỗi lần gọi; vì vậy `SkillProgressDao` tự kiểm tra rồi cập nhật (cùng cách đã dùng cho `ReviewQueue` và `Settings`). Phát hiện nhờ test rớt, đã sửa và test lại xanh.
- **Unique trên `child_id` nullable không bắt được trùng khóa chung** (SQLite coi NULL là khác nhau): `SettingsDao.setValue` tự kiểm tra rồi cập nhật thay vì dựa vào `ON CONFLICT`.
- **Thêm gói `uuid` (4.6.0)**: sinh id UUID v4 cho mọi dòng, gói Dart thuần, không có dịch vụ ngoài.

## 17/11/2026 — Vị trí Flutter SDK của Muse

Flutter SDK stable đặt tại `~/workspace/flutter-sdk/flutter` (nằm trong workspace nên tồn tại qua các lần thay máy ảo). Dùng cho `flutter create`, `analyze`, unit test và widget test. Không dùng để build APK hay chạy máy ảo — hai việc đó qua GitHub Actions. Người quyết: Claude (mục (j) ở trên).

## 18/11/2026 — T1-06: sinh SVG từ FigureSpec

- **Giữ đúng hình học của `gen.py`**: `buildFigureSvg` trong `app/lib/features/questions/figure_svg.dart` viết lại từng dòng các hàm `svg_grid`/`svg_fan`/`svg_path_grid` (cùng lề, cùng thứ tự kẻ, cùng tọa độ) nên chuỗi SVG khớp từng ký tự với `gen.py` cho cùng tham số — test so sánh chuỗi (`figure_svg_test.dart`, 7 trường hợp đại diện) là bằng chứng. Nét `#333` dày 3 như `gen.py`, đã đủ đậm; `FigureView` chỉ co giãn toàn bộ hình theo tỉ lệ nên nét giữ nguyên tỉ lệ.
- **Thêm gói `flutter_svg` 2.4.0** (duy nhất): hiển thị SVG bằng `SvgPicture.string` trong widget `FigureView`. Widget nhận `FigureSpec` và chiều rộng hiển thị tùy chọn (bỏ trống: dùng kích thước tự nhiên từ `figureSvgSize`).
- **Golden test 7 hình** (`figure_golden_test.dart`): countsq 2x3, countrect 1x4, counttri quạt 3 đoạn, matches 1 hàng 4 ô, matches 2 hàng 3 ô, shapeperim 1 hàng 3 ô, gridpath 2x2. Ảnh kỳ vọng nhúng base64 trong `app/test/goldens/figure_golden_data.dart`, test tự giải mã ra PNG trước khi so sánh (mẫu T1-02); đã kiểm chứng tự phục hồi bằng cách xóa PNG rồi chạy lại test. Chữ A/B trong lưới đường đi dùng font-family `sans-serif` của `gen.py` nên test nạp DejaVu Sans làm cả hai font 'Roboto' và 'sans-serif'.
- **Ảnh chụp cho Claude đếm lại bằng mắt**: 7 ảnh PNG 2x trong `docs/screenshots-t1-06/` (chỉ lưu local, không đẩy lên GitHub vì file nhị phân). File test chụp ảnh (`figure_screenshots_test.dart`) đã XÓA khỏi repo vì nó làm treo tiến trình test khi tắt (`Bad state: Cannot add event while adding stream` sau khi chụp xong bằng `RepaintBoundary.toImage` trong `tester.runAsync`) — ảnh đã chụp xong một lần, golden test là kiểm chứng lặp lại được.

## 18/11/2026 — T1-07: thang ải và thành thạo (Muse thiết kế, chờ Claude duyệt)

- **Mọi ngưỡng ở một chỗ duy nhất** (`app/lib/features/ladder/ladder_config.dart`, `LadderConfig`): bậc 1–6, bậc khởi đầu 1, cửa sổ 10 câu, lên bậc ≥ 8 đúng ngay, xuống bậc < 5 đúng ngay, cửa sổ thành thạo 5 câu, cần 4 đúng ngay, mức thành thạo tối thiểu Vừa (2). Không viết cứng số nào ở service hay test — test tham chiếu hằng số qua hành vi (vd: 8/10 lên, 7/10 không lên) chứ không đọc trực tiếp số.
- **Ánh xạ bậc → mức và kiểu trả lời** cũng nằm trong `LadderConfig` (`levelForRung`, `answerTypeForRung`): bậc 1–2 Dễ, 3–4 Vừa, 5–6 Khó; bậc lẻ trắc nghiệm, bậc chẵn điền số. Ngoại lệ: dạng `choiceOnly` (compare, weekday, parityrule) luôn trắc nghiệm ở mọi bậc — do generator quyết, thang ải không ép.
- **Mức thành thạo của dạng** (`masteryLevelForForm`, mục (b)): mức cao nhất dạng hỗ trợ, nhưng không thấp hơn Vừa nếu dạng có Vừa. Ví dụ: `{1,2,3}` → 3, `{1,2}` → 2, `{1}` → 1, `{2}` → 2, `{3}` → 3. Cả 48 dạng đều thành thạo được.
- **Service thuần Dart** (`app/lib/features/ladder/ladder_service.dart`, `LadderService`): dùng `AttemptsDao` + `SkillProgressDao` của T1-04, không gọi giờ trực tiếp (DAO tự lấy `db.clock.now()`). API cho T1-08 dùng tiếp: `rungFor`/`rungsFor` (chưa có dòng thì bậc 1), `evaluateStrand` (đánh giá cửa sổ 10 câu, trả `RungEvaluation` ghi rõ bậc cũ/mới, số đúng, cửa sổ đủ hay chưa), `evaluateFormMastery`/`isFormMastered`/`masteredForms`.
- **Cửa sổ 10 câu reset sau đổi bậc**: `evaluateStrand` chỉ đọc các lượt có `createdAt` sau `windowStartedAt` (mốc DAO đặt lại mỗi lần `setStrandRung` đổi bậc), giới hạn 10 câu mới nhất; chưa đủ 10 câu thì không đánh giá. Test chứng minh reset: lên bậc xong, 8 câu mới đúng ngay chưa đủ cửa sổ nên không đổi bậc; đủ 10 câu mới 10/10 mới lên tiếp.
- **Câu ôn tập vẫn tính vào cửa sổ thang ải**: luật chỉ nói "10 câu gần nhất của mảng", không loại trừ câu ôn tập (`isReview`) nên service đếm tất cả. Nếu Claude muốn loại trừ thì đổi một chỗ trong `evaluateStrand`.
- **Thành thạo chỉ tính câu ở đúng mức thành thạo**: thêm tham số `level` (tùy chọn) cho `AttemptsDao.getRecentFormAttempts` — thay đổi duy nhất vào code T1-04, không đổi schema. Câu làm ở mức thấp hơn không tính vào cửa sổ 5 câu (test dạng `{1,2}`: 5 câu mức Dễ đúng hết vẫn chưa thạo, 4/5 câu mức Vừa mới thạo).
- **Test dùng `FakeClock` và cho đồng hồ trôi 1 phút mỗi lượt trả lời**: `createdAt` phải phân biệt được thì thứ tự cửa sổ mới xác định (các lượt cùng một thời điểm sẽ sắp xếp tùy ý) và các lượt sau mốc `windowStartedAt` mới lọt vào cửa sổ (truy vấn dùng `createdAt > windowStartedAt`).
