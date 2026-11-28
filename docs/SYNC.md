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

## Đề tự soạn (bản 0.5, T5-03) và ảnh album (T5-05)

- **Bảng server `custom_questions`** (`db/migrations/0003_custom_questions.sql`, **chưa chạy trên Neon**): `id`, `family_id` (mặc định `current_family_id()`), `child_id` (null = mọi bé), `strand`, `rung` 1–6, `grade` 1–12, `text_vi`, `text_en`, `answer`, `choices` (jsonb), `explanation_vi`, `active`, `created_at`, `updated_at`. Ràng buộc: điền số thì `answer` là số nguyên không âm tối đa 6 chữ số; trắc nghiệm thì `choices` là mảng 2–6 chuỗi và `answer` là một trong số đó. RLS theo `family_id`; trigger `keep_newest`, `forbid_family_change` và một trigger đặt `updated_at = now()` khi sửa mà không đổi mốc; quyền `select, insert, update` (tắt câu bằng `active = false`, không xóa).
- **Chiều xuống duy nhất**: app chỉ TẢI `custom_questions` có `updated_at > mốc` (khóa `sync_custom_questions_mark`, lấy từ `updated_at` của server như `messages`), lưu vào bảng Drift `custom_questions` (schema v7). App không ghi gì lên bảng này. Cờ `customQuestionsEnabled` trong `sync_config.dart` mặc định `false`: tắt thì không gọi mạng cho bảng này và đề ngày không đổi. Bố/mẹ chạy SQL rồi đổi cờ thành `true` (bật cờ khi bảng chưa có sẽ làm mọi lượt đồng bộ báo 404).
- **Trộn vào đề ngày**: tối đa 1 câu mỗi chặng, thay câu 3 (đúng bậc hiện tại của bé), đúng mảng, câu của riêng bé hoặc của mọi bé, đang bật; nhiều câu thì chọn câu bé làm ít nhất. Nội dung câu được chụp vào `daily_sets.questions` (khóa `custom`), nên đề đã tạo không đổi khi bố sửa hoặc tắt câu. Lượt trả lời ghi vào `attempts` với `form_id = 'custom:<id>'` và gửi lên như mọi lượt khác (cột `form_id` là text tự do nên không cần đổi server). Câu tự soạn không vào sổ ôn tập và không tính thành thạo dạng bài; vẫn tính vào bậc của mảng.
- **Web admin**: tab "Đề tự soạn" (danh sách, thêm, sửa, bật/tắt) và nhập CSV (cột `strand, rung, grade, text_vi, text_en, answer, choices, explanation_vi, active`; kiểm tra từng dòng, xem trước, nhập theo lô 50, tối đa 500 dòng mỗi file). Dùng cùng `NeonHttp`.
- **Ảnh album (T5-05) CHỈ TRÊN MÁY**: bảng Drift `photos` (schema v6) và file PNG trong `<thư mục tài liệu>/photos/`. Không có cột `synced`, không có bảng server, bộ đồng bộ không đụng tới; xóa dữ liệu bằng menu QA không xóa file ảnh.
- Tổng quan schema Drift: v5 → v6 (`photos`) → v7 (`custom_questions`), mỗi bước có test migration (`app/test/core/database_v6_migration_test.dart`, `database_v7_migration_test.dart`).

## Bản chính thức: đăng nhập, mật khẩu, dọn bản thử (29/11/2026)

- **Quên mật khẩu**: Neon Auth dùng người gửi chung `auth@mail.myneon.app` nên gửi được thư. App và web gọi `POST {auth}/request-password-reset {email, redirectTo}` với `redirectTo = https://lavang-0708.github.io/TimoKid/` (domain đã được phép). Bấm liên kết trong thư thì Neon chuyển tới `redirectTo?token=...`; web admin đọc token và gọi `POST {auth}/reset-password {token, newPassword}`. Thư có thể rơi vào Thư rác. Muốn đổi người gửi hoặc nội dung thư: Neon Console > Auth > Email provider.
- **Đổi mật khẩu**: `POST {auth}/change-password {currentPassword, newPassword}` (app: Cài đặt bố/mẹ; web: Cài đặt > Tài khoản).
- **Phiên hết hạn**: `/token` trả 401 thì bộ đồng bộ báo `needsLogin`; biểu tượng đám mây hiện "Cần đăng nhập lại", Cài đặt bố/mẹ có mục "Đăng nhập lại". Việc chơi không bị chặn; dữ liệu nằm trên máy và gửi sau khi đăng nhập lại. Mốc đồng bộ gần nhất lưu ở khóa cục bộ `sync_last_synced_at`.
- **Cài đặt của bố**: web ghi `rewards` và `answer_type_lock` theo từng bé (`settings.child_id` = bé). Trước đây app chỉ đọc `rewards` chung và không đọc `answer_type_lock`, nên hai mục này chưa có tác dụng. Nay `RewardConfig.load` đọc mức riêng của bé đang chơi trước, rồi mới tới mức chung; `DailySetService` đọc `answer_type_lock` khi sinh đề ngày, chặng tự chọn và tầng tháp (`choice` luôn trắc nghiệm, `number` luôn điền số trừ dạng chỉ-trắc-nghiệm, bỏ trống = theo bậc). Đề ngày đã sinh trong ngày không đổi; áp dụng từ đề mới.
- **Tên và lớp bé**: web sửa `children` (kèm `updated_at`); app tải `children` có `updated_at` mới hơn mốc `sync_children_mark` và cập nhật khi dòng server mới hơn dòng trên máy.
- **Xu/kim cương của bản thử** (`wallet_ledger.reason` thuộc `test_grant`, `test_topup`, `test_cleanup`, hằng `testWalletReasons`): (1) bộ đồng bộ KHÔNG BAO GIỜ gửi các dòng này (cả ở bản thử); (2) bản chính thức, lần mở đầu tiên (khóa `sync_test_grants_cleaned_v1`), `TestGrantCleanup` xóa chúng khỏi máy. Sổ ví là append-only (trigger SQLite chặn UPDATE/DELETE) nên KHÔNG ghi dòng bù lên sổ (dòng bù sẽ lên server và hiện như giao dịch thật); thay vào đó `AppDatabase.purgeWalletRowsByReason` tạm bỏ trigger xóa trong một giao dịch rồi tạo lại ngay. Nếu bé đã tiêu quá phần xu thật (số dư âm sau khi xóa) thì thêm một dòng `test_cleanup` chỉ nằm trên máy (`synced = 1`, không bao giờ gửi) để số dư về 0. Đồ đã mua/mở khóa vẫn giữ. Web admin tính số dư từ `wallet_ledger` bỏ các lý do trên (kể cả dòng bản thử đã lỡ lên server).
- **Dọn trên server (tùy chọn, chủ dự án chạy bằng role chủ database)**: các dòng `test_grant`/`test_topup` mà bản thử cũ đã gửi lên vẫn nằm trong `wallet_ledger` của Neon; web admin đã bỏ qua chúng. Muốn xóa hẳn: `delete from public.wallet_ledger where reason in ('test_grant','test_topup');` (role `authenticated` không xóa được vì sổ chỉ SELECT/INSERT).
