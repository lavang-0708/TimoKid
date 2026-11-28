# Kế hoạch triển khai TimoKid

> Bản markdown của kế hoạch, xuất ngày 2026-11-17. Claude cập nhật file này khi kế hoạch thay đổi.

Muse viết code, Claude ra yêu cầu và review thay chủ dự án, chủ dự án duyệt các quyết định và cài thử trên máy thật. Kế hoạch này đi kèm `docs/DESIGN.md`. Khi hai tài liệu lệch nhau, bản thiết kế là chuẩn về sản phẩm, kế hoạch này là chuẩn về cách làm.

## Vai trò và quy trình

Mỗi nhiệm vụ trong kế hoạch có một mã (ví dụ `T1-05`) và đi qua đúng một pull request. Không ai đẩy thẳng code lên nhánh `main`. Ngoại lệ: Claude được đẩy thẳng thay đổi của `docs/DESIGN.md` và `docs/PLAN.md`.

| Ai | Làm gì |
| --- | --- |
| Chủ dự án | Duyệt quyết định sản phẩm, cài APK lên máy thật cho bé chơi thử, cấp tài khoản và bí mật (keystore, Neon, Cloudflare) |
| Claude | Viết yêu cầu cho từng nhiệm vụ, review pull request theo tiêu chí nghiệm thu, kiểm tra bằng chứng chạy thật, merge pull request đạt (chủ dự án giao từ 17/11), báo chủ dự án tiến độ |
| Muse | Viết code, test và tài liệu theo yêu cầu, mở pull request, sửa theo review |

### Vòng làm một nhiệm vụ

1. Claude gửi Muse yêu cầu: mã nhiệm vụ, phạm vi, tiêu chí nghiệm thu, những gì không được làm.
2. Muse tạo nhánh `task/T1-05-ten-ngan`, làm việc, mở pull request theo mẫu bên dưới.
3. Claude review: đọc code, đối chiếu tiêu chí, xem log CI và ảnh chụp màn hình. Kết luận một trong ba: Đạt, Cần sửa (kèm danh sách cụ thể), hoặc Cần chủ dự án quyết.
4. Khi Đạt, Claude merge (squash). Mỗi bản 0.x xong thì gắn tag, CI phát hành APK.

### Mẫu mô tả pull request

Mỗi pull request có đủ 6 mục: **Nhiệm vụ** (mã và tên), **Đã giải quyết gì** (viết cho người không đọc code), **Thay đổi chính** (theo file hoặc module), **Cách đã kiểm chứng** (lệnh đã chạy và kết quả thật, ảnh chụp màn hình nếu có giao diện), **Rủi ro và điểm chưa chắc**, **Việc còn lại**.

### Trạng thái nhiệm vụ

Mọi báo cáo dùng đúng năm trạng thái: **Chưa bắt đầu**, **Đang làm**, **Chờ xác nhận** (ghi rõ chờ ai, chờ gì), **Bị chặn** (ghi rõ lỗi), **Xong** (đã merge).

### Quy tắc cho Muse

- Làm đúng phạm vi nhiệm vụ. Thấy việc cần làm thêm thì ghi vào mục "Việc còn lại", không tự làm.
- Không tự đổi quyết định trong bản thiết kế (luật xu, thang ải, công nghệ). Gặp chỗ thiết kế thiếu hoặc mâu thuẫn thì hỏi, ghi rõ các phương án.
- CI xanh chưa đủ để coi là xong. Phải có bằng chứng chạy thật theo tiêu chí của nhiệm vụ.
- Không đưa bí mật (mật khẩu, khóa, chuỗi kết nối) vào code hay pull request.
- Không thêm thư viện, dịch vụ trả phí hay quảng cáo, theo dõi người dùng.
- Cuối mỗi pull request cập nhật `docs/HANDOVER.md`.

## Làm rõ ngày 17/11 (trả lời câu hỏi của Muse)

Các điểm dưới đây ghi đè mọi chỗ nói khác trong kế hoạch.

