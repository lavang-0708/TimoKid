# TimoKid - Web admin cho phụ huynh

Trang web tĩnh (React + Vite + TypeScript, không có backend riêng) để phụ huynh xem thống kê của bé, gửi thư và quà, chỉnh cài đặt. Thiết kế ưu tiên điện thoại, dùng được trên máy tính. Tài liệu thiết kế: `docs/DESIGN.md` (mục "Web admin cho phụ huynh") và `docs/SYNC.md`.

## Chạy ở máy

```
cd admin
npm ci
npm run dev        # http://localhost:5173/TimoKid/
```

Các lệnh khác:

| Lệnh | Việc |
| --- | --- |
| `npm run lint` | ESLint |
| `npm test` | Vitest, chỉ logic thuần (ngày giờ Việt Nam, dạng yếu, kiểm tra thư...) |
| `npm run build` | Kiểm tra kiểu TypeScript và build ra `dist/` |
| `npm run test:e2e` | Kiểm thử đầu-cuối với backend THẬT (không chạy trong CI, xem bên dưới) |

## Kết nối backend

Hai URL công khai nằm trong `src/lib/config.ts` (lấy từ Neon project `timokid`, ghi trong `docs/SYNC.md`):

- Neon Auth: `.../timokid/auth`
- Data API: `.../timokid/rest/v1`

Có thể ghi đè khi build bằng `VITE_TIMOKID_AUTH_URL` và `VITE_TIMOKID_API_URL`. Trong repo không có mật khẩu database hay khóa bí mật: trang chỉ dùng JWT của người đăng nhập, quyền truy cập do RLS trong database quyết định.

Cách đăng nhập: `POST {AUTH}/sign-in/email` (cookie phiên), rồi `GET {AUTH}/token` lấy JWT sống khoảng 15 phút, gửi kèm `Authorization: Bearer` tới Data API. JWT được làm mới tự động. Không dùng SDK `@neon/neon-js` để trang nhỏ (khoảng 57 KB gzip) và kiểm thử được bằng Node; luồng gọi giống hệt `db/tests/rls_test.py`.

Chạy ở máy cần origin `localhost` được Neon Auth cho phép; bản deploy dùng `https://lavang-0708.github.io` (đã thêm vào trusted origins).

## Các màn hình

Đăng nhập/Đăng ký, Chọn bé, Thống kê (7 hoặc 30 ngày, kèm thẻ Nhân vật và pet), Dạng bài (7, 30 hoặc 90 ngày), Thư và quà, Cài đặt. Trang không tạo được hồ sơ bé: hồ sơ xuất hiện sau khi app trên máy bé đăng nhập cùng tài khoản và đồng bộ.

**Dạng bài** có mục "Thống kê từng dạng": với bé đang chọn và khoảng ngày đã chọn, mỗi mảng liệt kê đủ các dạng của app (84 dạng: logic 18, số học 15, lý thuyết số 17, hình học 17, tổ hợp 17) kèm số lượt và tỉ lệ đúng ngay lần đầu. Dạng yếu (từ 5 lượt trở lên, đúng dưới 60%) xếp trước, rồi theo tỉ lệ đúng tăng dần; dạng chưa làm lượt nào hiện "Chưa làm" ở cuối mỗi mảng. Dữ liệu lấy từ bảng `attempts`; phần tính nằm ở `formStatsByStrand` trong `src/lib/logic.ts`. Bảng tên tiếng Việt `FORM_LABELS` (`src/lib/labels.ts`) được `src/lib/labels.test.ts` đối chiếu với mã Dart trong `app/lib/features/questions/generators/`: thêm hoặc đổi mã dạng trong app mà quên cập nhật nhãn thì `npm test` báo lỗi.

**Nhân vật và pet** (thẻ trong màn Thống kê, chỉ đọc) hiển thị tên, dáng, bộ đồ, phụ kiện đang đeo, loài pet, giai đoạn và số ngày xong đề nữa để lên giai đoạn sau. Đọc từ các khóa `settings` của bé: `character_profile`, `kid_head_accessory`, `kid_glasses`, `kid_white_shoes`, `kid_backpack`, `selected_egg`, `egg_hatched`; giai đoạn pet tính từ số dòng `daily_sets` có đủ 5 chặng `done` (mới nở 0-2 ngày, tuổi nhỡ 3-7, trưởng thành từ 8, như `app/lib/features/room/pet_growth.dart`). Tên bộ đồ, loài, giai đoạn được chép từ mã Dart sang `labels.ts`. Khi app chưa đồng bộ các dòng này, thẻ hiện "Chưa có dữ liệu — app chưa đồng bộ" thay vì báo lỗi.

Cài đặt ghi vào bảng `settings` của bé bằng cách đọc theo `child_id` + `key` rồi PATCH theo `id` (chưa có thì POST), vì chỉ mục duy nhất là chỉ mục biểu thức nên `on_conflict` không dùng được. Các khóa: `answer_type_lock` (map mảng -> `choice` | `number` | null) và `rewards` (cùng tên khóa với app: `easy`, `medium`, `hard`, `stage_complete`, `daily_complete_xu`, `daily_complete_gem`, `mastery_gem`).

## Deploy

`.github/workflows/admin.yml`: khi push vào `main` có đổi `admin/**` (hoặc chạy tay bằng workflow_dispatch) thì chạy `npm ci`, lint, test, build rồi deploy `admin/dist` lên GitHub Pages: `https://lavang-0708.github.io/TimoKid/`. Pull request chỉ chạy lint, test, build.

Chủ repo cần bật một lần: Settings -> Pages -> Source = "GitHub Actions".

## Kiểm thử đầu-cuối (chạy tay)

```
npm run test:e2e
```

Mỗi lần chạy đăng ký một tài khoản thử mới `rls-admin-<ngẫu nhiên>@example.com`, gọi `ensure_family`, chèn một bé thử cùng lượt trả lời, ví, bậc, sổ ôn tập, đề ngày bằng JWT của tài khoản đó, rồi kiểm tra số liệu từng màn hình, gửi thư và đổi cài đặt. Dọn tài khoản thử bằng `db/tests/cleanup_test_accounts.sql` (tiền tố `rls-`).
