# HANDOVER — TimoKid

Cập nhật cuối: 17/11/2026 (nhiệm vụ T1-02, nhánh `task/T1-02-khung-app`).

## Trạng thái hiện tại

- `main` đang ở commit `c0eca20` — PLAN.md đã có mục "Làm rõ ngày 17/11" (a–j), ghi đè mọi chỗ khác trong kế hoạch.
- T1-01 **Chờ merge**: PR #1 (https://github.com/lavang-0708/TimoKid/pull/1) đã được Claude review Đạt. Nhánh T1-02 này tách từ `main` trước khi PR #1 merge nên mang theo lại các file của T1-01; rebase sau khi PR #1 merge.
- T1-02 **Đang làm**: khung app Flutter (package `vn.timokid.app`, 3 màn trống, mở đầu vào Thị trấn). PR: #2 (https://github.com/lavang-0708/TimoKid/pull/2).
- Các nhiệm vụ còn lại của bản 0.1 (T1-03 đến T1-14): **Chưa bắt đầu**.

## Điểm cần biết khi tiếp tục

- **Muse không đẩy được file nhị phân lên GitHub qua MCP** (kênh push-files chỉ nhận file text UTF-8; thử đẩy base64 qua `push_files` thì file lên sai dạng text). Vì vậy T1-02 có 3 chỗ làm khác thường, ghi trong `docs/DECISIONS.md`: (1) ảnh golden nhúng base64 trong `app/test/goldens/golden_data.dart`, test tự giải mã ra PNG trước khi so sánh; (2) chưa có icon launcher riêng — `AndroidManifest.xml` bỏ `android:icon`, app dùng icon mặc định của hệ thống, icon thật làm ở T1-12; (3) thiếu `app/android/gradle/wrapper/gradle-wrapper.jar` nên `flutter build apk` chưa chạy được — T1-03 bổ sung trong CI (tải jar chuẩn của Gradle 9.5.0 trong workflow rồi commit bằng git của Actions, hoặc cài Gradle hệ thống). `flutter analyze` và `flutter test` vẫn chạy đủ trên máy Muse.
- Flutter SDK của Muse: `~/workspace/flutter-sdk/flutter`, bản 3.50.0 stable, Dart 3.14.0. Build APK và máy ảo chỉ qua GitHub Actions (T1-03).

## Cách build và chạy test

- Ngân hàng câu hỏi (không cần Flutter):

  ```sh
  python3 tools/question_bank/check.py
  # kỳ vọng: questions: 267 | bad: 0 | unchecked: []
  ```

- Flutter SDK của Muse nằm ở `~/workspace/flutter-sdk/flutter` (bản stable, cài theo mục (j) trong PLAN). Chạy `flutter analyze`, unit test và widget test local; build APK và test máy ảo chạy trên GitHub Actions.
- Bản 0.1 chưa có code app; `app/` mới là thư mục rỗng (giữ bằng `.gitkeep`, T1-02 sẽ xóa khi chạy `flutter create`).

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