| Mã | Câu hỏi | Chốt |
| --- | --- | --- |
| a | "Dạng bài" là gì | Dạng bài = một `form` trong `gen.py`: 48 generator (lúc chốt T1-05; hiện app có **84 dạng**: thêm 24 dạng TIMO lớp 2 và 12 dạng đợt 3 — xem `question_registry.dart`, `tools/question_bank/TIMO3_FORMS.md`). Mỗi generator khai báo các mức nó hỗ trợ và chỉ sinh câu ở các mức đó. Không tự soạn thêm mức mới trong T1-05; việc bổ sung mức là nhiệm vụ nội dung riêng của Claude. |
| b | Dạng không có mức Khó thì thành thạo thế nào | Thành thạo = đúng ngay lần đầu 4 trong 5 câu gần nhất ở mức cao nhất mà dạng hỗ trợ, và không thấp hơn mức Vừa nếu dạng có mức Vừa. Như vậy mọi dạng (48 lúc đó, nay 84) đều thành thạo được. |
| c | Khoảng xu và thứ tự nhân thưởng | Thứ tự: xu gốc theo bậc, rồi chia đôi làm tròn lên nếu đúng sau gợi ý, rồi nhân đôi nếu là câu ôn tập. Test nghiệm thu T1-11: bé ở bậc 3-4, sổ ôn tập trống, đúng ngay hết 25 câu, tổng phải là 120 xu. Giữ khoảng 100-130 là mục tiêu thiết kế, không phải tiêu chí test cho mọi trường hợp. |
| d | Nghiệm thu T1-05 cho câu trắc nghiệm chọn | Với dạng `choiceOnly` (compare, weekday, parityrule): chỉ số đáp án hợp lệ, 4 lựa chọn khác nhau (hoặc đủ số lựa chọn của dạng), lựa chọn đúng khớp với hàm giải độc lập, cả VI và EN. Các kiểm tra "số dương" và "3 đáp án nhiễu" chỉ áp dụng cho câu điền số. |
| e | Bảng dữ liệu | T1-04 tạo 7 bảng như ghi. `inventory` tạo ở T2-05, `pets` ở T2-07 (bằng migration). `families`, `messages`, `custom_questions`, `content_packs` thuộc bản 0.3 và 0.5. Ngoại lệ cột: `children` không có `child_id` (có `family_id` để trống tới bản 0.3); `settings` có `child_id` để trống cho cài đặt chung. |
| f | Định nghĩa "đúng" và cửa sổ 10 câu | "Đúng" cho lên bậc, xuống bậc và thành thạo luôn là đúng ngay lần đầu. Xuống bậc khi số câu đúng ngay lần đầu dưới 5 trong 10. Giữ quy tắc tính lại từ 10 câu mới sau mỗi lần đổi bậc. |
| g | Đề ngày: thiếu dạng và câu ôn tập | Thiếu dạng thì được lặp, ưu tiên lặp dạng ít gặp nhất trong 7 ngày gần đây. Câu 4 (ôn tập) dùng bậc đã lưu trong `review_queue`. Nếu dạng ôn tập trùng dạng đã có trong chặng thì giữ câu ôn tập, đổi dạng của câu kia. |
| h | CI và phát hành | Integration test trên máy ảo tách ra workflow riêng, chạy cho pull request có thay đổi trong `app/lib/**` phần giao diện hoặc khi gắn nhãn `ui`, ngân sách 25 phút. Workflow chính (analyze, test, build APK debug) giữ dưới 15 phút. Tag phát hành do Muse tạo sau khi Claude kết luận Đạt cho nhiệm vụ nghiệm thu. Phần ký APK của T1-03 chờ chủ dự án nạp keystore; các phần khác của T1-03 làm trước. |
| i | Điểm nhỏ | Nghiệm thu T1-01 là log chạy tay `check.py`. Menu QA mở bằng nhấn giữ 5 giây ở góc trên bên trái. `Clock` trả ngày theo múi giờ Asia/Ho_Chi_Minh. Bản 0.1 mở app vào thẳng màn Thị trấn tạm với bé mặc định. |
| j | Môi trường build | Muse được cài Flutter SDK trong workspace của mình để chạy `flutter create`, `analyze`, unit test và widget test. Build APK và test máy ảo chạy trên GitHub Actions. |
| k | Nguồn hình (chốt 18/11) | Các tấm trong `assets/concept/` là nguồn hình chính: tách nền, cắt từng món, sửa lỗi theo bảng trong `assets/concept/README.md`. Món thiếu hoặc hỏng thì Muse vẽ bổ sung cùng phong cách pastel viền trắng sticker. Áp dụng từ T1-12 (icon app, nền Thị trấn, biểu tượng nút) và cả bản 0.2. |
| l | Màn làm toán sau khi chủ dự án dùng thử v0.0.1 (chốt 18/11) | (1) Đề luôn hiện song ngữ: dòng trên tiếng Việt chữ to, dòng dưới tiếng Anh chữ nhỏ hơn, màu nhạt hơn; bỏ nút đổi EN. Gợi ý và lời giải cũng hiện song ngữ theo cùng cách. Nút xem từ khóa giữ nguyên. (2) Hai cột cân nhau: khối đề (cột trái) và khối đáp án (cột phải) cùng căn giữa theo chiều dọc trong vùng dưới thanh trên, không để đề dính góc trên trái còn đáp án lệch xuống góc dưới phải. Gợi ý, lời giải nằm ngay dưới đề trong cột trái; nút Tiếp nằm dưới đáp án trong cột phải. |
| m | Màn làm toán sinh động (chốt 18/11, tham khảo Duolingo và iSmart) | Âm thanh: đúng phát `correct.wav` ("ting"), sai phát `wrong.wav` ("è" nhẹ), xu phát `coin.wav`, xong chặng phát `stage_complete.wav` (có sẵn trong `app/assets/sounds/`), tắt được theo `sound_enabled`. Giao diện: thanh tiến độ 5 ô ở trên thay chữ "Câu 1/5"; nền theo khu, mỗi mảng một màu pastel kèm họa tiết nhẹ (SVG); đề nằm trong thẻ trắng bo tròn có bóng; nút đáp án to kiểu nổi (viền dưới đậm, nhấn thì lún xuống); kết quả hiện bằng băng trượt lên từ đáy màn: xanh "Đúng rồi! +2 xu" kèm nút Tiếp (băng bo tròn, nền xanh nhạt `#E3F7E6`, viền xanh `#43A047` dày 3, bóng dưới, biểu tượng dấu tích tròn bên trái, số xu trong ô vàng có hình đồng xu; nút đáp án đúng chuyển xanh; xem `docs/preview_font_mau.webp`), cam nhạt "Gần đúng rồi, xem gợi ý nhé" khi sai lần đầu (không dùng đỏ gắt); xu bay về góc ví; đúng liền 3 câu hiện "3 câu liền!". Có một pet hoặc nhân vật nhỏ ở góc phản ứng vui khi đúng, động viên khi sai (lấy từ tấm concept pet). Hiệu ứng ngắn dưới 1 giây, không chặn thao tác. Phông chữ: dùng Nunito có sẵn trong `app/assets/fonts/` cho toàn app (khai báo trong pubspec, đặt làm `fontFamily` của theme). Tương phản: chữ đề màu tím đậm `#3B2E5A` trên thẻ trắng, dòng tiếng Anh `#8A7FA6`, số trên nút `#4B2E83`, nền màn và nền thẻ phải khác hẳn nhau (ảnh mẫu `docs/preview_font_mau.webp`); mọi chữ chính đạt tương phản tối thiểu 4,5:1. |

