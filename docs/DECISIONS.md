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

## 17/11/2026 — Vị trí Flutter SDK của Muse

Flutter SDK stable đặt tại `~/workspace/flutter-sdk/flutter` (nằm trong workspace nên tồn tại qua các lần thay máy ảo). Dùng cho `flutter create`, `analyze`, unit test và widget test. Không dùng để build APK hay chạy máy ảo — hai việc đó qua GitHub Actions. Người quyết: Claude (mục (j) ở trên).
