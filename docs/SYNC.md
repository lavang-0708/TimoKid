# Đồng bộ và web admin (bản 0.3)

Tài liệu thiết kế cho T3-01 và T3-02. Claude viết, đã dựng và kiểm thử trên Neon project `timokid`.

## Hạ tầng

| Thành phần | Giá trị |
| --- | --- |
| Neon project | `timokid` (id `lucky-queen-61383087`), vùng AWS Singapore, Postgres 17, compute 0.25 CU, gói miễn phí, tách hẳn khỏi FB_Predict |
| Database | `timokid`, branch `main` |
| Neon Auth (Managed Better Auth) | `https://ep-damp-waterfall-a1cu82wt.neonauth.ap-southeast-1.aws.neon.tech/timokid/auth` |
| Data API (PostgREST) | `https://ep-damp-waterfall-a1cu82wt.apirest.ap-southeast-1.aws.neon.tech/timokid/rest/v1` |
| Web admin | trang tĩnh trong `admin/`, deploy lên GitHub Pages `https://lavang-0708.github.io/TimoKid/` (chủ dự án chọn GitHub Pages thay Cloudflare Pages ngày 21/11) |

Hai URL trên là công khai, được phép nằm trong code. Trong repo không có mật khẩu database hay khóa bí mật nào. App và web admin chỉ dùng JWT của người đăng nhập.

## Tài khoản

- Một tài khoản Neon Auth (email và mật khẩu) là một gia đình. Bố đăng nhập cùng tài khoản trên app của bé (một lần lúc cài) và trên web admin.
- Sau khi đăng nhập, app và web gọi `rpc/ensure_family`. Hàm này tạo dòng `families` nếu chưa có và trả lại gia đình.
- Neon Auth hiện cho mọi người tự đăng ký. Điều này không làm lộ dữ liệu, vì người lạ chỉ tạo được gia đình rỗng của chính họ. Khi Neon có tùy chọn chặn đăng ký thì bật lên.
- Domain được phép chuyển hướng sau đăng nhập: `https://lavang-0708.github.io`. Khi chạy thử ở máy, `localhost` được chấp nhận.

## Schema

Migration nằm ở `db/migrations/0001_init.sql`, đã chạy trên branch `main`.

| Bảng | Loại | Ghi chú |
| --- | --- | --- |
| families | sửa | `owner_user_id` = `auth.user_id()` |
| children | sửa | id do app sinh; `last_synced_at` để web hiện mốc đồng bộ |
| attempts | chỉ thêm | khớp bảng Drift `attempts`; `received_at` do server ghi |
| wallet_ledger | chỉ thêm | khớp bảng Drift `wallet_ledger` |
| skill_progress | sửa | unique (child_id, scope, key) |
| review_queue | sửa | có `deleted_at` thay cho xóa cứng |
| daily_sets | sửa | `questions`, `stage_status` là jsonb |
| settings | sửa | `child_id` null = cài đặt chung của gia đình; unique (family, child, key) |
| messages | sửa | thư và quà từ bố; `claimed_at` chặn nhận quà hai lần |

View cho web admin: `child_daily_stats` (số câu, số câu đúng ngay, thời gian, theo bé, ngày giờ Việt Nam và mảng) và `child_balances` (số dư xu, kim cương). Cả hai đặt `security_invoker`, nên RLS vẫn áp dụng.

`inventory`, `pets`, `custom_questions`, `content_packs` sẽ thêm ở migration sau, khi T2-05/T2-06 chốt dữ liệu trong app và khi tới bản 0.5.

## Phân quyền (RLS)

- Mọi bảng đều bật RLS. Role `anonymous` không có quyền gì.
- `current_family_id()` trả về gia đình của `auth.user_id()`. `is_my_child(child_id)` kiểm tra bé có thuộc gia đình đó không. Hai hàm này chạy với quyền của chủ database, để policy không bị gọi đệ quy.
- Bé và cài đặt: chỉ thấy và ghi trong gia đình mình. Lượt trả lời, ví, bậc, sổ ôn tập, đề ngày: chỉ với bé của gia đình mình.
- `attempts` và `wallet_ledger` chỉ có quyền SELECT và INSERT. Không sửa, không xóa được.
- Trigger chặn đổi `family_id` và `child_id` bằng UPDATE.