## Quy ước kỹ thuật

App viết bằng Flutter, chạy offline hoàn toàn ở bản 0.1 và 0.2. Mọi thư viện dùng bản stable mới nhất tại thời điểm tạo repo và ghi cố định trong `pubspec.lock`.

### Công nghệ

| Phần | Chọn dùng |
| --- | --- |
| App | Flutter stable, Dart 3, chỉ build Android, khóa màn hình ngang |
| Quản lý trạng thái | Riverpod |
| Điều hướng màn hình | go_router |
| Cơ sở dữ liệu trên máy | Drift (SQLite), có migration từ bản đầu |
| Hình vẽ câu hỏi | SVG sinh từ tham số câu hỏi, hiển thị bằng flutter_svg |
| Cảnh phòng và thị trấn (từ bản 0.2) | Widget Flutter thường; chỉ dùng Flame nếu cần kéo thả hoặc hiệu ứng mà widget làm không tốt, và phải nêu lý do trong pull request |
| Âm thanh | audioplayers hoặc just_audio, âm thanh ngắn dạng .ogg |
| Web admin (bản 0.3) | React, Vite, TypeScript, build ra trang tĩnh cho Cloudflare Pages |
| Máy chủ (bản 0.3) | Neon project riêng: Postgres, Data API, Neon Auth. Không viết backend riêng |

### Cấu trúc repo `lavang-0708/TimoKid`

```
app/        App Flutter
  lib/core/        theme, router, database, tiện ích chung
  lib/features/    mỗi tính năng một thư mục: questions, daily_set, review, wallet, ...
  test/            unit test
  integration_test/ test chạy trên máy ảo, có chụp màn hình
admin/      Web admin (từ bản 0.3)
assets/     Tài sản hình: concept/ (nguồn hình chính, xem README trong đó), templates/ (khung vẽ SVG)
content/    Hình và gói nội dung thêm về sau, phát qua Cloudflare Pages
tools/      Script Python sinh và kiểm tra ngân hàng câu hỏi mẫu
docs/       DESIGN, PLAN, HANDOVER, DECISIONS, ASSETS
```

### Chất lượng code

- `flutter analyze` không có cảnh báo, code định dạng bằng `dart format`.
- Logic học (sinh câu, thang ải, đề ngày, sổ ôn tập, xu) nằm trong Dart thuần, không phụ thuộc widget, để test được bằng unit test.
- Thời gian và số ngẫu nhiên đi qua một lớp `Clock` và một `Random` có seed, để test tái hiện được và menu QA nhảy ngày được.
- Bảng dữ liệu dùng đúng tên trong bản thiết kế. Mỗi dòng có `id` dạng UUID, `child_id`, `created_at`, `updated_at` và cờ `synced`, để bản 0.3 gắn đồng bộ mà không phải đổi cấu trúc.
- Giao diện app bằng tiếng Việt. Nội dung câu hỏi song ngữ.

### CI trên GitHub Actions

| Khi nào | Chạy gì |
| --- | --- |
| Mỗi pull request | `flutter analyze`, `flutter test`, build APK bản debug và đính kèm làm artifact |
| Pull request có thay đổi giao diện | Thêm integration test trên máy ảo Android, đính kèm ảnh chụp màn hình làm artifact |
| Gắn tag `v*` | Build APK bản release đã ký bằng keystore cố định, tạo GitHub Release kèm file APK |

Keystore phải cố định từ bản đầu tiên: nếu đổi keystore, Android không cho cài đè bản mới và bé mất dữ liệu khi gỡ app cũ. CI cần dưới 15 phút cho mỗi pull request để không tốn phút chạy.

## Bản 0.1: lõi học

Kết quả của bản 0.1 là một file APK bé cài được, làm đề ngày 25 câu song ngữ, được gợi ý, xem lời giải và nhận xu. Chưa có nhân vật, pet hay đồng bộ. Hình ảnh là hình tạm. Làm theo thứ tự mã nhiệm vụ; T1-05 và T1-06 làm song song với T1-04 được.

### T1-01 Khởi tạo repo

- **Làm:** `docs/DESIGN.md`, `docs/PLAN.md`, `tools/question_bank/` (`gen.py`, `check.py`, `questions.json`) và `assets/` đã có sẵn trên `main`. Muse thêm: `README.md` ngắn, `.gitignore` cho Flutter và Python, `docs/HANDOVER.md`, `docs/DECISIONS.md`, và các thư mục còn lại theo mục Cấu trúc repo.
- **Nghiệm thu:** chạy `python3 tools/question_bank/check.py` ra 267 câu, 0 câu sai.

### T1-02 Khung app Flutter

- **Làm:** project Flutter trong `app/`, package `vn.timokid.app`, tên hiển thị "TimoKid". Khóa màn hình ngang, ẩn thanh trạng thái. Theme pastel tạm (màu nền, nút bo tròn, chữ to). Riverpod, go_router và các màn trống: Thị trấn, Làm toán, Kết quả chặng.
- **Nghiệm thu:** APK debug cài được, mở ra nằm ngang trên cả điện thoại (khung 800 x 360 dp) lẫn máy tính bảng (1280 x 800 dp), không tràn chữ. Ảnh chụp hai kích thước trong pull request.

