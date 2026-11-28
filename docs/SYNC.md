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

## Phía app (T3-03, T3-04, T3-06)

Code nằm ở `app/lib/core/sync/` (cấu hình, máy khách Neon, bộ đồng bộ, provider), `app/lib/features/auth/` (đăng nhập, cổng phụ huynh, cài đặt), `app/lib/features/profile/` (nhiều bé) và `app/lib/features/mailbox/` (thư và quà).

- **Cấu hình:** `sync_config.dart` chứa hai URL công khai, ghi đè được bằng `--dart-define=TIMOKID_AUTH_URL=... --dart-define=TIMOKID_API_URL=...`. Neon Auth kiểm `Origin` nên app gửi `https://lavang-0708.github.io` (domain đã được phép của web admin; đổi bằng `TIMOKID_AUTH_ORIGIN`). Không có khóa bí mật nào trong app.
- **Đăng nhập:** `POST {auth}/sign-in/email` (hoặc `sign-up/email`) trả cookie phiên. App giữ cookie trong `flutter_secure_storage` (Android Keystore), cùng email; không lưu mật khẩu, không lưu JWT, không ghi log token. JWT ngắn hạn lấy từ `GET {auth}/token` kèm cookie, giữ trong bộ nhớ, tự làm mới khi sắp hết hạn hoặc khi Data API trả 401. Sau đăng nhập gọi `rpc/ensure_family` (bộ đồng bộ cũng gọi lại một lần mỗi lần chạy app).
- **Lần đầu mở app** (và máy cài đè bản cũ): màn "Bố/mẹ đăng nhập" với nút "Dùng không cần tài khoản" nổi bật. Bấm bất kỳ nút nào thì không hỏi lại (khóa chung `sync_login_prompt_done`). Không đăng nhập thì app chạy đủ, không gọi mạng. Đăng nhập/đăng xuất sau này: bấm biểu tượng đám mây trên HUD, trả lời phép nhân ba chữ số (cổng phụ huynh), vào Cài đặt cho bố/mẹ (đăng nhập, đăng xuất, đồng bộ ngay, đổi bé, thêm bé). Đăng xuất chỉ xóa phiên, dữ liệu trên máy còn nguyên.
- **Nhiều bé:** bé đang chơi lưu ở khóa chung `active_child_id` (chỉ trên máy). `AppDatabase.ensureSeeded()` trả bé này (chưa chọn hoặc không còn thì bé tạo sớm nhất), nên mọi màn cũ dùng đúng bé được chọn. Dữ liệu máy cũ luôn thuộc bé đầu tiên. Có từ 2 bé thì sau màn khởi động hiện màn chọn bé. "Thêm bé" (sau cổng phụ huynh) tạo hồ sơ + bậc 1 và đi qua mở đầu như bé đầu tiên.
- **Drift schema v5:** thêm bảng `messages` (thư đã tải) và `review_tombstones` (mục sổ ôn tập đã xóa chờ gửi). Trigger SQLite: sửa bất kỳ dòng nào của bảng có sửa mà không tự đặt `synced` thì đặt lại `synced = 0`; xóa mục `review_queue` thì ghi tombstone; trigger append-only của `attempts`/`wallet_ledger` nay cho phép UPDATE khi chỉ đổi cột `synced`.
- **Giờ:** app lưu giờ Việt Nam kiểu "UTC + 7 gắn nhãn UTC" (`Clock.now`). Khi gửi trừ 7 giờ thành thời điểm thật; khi tải về cộng lại (`toServerTime`/`fromServerTime`).
- **Chiều lên:** đúng như mục trên. Chi tiết thêm: `on_conflict=id` với mọi bảng; `Prefer: return=minimal`; chỉ đánh dấu `synced` các dòng của lô thành công và chưa bị sửa từ lúc đọc; lỗi giữa chừng thì dừng cả lượt, lượt sau gửi lại. `settings`: chỉ gửi dòng của bé (`child_id` khác null), bỏ khóa chỉ có ý nghĩa trên máy (`active_child_id`, `onboarding_completed`, `sound_enabled`, `music_enabled`, `sync_*`); dòng chung (vd `rewards`) chỉ tải về, server luôn thắng. Mục sổ ôn tập đã xóa gửi như dòng `review_queue` có `deleted_at`. Thư đã mở trên máy gửi bằng `PATCH messages` (`opened_at`). Cuối lượt gửi: `PATCH children` đặt `last_synced_at`. Chỉ mục duy nhất của `settings` là chỉ mục biểu thức nên không upsert theo khóa được: mỗi lượt tải `settings` TRƯỚC khi gửi, và dòng máy có cùng (bé, khóa) với dòng server thì đổi `id` thành id server, nhờ đó gửi lên đúng dòng, không tạo dòng trùng.
- **Chiều xuống:** `settings` và `messages` với `updated_at > mốc`; mốc lưu ở khóa `sync_settings_mark`, `sync_messages_mark` (lấy từ chính `updated_at` của server, không dùng đồng hồ máy). Cài đặt của bé: `updated_at` mới hơn thắng.
- **Mở quà:** `MailboxService.claim` gọi `rpc/claim_message`. Chỉ khi `claimed = true` và chưa có dòng `wallet_ledger` nào có `ref_id` = id thư mới cộng xu/kim cương (lý do `mail_gift`); món đồ vào `inventory` (nguồn `gift`, bỏ qua nếu đã có). Mở thư đánh dấu đã đọc và gửi `opened_at`; lỗi mạng khi mở quà thì chưa cộng gì, thử lại được.
- **Khi nào đồng bộ:** mở app, sau mỗi chặng (`MathScreen`), mỗi 15 phút khi đã đăng nhập, khi app quay lại từ nền, sau đăng nhập, sau mở thư/quà. Không kiểm tra kết nối trước: cứ thử, lỗi mạng thì hiện biểu tượng mất mạng. Trạng thái trong biểu tượng đám mây `sync-status-icon` ở HUD Phòng và Thị trấn: chưa đăng nhập, đang đồng bộ, đã đồng bộ, mất mạng, lỗi.
- **Bảng thêm (`0002_app_tables.sql`):** `inventory`, `pets`, `arena_attempts`. App chỉ gửi ba bảng này khi `syncExtraTablesEnabled = true` (mặc định `false` trong `sync_config.dart`). Chủ dự án chạy `db/migrations/0002_app_tables.sql` trên Neon rồi đổi cờ thành `true`; bật cờ khi bảng chưa có sẽ làm mọi lượt đồng bộ báo lỗi 404.
- **Kiểm thử app:** `app/test/core/sync/` (bộ đồng bộ, máy khách Neon, Neon giả `FakeNeon` dùng `MockClient`, không gọi mạng thật), `app/test/features/{auth,profile,mailbox}/`, `app/test/core/database_v5_migration_test.dart`.

## Kiểm thử thật phía app (28/11/2026)

- Đã chạy `db/migrations/0002_app_tables.sql` trên Neon (thêm `inventory`, `pets`, `arena_attempts`) và bật `syncExtraTablesEnabled`.
- `app/test_real/neon_smoke_test.dart` (không chạy trong CI) đăng ký tài khoản `rls-app-*@example.com`, đồng bộ dữ liệu mẫu của mọi bảng, gửi lại không tạo dòng trùng, bố gửi thư có quà (50 xu, 2 kim cương), app tải thư về và mở quà hai lần: cộng đúng một lần, server ghi `claimed_at`. Kết quả: đạt. Sau đó dọn tài khoản thử bằng `db/tests/cleanup_test_accounts.sql` (mẫu `rls-%` gồm cả `rls-app-%`).