## Đồng bộ chiều lên (app → Neon)

- Mỗi bảng trong Drift đã có cờ `synced`. App gom các dòng `synced = false` thành lô (tối đa 200 dòng mỗi bảng) và gửi theo thứ tự `children` → `daily_sets` → `attempts` → `wallet_ledger` → `skill_progress` → `review_queue` → `settings`.
- Bảng chỉ thêm: `POST /attempts?on_conflict=id` với `Prefer: resolution=ignore-duplicates`. Gửi lại cùng id thì bỏ qua, không tạo dòng trùng.
- Bảng có sửa: `POST /<bảng>?on_conflict=id` với `Prefer: resolution=merge-duplicates`. Trigger `keep_newest` giữ dòng có `updated_at` mới hơn, nên lô cũ gửi lại không ghi đè dữ liệu mới.
- Mục bị xóa khỏi sổ ôn tập trong app: gửi dòng có `deleted_at`. App cần giữ một bảng "đã xóa chờ gửi" nhỏ.
- Gửi xong một lô thì đánh `synced = true` cho đúng các id trong lô đó. Lỗi mạng giữa chừng thì lần sau gửi lại cả lô, nhờ upsert theo id nên không trùng.
- Gửi xong toàn bộ thì cập nhật `children.last_synced_at`.

## Đồng bộ chiều xuống (Neon → app)

- Tải `settings` và `messages` có `updated_at > mốc lần trước` (lưu mốc này trong `settings` của máy).
- Mở quà: app gọi `rpc/claim_message`. Lần đầu trả `claimed = true` cùng quà, các lần sau trả `claimed = false`. App ghi dòng `wallet_ledger` với `ref_id` = id thư. Trước khi cộng, app kiểm tra đã có dòng mang `ref_id` đó chưa. Như vậy quà không thể nhận hai lần, kể cả khi đồng bộ lại.
- Xung đột ở `settings`: dòng có `updated_at` mới hơn thắng. Web admin chỉ ghi các khóa của phụ huynh (mức thưởng, khóa kiểu trả lời), app chỉ ghi các khóa của bé (hồ sơ nhân vật...), nên hai bên gần như không ghi trùng một khóa.

## Khi nào đồng bộ

Khi mở app, sau mỗi chặng, và cứ 15 phút khi app đang mở. Chỉ đồng bộ khi có mạng. Lỗi mạng hoặc Neon đang tạm dừng chỉ hiện một biểu tượng nhỏ, không chặn bé chơi.

## Ước tính dung lượng (3 bé, 1 tháng)

- Một lượt trả lời khoảng 0,4 KB JSON. 3 bé × 40 câu × 30 ngày = 3.600 dòng, khoảng 1,5 MB tải lên.
- Ví khoảng gấp đôi số lượt, khoảng 2 MB. Đề ngày khoảng 6 KB mỗi đề, 90 đề khoảng 0,5 MB. Bậc, sổ ôn tập, cài đặt không đáng kể.
- Tải về (thư, cài đặt) và web admin xem thống kê qua view gộp: dưới 20 MB một tháng.
- Tổng egress dưới 30 MB một tháng, khoảng 0,6% hạn mức 5 GB. Dung lượng database dưới 10 MB một năm.

## Kiểm thử

`db/tests/rls_test.py` chạy trên Data API thật, với 2 tài khoản thử đăng ký mới mỗi lần chạy. Bài kiểm thử chứng minh:
- Gia đình B không đọc, không ghi, không sửa được dữ liệu của gia đình A.
- `attempts` và `wallet_ledger` không sửa, không xóa được.
- Gửi lại cùng một lô không tạo dòng trùng.
- Dòng cũ hơn không ghi đè dòng mới hơn.
- Quà chỉ nhận được một lần.
- Không có JWT thì không đọc được gì.

Chạy xong thì dọn tài khoản thử bằng `db/tests/cleanup_test_accounts.sql` (chạy với role chủ database).

Kết quả ngày 21/11: 27/27 mục đạt.