### T1-03 CI và phát hành APK

- **Làm:** các workflow như bảng CI. Workflow release đọc keystore từ GitHub Secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`). Kèm script và hướng dẫn để chủ dự án tự tạo keystore trên máy mình; keystore không bao giờ nằm trong repo.
- **Nghiệm thu:** pull request thử có APK debug tải về được. Gắn tag thử `v0.0.1` tạo Release có APK đã ký (sau khi chủ dự án nạp secrets).

### T1-04 Cơ sở dữ liệu trên máy

- **Làm:** Drift với các bảng `children`, `attempts`, `skill_progress`, `review_queue`, `daily_sets`, `wallet_ledger`, `settings`. Bản 0.1 tự tạo một hồ sơ bé mặc định, lớp 2. `attempts` và `wallet_ledger` chỉ thêm dòng, không sửa, không xóa. Số dư xu tính bằng tổng ledger.
- **Nghiệm thu:** unit test tạo, đọc, cập nhật trên cơ sở dữ liệu trong bộ nhớ. Dữ liệu còn nguyên sau khi tắt hẳn app và mở lại.

### T1-05 Bộ sinh câu hỏi

- **Làm:** chuyển tất cả dạng bài trong `gen.py` sang Dart. Mỗi dạng là một `QuestionGenerator` có `formId` (ví dụ `logic.balance`), mảng, các mức hỗ trợ, và hàm `generate(level, random)` trả về `Question` gồm: đề VI, đề EN, từ khóa, gợi ý, lời giải, đáp án, 3 đáp án nhiễu, tham số hình vẽ. Dạng bài vốn là câu chọn đánh dấu `choiceOnly`. Giữ nguyên cách diễn đạt đề và lời giải của `gen.py`; sửa câu chữ thì ghi vào pull request.
- **Nghiệm thu:** với mỗi dạng và mỗi mức, test sinh 500 câu bằng 500 seed và kiểm tra: đáp án khớp với một hàm giải độc lập viết riêng trong test (không gọi lại code sinh câu); đáp án là số dương; 3 đáp án nhiễu khác nhau và khác đáp án; đề không còn ký tự mẫu như `{`, `null`, `NaN`; lời giải có chứa đáp án. Báo cáo số dạng đã chuyển so với `gen.py`.

### T1-06 Hình vẽ cho câu hình học

- **Làm:** sinh SVG từ tham số cho các dạng đếm hình vuông, hình chữ nhật, tam giác, que diêm, ghép hình vuông, đường đi trên lưới, theo các hàm `svg_*` trong `gen.py`. Nét đậm, dễ nhìn trên màn hình nhỏ.
- **Nghiệm thu:** test so sánh hình mẫu (golden test) cho mỗi dạng. Ảnh chụp tất cả dạng trong pull request để Claude đếm lại bằng mắt.

### T1-07 Thang ải và thành thạo

- **Làm:** mỗi mảng có bậc 1 đến 6 (bậc lẻ trắc nghiệm, bậc chẵn điền số; bậc 1 và 2 nội dung Dễ, 3 và 4 Vừa, 5 và 6 Khó). Bé mới bắt đầu ở bậc 1. Lên một bậc khi đúng ngay lần đầu từ 8 trên 10 câu gần nhất của mảng; xuống một bậc khi dưới 5 trên 10; sau mỗi lần đổi bậc thì tính lại từ 10 câu mới. Thành thạo dạng bài: đúng ngay lần đầu 4 trong 5 câu gần nhất ở bậc 3 trở lên. Các ngưỡng này là hằng số cấu hình, không viết cứng rải rác.
- **Nghiệm thu:** unit test cho lên bậc, xuống bậc, chạm trần bậc 6, đáy bậc 1, và thành thạo.

### T1-08 Đề ngày

- **Làm:** mỗi ngày theo giờ Việt Nam tạo một đề 25 câu, 5 chặng theo 5 mảng. Trong mỗi chặng: câu 1 và 2 thấp hơn bậc hiện tại một bậc (không dưới bậc 1), câu 3 đúng bậc, câu 4 lấy từ sổ ôn tập nếu đến hạn (nếu không thì đúng bậc), câu 5 cao hơn một bậc (không quá bậc 6). Không lặp dạng bài trong cùng chặng nếu mảng còn dạng khác. Đề được lưu lại khi tạo, nên tắt app giữa chừng mở lại vẫn đúng câu đang làm. Bé chọn thứ tự chặng tùy ý. Sau khi xong đề ngày, bé làm thêm chặng tự chọn không giới hạn.
- **Nghiệm thu:** unit test cấu trúc đề với nhiều trạng thái bậc và sổ ôn tập. Test sang ngày mới lúc 0 giờ tạo đề mới.

### T1-09 Màn làm toán

- **Làm:** đề tiếng Việt chữ to, nút "EN" đổi sang đề tiếng Anh, nút xem từ khóa song ngữ, hình vẽ nếu có. Trắc nghiệm: 4 nút lớn, thứ tự trộn ngẫu nhiên. Điền số: bàn phím số riêng trong app, nút to, có nút xóa. Sai lần đầu hiện gợi ý và cho làm lại; sai lần hai hiện lời giải từng bước và nút "Tiếp". Đúng thì có hiệu ứng và âm thanh ngắn, hiện số xu nhận được. Mỗi lượt trả lời ghi một dòng `attempts` (dạng, bậc, kiểu trả lời, đúng sai, số lần thử, thời gian làm). Cuối chặng là màn Kết quả chặng.
- **Nghiệm thu:** integration test đi hết một chặng gồm cả câu đúng ngay, câu đúng sau gợi ý, câu sai hai lần; chụp màn hình mỗi trạng thái. Nút bấm tối thiểu 56 x 56 dp.

### T1-10 Sổ ôn tập

- **Làm:** câu sai (kể cả đúng sau gợi ý) đưa dạng bài và bậc vào `review_queue`. Hỏi lại bằng câu mới cùng dạng sau 1, 3 và 7 ngày. Đúng ngay lần đầu đủ ba lần thì ra khỏi sổ; sai thì quay lại mốc 1 ngày. Một dạng bài chỉ có một mục trong sổ.
- **Nghiệm thu:** unit test đủ vòng 1-3-7 ngày, quay lại khi sai, không trùng mục, dùng `Clock` giả.

### T1-11 Ví xu

- **Làm:** cộng xu theo bảng thưởng trong bản thiết kế, đổi từ "mức" sang bậc: bậc 1-2 được 2 xu, bậc 3-4 được 3 xu, bậc 5-6 được 5 xu cho mỗi câu đúng ngay. Đúng sau gợi ý được nửa số xu, làm tròn lên. Câu từ sổ ôn tập gấp đôi. Xong chặng thêm 5 xu, xong đề ngày thêm 20 xu và 1 kim cương. Mọi mức thưởng nằm trong một file cấu hình. Số dư hiển thị trên màn Thị trấn.
- **Nghiệm thu:** unit test từng loại thưởng và test một ngày đủ 25 câu cho tổng xu nằm trong khoảng thiết kế (100 đến 130 xu) với bé ở bậc giữa.

### T1-12 Màn Thị trấn tạm

- **Làm:** 5 nút lớn cho 5 khu (tên theo bản thiết kế), mỗi nút hiện trạng thái chặng hôm nay (chưa làm, đang làm, xong), thanh tiến độ đề ngày, số xu và kim cương. Chưa cần bản đồ hay cư dân.
- **Nghiệm thu:** ảnh chụp màn Thị trấn trước, giữa và sau khi xong đề ngày.

### T1-13 Menu QA ẩn

- **Làm:** mở bằng cách nhấn giữ 5 giây vào góc màn hình. Chức năng: nhảy sang ngày hôm sau, đặt bậc từng mảng, xem sổ ôn tập, xem 20 lượt trả lời gần nhất, xem thử một dạng bài bất kỳ ở bậc bất kỳ, xóa dữ liệu. Menu chỉ có trong bản debug và bản có cờ QA, không có trong bản release giao cho bé.
- **Nghiệm thu:** Claude dùng được menu để kiểm tra T1-07, T1-08, T1-10 trên bản APK debug.

### T1-14 Nghiệm thu và phát hành v0.1.0

- **Làm:** kiểm tra toàn bộ bản 0.1 trên máy ảo, sửa lỗi, cập nhật tài liệu, gắn tag `v0.1.0`.
- **Nghiệm thu:** APK release cài trên máy thật của chủ dự án, bé làm trọn một đề ngày không gặp lỗi. Sau đó bé chơi khoảng một tuần; chủ dự án ghi lại nhận xét (đề có quá dài không, bé có đọc lời giải không) để chỉnh trước bản 0.2.

## Bản 0.2: lõi game

Kết quả của bản 0.2 là bé tạo nhân vật, ấp trứng, có phòng riêng, mua đồ và thay đồ bằng xu kiếm từ đề ngày. Bắt đầu sau khi bé đã chơi thử bản 0.1 và chủ dự án chốt các chỉnh sửa. **Cập nhật 19/11: chủ dự án chốt làm song song**, bắt đầu T2-01, T2-02 ngay sau T1-15, không chờ bé chơi thử bản 0.1; anh xem một thể khi có nhân vật, trứng pet và cửa hàng chạy được. Hình dùng bộ tạm từ các tấm phác ý tưởng (trứng, pet, phòng) cho đến khi có hình thật.

### T2-01 Quy trình nạp hình

- **Làm:** file `assets/manifest.json` liệt kê mọi hình: mã, loại (lớp nhân vật, đồ, pet, nội thất, nền), dáng nam hoặc nữ, lớp, có đổi màu không, giá. Script kiểm tra hình đầu vào: đúng kích thước khung, PNG có nền trong suốt, đúng quy tắc đặt tên trong bản thiết kế. Thêm một món đồ mới chỉ cần thả file và thêm một dòng manifest.
- **Nghiệm thu:** script báo lỗi rõ ràng với một file JPEG hoặc PNG không trong suốt; chạy trong CI.

### T2-02 Vẽ nhân vật theo lớp

> **Hiện trạng (21/11):** `CharacterView` ghép lớp đã thành legacy; app vẽ nhân vật bằng ảnh toàn thân qua `KidSprite` (`app/lib/features/character/kid_sprite.dart`). Xem `docs/ASSETS.md` mục "Nhân vật toàn thân (hiện hành)". Phần dưới giữ làm kế hoạch gốc.

- **Làm:** widget `CharacterView` chồng các lớp theo thứ tự trong bản thiết kế, tô màu lớp xám bằng phép nhân màu (multiply) rồi đặt lớp `_line` lên trên. Dùng chung cho màn tạo nhân vật, phòng và tủ đồ. Hiệu ứng thở nhẹ và chớp mắt bằng animation đơn giản.
- **Nghiệm thu:** golden test với 3 bộ phối đồ và 3 bảng màu. Vẽ một nhân vật đủ lớp dưới 16 ms trên máy ảo tầm trung.

### T2-03 Mở đầu: tạo nhân vật và chọn trứng

> **Hiện trạng (21/11):** màn mở đầu có **4 bước cho cả nam và nữ**: giới tính, bộ đồ (3 bộ), đặt tên, chọn trứng (`_girlStepKeys` trong `onboarding_screen.dart`). Không còn chọn màu da, tóc, mắt, miệng. Phần dưới giữ làm kế hoạch gốc.

- **Làm:** lần đầu mở app: chọn giới tính, màu da, kiểu và màu tóc, kiểu và màu mắt, kiểu miệng, đặt tên (tối đa 12 ký tự, không bắt buộc dấu). Sau đó chọn 1 trong 3 trứng: Chó Tinh Anh, Mèo Mũm Mĩm, Thỏ Bánh Bao. Trứng nở khi bé xong chặng đầu tiên, có hiệu ứng nở.
- **Nghiệm thu:** integration test đi hết luồng mở đầu đến khi trứng nở, chụp màn hình từng bước. Đổi ý ở bước nào cũng quay lại được.

### T2-04 Căn phòng và cổng mỗi ngày

- **Làm:** màn Phòng là màn chính: nền phòng, nhân vật, pet, nội thất đặt được vào các ô cố định, nút ra Thị trấn, nút Tủ đồ, nút Cửa hàng. Khi chưa xong đề ngày: Tủ đồ, Cửa hàng và chơi với pet bị khóa, có lời nhắc dễ thương dẫn ra Thị trấn. Chạm vào pet hoặc đồ vật thì có phản ứng nhỏ.
- **Nghiệm thu:** test khóa và mở khóa theo trạng thái đề ngày, kể cả khi qua ngày mới thì khóa lại.

### T2-05 Tủ đồ

- **Làm:** kéo thả món đồ đã sở hữu lên nhân vật, hoặc chạm để mặc. Mặc món mới cùng lớp thì thay món cũ. Chia theo lớp (áo, quần váy, giày, phụ kiện). Chỉ hiện đồ đúng dáng của nhân vật.
- **Nghiệm thu:** integration test mặc và cởi đồ, trạng thái đang mặc còn nguyên sau khi tắt mở app.

### T2-06 Cửa hàng và kim cương

- **Làm:** cửa hàng bán quần áo, thức ăn và đồ chơi cho pet, nội thất; giá lấy từ manifest. Đồ hiếm và pet mới mua bằng kim cương. Mua thì ghi `wallet_ledger` và `inventory`. Không đủ tiền thì nút mua mờ và báo còn thiếu bao nhiêu xu. Không có hộp quà may rủi, không mua bằng tiền thật.
- **Nghiệm thu:** unit test không để số dư âm, không mua trùng món đã có.

### T2-07 Pet lớn theo giai đoạn

> **Hiện trạng (21/11):** pet lớn theo số ngày xong trọn đề ngày (mới nở 0–2, nhỡ 3–7, lớn từ 8), cỡ 30/40/58/72% chiều cao nhân vật — `app/lib/features/room/pet_growth.dart`; không dùng ngưỡng "thành thạo 10/30 dạng" ghi dưới.

- **Làm:** pet có 3 giai đoạn: mới nở, nhỡ (bé thành thạo 10 dạng bài), lớn (30 dạng). Lên giai đoạn có hiệu ứng chúc mừng. Cho ăn và chơi chỉ để vui, không có trạng thái đói, ốm hay buồn. Bé có nhiều pet thì chọn một con đi theo trong phòng.
- **Nghiệm thu:** unit test ngưỡng lên giai đoạn; kiểm tra bằng menu QA.

### T2-08 Âm thanh và hiệu ứng

- **Làm:** âm thanh ngắn cho bấm nút, trả lời đúng, sai, nhận xu, nở trứng; nhạc nền nhẹ. Nút nảy khi bấm, sao bay khi nhận xu, pháo giấy khi xong đề ngày. Âm thanh lấy từ nguồn giấy phép CC0, ghi nguồn trong `docs/ASSETS.md`. Bật tắt âm thanh và nhạc riêng.
- **Nghiệm thu:** chủ dự án hoặc bé xác nhận trên máy thật; app không giật khi có hiệu ứng.

### T2-09 Nghiệm thu và phát hành v0.2.0

- **Làm:** như T1-14. Dữ liệu từ bản 0.1 (xu, bậc, sổ ôn tập) phải được giữ khi cài đè bản 0.2.
- **Nghiệm thu:** cài đè trên máy thật không mất dữ liệu; test migration cơ sở dữ liệu từ schema 0.1.

### T2-10 Đấu trường TIMO

- **Làm:** màn thi thử đúng định dạng vòng Chọn TIMO thật: 25 câu điền số, 5 phần x 5 câu (Tư duy logic, Số học, Lý thuyết số, Hình học, Tổ hợp), 4 điểm/câu, 100 điểm, 90 phút, sai không trừ điểm; câu dựng từ ngân hàng theo bậc của bé, tăng dần trong phần. Không báo đúng/sai khi thi; nộp xong chỉ hiện số câu đúng, điểm, số đúng từng phần và huy chương (Vàng từ 21 câu đúng, Bạc từ 16, Đồng từ 11, còn lại Tham gia). Thưởng kim cương cho bài đầu tiên mỗi ngày (Vàng 5, Bạc 3, Đồng 2, Tham gia 1). Lưu từng bài vào bảng `arena_attempts` (schema v3). Lối vào từ Thị trấn (khu trên bản đồ + nút HUD).
- **Nghiệm thu:** unit test dựng đề (25 câu, 5 phần đúng thứ tự, không lặp dạng, độ khó tăng, đáp án hợp lệ), chấm điểm, ngưỡng huy chương, thưởng một lần mỗi ngày; widget test luồng thi (trả lời, chuyển câu, nộp có xác nhận, hết giờ tự nộp, bỏ thi), kết quả không lộ đúng/sai; migration v2→v3 giữ dữ liệu; không tràn màn ở 608x248, 640x320, 800x360, 1280x800; golden sảnh/thi/kết quả 800x360. Khi họa sĩ giao ảnh thì đặt `arenaArtReady = true`.

## Bản 0.3: đồng bộ và web admin

Kết quả của bản 0.3 là chủ dự án xem được tiến độ của từng bé và gửi thư, quà từ một trang web, còn app vẫn chạy được khi không có mạng. Toàn bộ nằm trong gói miễn phí của Neon và Cloudflare. Trước khi làm, Muse đọc tài liệu hiện hành của Neon Auth và Data API và viết một trang thiết kế ngắn `docs/SYNC.md` để Claude duyệt.

### T3-01 Thiết kế đồng bộ

- **Làm:** `docs/SYNC.md` mô tả: schema Postgres, chính sách phân quyền theo dòng (RLS) theo gia đình, cách đăng nhập, cách đẩy lên (hàng chờ các dòng `synced = false`, gửi theo lô, ghi đè an toàn khi gửi lại), cách kéo về (chỉ lấy thay đổi sau mốc `updated_at` lần trước), xử lý xung đột cho các bảng có sửa (`inventory`, `settings`, `skill_progress`), ước tính dung lượng và egress mỗi tháng cho 3 bé.
- **Nghiệm thu:** Claude duyệt. Ước tính egress dưới 10% hạn mức 5 GB của gói miễn phí.

### T3-02 Neon project và schema

- **Làm:** project Neon riêng tên `timokid`, tách hẳn khỏi FB_Predict. Migration SQL trong repo (`db/migrations/`), bật RLS cho mọi bảng, bật Data API và Neon Auth. Chủ dự án hoặc Claude tạo project theo hướng dẫn của Muse; Muse không cần quyền quản trị Neon.
- **Nghiệm thu:** test SQL chứng minh tài khoản gia đình A không đọc, không ghi được dữ liệu gia đình B.

### T3-03 Đăng nhập và nhiều bé trong app

- **Làm:** màn cài đặt lần đầu cho bố đăng nhập, chọn hoặc tạo hồ sơ bé, chọn lớp. Màn chọn hồ sơ khi có từ 2 bé. Bé không cần mật khẩu. Dữ liệu bản 0.2 đang có trên máy gắn vào hồ sơ bé đầu tiên.
- **Nghiệm thu:** cài đè trên máy đang chạy bản 0.2, đăng nhập xong dữ liệu cũ còn nguyên và được đẩy lên.

### T3-04 Bộ đồng bộ

- **Làm:** đồng bộ khi mở app, khi xong mỗi chặng và mỗi 15 phút khi app đang mở, chỉ khi có mạng. Lỗi mạng hoặc Neon tạm dừng không được làm gián đoạn việc chơi, chỉ hiện biểu tượng nhỏ. Tải về thư, quà, cài đặt.
- **Nghiệm thu:** test mất mạng giữa lúc gửi lô, gửi lại không tạo dòng trùng. Đo và ghi trong pull request số byte tải lên, tải về cho một ngày chơi.

### T3-05 Web admin

- **Làm:** trang tĩnh trong `admin/`, đăng nhập cùng tài khoản với app. Các khu vực: Thống kê (chọn bé; số câu, tỉ lệ đúng theo 5 mảng, bậc hiện tại, thời gian học mỗi ngày, số ngày xong đề), Dạng bài (thành thạo, đang yếu, trong sổ ôn tập), Thư và quà, Cài đặt (hồ sơ bé, lớp, mức thưởng, khóa kiểu trả lời theo bé). Hiện thời điểm đồng bộ gần nhất. Dùng tốt trên điện thoại của chủ dự án.
- **Nghiệm thu:** ảnh chụp mỗi khu vực với dữ liệu thật từ máy thử, trên màn hình điện thoại và máy tính.

### T3-06 Thư và quà từ bố

- **Làm:** bố viết lời nhắn (tối đa 300 ký tự), đính kèm tùy chọn một món đồ, một số xu hoặc kim cương, gửi cho một bé. Trong app, hộp thư trên màn Phòng có dấu báo thư mới; mở thư có hiệu ứng mở quà, quà vào ví hoặc tủ đúng một lần.
- **Nghiệm thu:** gửi từ web, mở trên app, quà không nhận hai lần kể cả khi đồng bộ lại. Web admin hiện trạng thái "bé đã mở".

### T3-07 Triển khai và phát hành v0.3.0

- **Làm:** web admin deploy tự động lên Cloudflare Pages khi merge vào `main`. Cấu hình (URL Data API, khóa công khai) nằm trong biến môi trường, không có khóa bí mật nào trong trang tĩnh. Phát hành APK v0.3.0.
- **Nghiệm thu:** sau một tuần dùng thật, Claude kiểm tra mức dùng compute, dung lượng và egress trên Neon, báo chủ dự án.

## Bản 0.4 và 0.5

Hai bản này mới ghi ở mức nhiệm vụ. Claude sẽ viết tiêu chí nghiệm thu chi tiết khi bản 0.3 xong, dựa trên nhận xét sau khi bé chơi thật.

### Bản 0.4: thị trấn sống

| Mã | Nhiệm vụ |
| --- | --- |
| T4-01 | Bản đồ Thị trấn Diệu Kỳ có hình, thay cho 5 nút tạm |
| T4-02 | 5 cư dân nhờ giúp: câu thoại mở đầu và cảm ơn cho mỗi chặng, lưu trong file nội dung để sửa không cần code (Xong trên nhánh `feature/v04-town-life`, chờ review; hình chờ lô 17) |
| T4-03 | Sổ sticker: mỗi dạng bài thành thạo được một sticker, xếp theo 5 mảng, kèm 2 kim cương (Xong trên nhánh `feature/v04-town-life`, chờ review; hình chờ lô 17) |
| T4-04 | Mở khóa phòng và tòa nhà mới theo số dạng bài thành thạo (Xong trên nhánh `feature/v04-town-life`, chờ review; hình chờ lô 17) |
| T4-05 | Nghiệm thu và phát hành v0.4.0 |

### Bản 0.5: nội dung mở rộng

| Mã | Nhiệm vụ |
| --- | --- |
| T5-01 | Gói nội dung: app tải danh mục và hình mới từ Cloudflare Pages, không cần cài lại app |
| T5-02 | Bộ sưu tập theo mùa có ngày bắt đầu, kết thúc (Tết, Trung thu, Giáng sinh) (Xong trên nhánh `feature/v05-content`, chờ review; cấu hình một chỗ `app/lib/features/seasons/season_config.dart`; Trung thu và Giáng sinh chưa có hình riêng) |
| T5-03 | Nạp đề từ web admin bằng file CSV hoặc nhập từng câu, gắn mảng, bậc và lớp (Xong trên nhánh `feature/v05-content`, chờ review; app tắt sau cờ `customQuestionsEnabled = false` cho tới khi chủ dự án chạy `db/migrations/0003_custom_questions.sql`) |
| T5-04 | Thi thử 25 câu bấm giờ: 60 phút trắc nghiệm kiểu vòng loại hoặc 90 phút điền số kiểu vòng quốc gia |
| T5-05 | Chụp ảnh nhân vật, lưu vào album trong app (Xong trên nhánh `feature/v05-content`, chờ review; chưa có nút chia sẻ vì app chưa có gói chia sẻ) |
| T5-06 | Nghiệm thu và phát hành v0.5.0 |

## Nghiệm thu và bàn giao

Một nhiệm vụ chỉ được tính là Xong khi đủ bốn điều kiện: CI xanh, đạt tiêu chí nghiệm thu riêng của nhiệm vụ, Claude review Đạt, và tài liệu bàn giao đã cập nhật.

### Claude kiểm tra gì khi review

- Code làm đúng phạm vi, không tự ý đổi quyết định trong bản thiết kế.
- Test thật sự kiểm tra được lỗi: test đáp án không tự so với chính nó, test thời gian dùng `Clock` giả.
- Bằng chứng chạy thật: log lệnh, ảnh chụp màn hình, APK tải về được.
- Với câu hỏi: Claude tự lấy mẫu câu từ mỗi dạng bài để giải lại và đọc lại câu chữ tiếng Việt, tiếng Anh.
- Không có bí mật trong code, không có thư viện hay dịch vụ ngoài kế hoạch.
- Dữ liệu của bé không bị mất khi cài đè bản mới.

### Tài liệu trong repo

| File | Chứa gì | Ai cập nhật |
| --- | --- | --- |
| `docs/DESIGN.md` | Bản thiết kế tổng | Claude, khi thiết kế đổi |
| `docs/PLAN.md` | Kế hoạch này | Claude, khi kế hoạch đổi |
| `docs/HANDOVER.md` | Trạng thái hiện tại: nhiệm vụ nào xong, đang làm, bị chặn; cách build và chạy test; điểm cần biết khi tiếp tục | Muse, cuối mỗi pull request |
| `docs/DECISIONS.md` | Mỗi quyết định kỹ thuật hoặc sản phẩm mới: ngày, nội dung, lý do, ai quyết | Muse ghi, Claude xác nhận |
| `CHANGELOG.md` | Thay đổi của mỗi bản phát hành, viết cho người không đọc code | Muse, khi gắn tag |
| `docs/ASSETS.md` | Nguồn và giấy phép của hình, âm thanh | Muse |

`HANDOVER.md` là file đầu tiên một phiên làm việc mới của Muse hoặc Claude phải đọc, nên luôn phản ánh đúng trạng thái nhánh `main` và các pull request đang mở. Không làm lại việc đã xong; tiếp tục từ trạng thái thật của repo.

## Việc cần chủ dự án

Những việc này cần tài khoản hoặc quyết định của anh, Muse và Claude không tự làm được.

- [ ] Cấp cho Muse quyền ghi vào repo `lavang-0708/TimoKid`, và cho Claude quyền đọc, bình luận pull request.
- [x] Tài liệu và ba file ngân hàng câu hỏi đã có trong repo.
- [ ] Tạo keystore theo hướng dẫn trong T1-03, cất giữ cẩn thận, nạp vào GitHub Secrets. Mất keystore thì không cài đè bản mới được.
- [ ] Cho phép cài APK ngoài Play Store trên máy của bé (cài đặt "Cài ứng dụng không rõ nguồn gốc").
- [ ] Sau mỗi bản 0.x, cho bé chơi và ghi lại nhận xét.
- [ ] Trước bản 0.2: có bộ hình nhân vật nữ vẽ đúng khung (1024 x 1536, PNG trong suốt, tách lớp), từ em gái hoặc công cụ AI. Không có thì bản 0.2 dùng hình tạm.
- [ ] Trước bản 0.3: đồng ý tạo Neon project `timokid` và có tài khoản Cloudflare (gói miễn phí) để deploy web admin.
