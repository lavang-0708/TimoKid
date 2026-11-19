# TimoKid

App Android giúp bé lớp 2 ôn thi Olympic Toán TIMO bằng cách giải toán để nuôi pet, thay trang phục nhân vật và mở rộng Thị trấn Diệu Kỳ.

- Thiết kế tổng: `docs/DESIGN.md`
- Kế hoạch triển khai: `docs/PLAN.md` (mục "Làm rõ ngày 17/11" ghi đè mọi chỗ khác)
- Trạng thái hiện tại: `docs/HANDOVER.md`
- Quyết định đã chốt: `docs/DECISIONS.md`

## Cấu trúc repo

- `app/` — app Flutter (từ T1-02)
- `admin/` — web admin cho phụ huynh (từ bản 0.3)
- `assets/` — tài sản hình: `concept/` (phác ý tưởng, chỉ tham khảo), `templates/` (khung vẽ SVG)
- `content/` — hình và gói nội dung thêm về sau
- `tools/` — script Python sinh và kiểm tra ngân hàng câu hỏi mẫu
- `docs/` — DESIGN, PLAN, HANDOVER, DECISIONS, ASSETS

## Ngân hàng câu hỏi

267 câu mẫu, 48 dạng bài (`form`), 5 mảng TIMO, song ngữ Việt – Anh. Kiểm tra độc lập:

```sh
python3 tools/question_bank/check.py
# questions: 267 | bad: 0 | unchecked: []
```

## Quy trình làm việc

Mỗi nhiệm vụ trong `docs/PLAN.md` (mã `T1-01` đến `T5-06`) đi qua đúng một pull request. Không đẩy thẳng lên `main`. Muse viết code, Claude review thay chủ dự án, chủ dự án bấm merge và cài thử APK trên máy thật.

## Bí mật

Không có mật khẩu, khóa hay chuỗi kết nối nào trong repo. Keystore Android và secrets của CI nằm trong GitHub Secrets (xem T1-03 trong PLAN).
