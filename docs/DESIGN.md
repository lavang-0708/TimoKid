# Bản thiết kế tổng: TimoKid

> Bản markdown của tài liệu thiết kế, xuất ngày 2026-11-17. Bản gốc do Claude và chủ dự án soạn. Khi thiết kế thay đổi, Claude cập nhật file này.

## Tóm tắt

TimoKid là app Android giúp bé lớp 2 ôn thi Olympic Toán TIMO bằng cách giải toán để nuôi pet, thay trang phục nhân vật và mở rộng Thị trấn Diệu Kỳ của mình. Bố theo dõi tiến độ và gửi quà qua một trang web admin riêng.

| Hạng mục | Đã chốt |
| --- | --- |
| Người dùng | Bé gái lớp 2, đọc hiểu tốt. Hỗ trợ nhiều bé trong một tài khoản phụ huynh, mỗi bé có lớp riêng |
| Câu hỏi | Song ngữ Việt - Anh, 5 mảng TIMO, sinh từ khuôn có tham số. Phụ huynh nạp thêm đề được |
| Cách học | Sai lần đầu được gợi ý và thử lại, sai lần hai xem lời giải. Câu sai vào sổ ôn tập giãn cách |
| Độ khó | App tự chỉnh theo từng mảng, trong phạm vi lớp của bé |
| Cổng mỗi ngày | 1 đề 25 câu chia 5 chặng, làm xong mới mở phần chơi |
| Game | Tạo nhân vật, thay đồ, nuôi pet, phòng và thị trấn mở khóa dần |
| Phần thưởng | Đồ mới và pet mới chỉ có được nhờ giải toán |
| Hình ảnh | Hai dáng nhân vật nam và nữ riêng. Họa sĩ vẽ nhân vật và món chủ đạo, phần còn lại vẽ bổ sung và đổi màu bằng code |
| Công nghệ | Flutter, màn hình ngang, chạy offline trước, cài bằng file APK |
| Hạ tầng | Neon project riêng (Data API và Auth), web admin trên Cloudflare Pages, GitHub Actions build APK. Không dùng Railway |

## Năm định hướng

1. **Câu hỏi là khuôn sinh câu, không phải danh sách cố định.** Với 25 câu mỗi ngày, một bộ 267 câu sẽ hết sau khoảng 11 ngày. App sinh câu mới từ 48 dạng bài có tham số và theo dõi bé theo dạng bài.
2. **Đề 25 câu chia 5 chặng.** Mỗi chặng 5 câu ở một khu của thị trấn, xong chặng có thưởng nhỏ, bé nghỉ giữa chừng rồi làm tiếp được.
3. **Thưởng cho nỗ lực và tiến bộ.** Không có hộp quà may rủi, không quảng cáo. Pet không ốm hay buồn khi bé nghỉ. Sai không bị trừ xu hay mất đồ.
4. **Nội dung thêm được mà không cần cài lại app.** Đồ mới, pet mới và câu hỏi mới là các gói nội dung đẩy lên từ web admin.
5. **Đưa bản thô cho bé chơi thật sớm.** Mọi con số trong tài liệu này (giá đồ, mức thưởng, ngưỡng lên mức) là đề xuất ban đầu, chỉnh lại sau khi bé chơi thử.

## Hành trình của bé

Lần đầu mở app, bé đi qua một câu chuyện ngắn thay vì màn đăng nhập. Bố đăng nhập một lần lúc cài đặt, sau đó bé không cần mật khẩu.

### Lần đầu mở app

1. Bé tạo nhân vật: chọn giới tính, màu da, kiểu và màu tóc, mắt, miệng, rồi đặt tên.
2. Bé chọn một trong ba quả trứng: Chó Tinh Anh, Mèo Mũm Mĩm hoặc Thỏ Bánh Bao. Trứng nở sau khi bé làm xong chặng toán đầu tiên.
3. Bé vào căn phòng của mình. Đây là màn chính, cửa phòng dẫn ra thị trấn.

### Mỗi ngày

1. Bé mở app và thấy hộp thư. Nếu bố gửi lời nhắn hay quà thì bé mở ra trước.
2. Phần thay đồ và chơi với pet đang khóa. Bé ra thị trấn, năm cư dân ở năm khu đang chờ nhờ giúp.
3. Bé làm lần lượt 5 chặng, mỗi chặng 5 câu, thứ tự tùy bé chọn. Xong mỗi chặng bé nhận xu.
4. Xong đủ 5 chặng, phần chơi mở khóa đến hết ngày. Bé mua đồ, thay trang phục, chăm pet, trang trí phòng.
5. Muốn thêm xu, bé quay lại thị trấn làm thêm chặng tự chọn, không giới hạn.

## Phần học

App theo dõi bé theo dạng bài, ví dụ "bài cái cân" hay "đếm hình vuông", và sinh câu mới cho từng dạng mỗi lần hỏi.

### Ngân hàng câu hỏi

- 5 mảng: Tư duy lôgic, Số học / Đại số, Lý thuyết số, Hình học, Tổ hợp.
- 48 dạng bài (mỗi `form` trong `gen.py` là một dạng). Mỗi dạng hỗ trợ từ 1 đến 3 mức trong Dễ, Vừa, Khó; 17 dạng đủ cả 3 mức. Bộ 267 câu đã soạn (`tools/question_bank/questions.json`) là mẫu của các dạng này.
- Mỗi dạng là một khuôn: đề tiếng Việt, đề tiếng Anh, từ khóa song ngữ, gợi ý, lời giải từng bước, và công thức tính đáp án. App thay số, tên và hình để ra câu mới. Đáp án luôn do code tính.
- Câu phụ huynh nạp từ web admin là câu cố định, được gắn mảng và mức để trộn vào đề.

### Đề mỗi ngày

- 25 câu, 5 chặng, mỗi chặng là 5 câu của một mảng. Không bấm giờ.
- Mỗi chặng là một ải nhỏ: câu 1 và 2 thấp hơn bậc hiện tại một bậc để khởi động, câu 3 đúng bậc, câu 4 từ sổ ôn tập (nếu trống thì đúng bậc), câu 5 là câu trùm cao hơn một bậc.
- Kiểu trả lời (trắc nghiệm 4 lựa chọn hoặc điền số) do bậc của câu quyết định, xem thang ải bên dưới. Các dạng bài vốn là câu chọn (ai cao nhất, thứ mấy trong tuần) luôn là trắc nghiệm.
- Đề hiện bằng tiếng Việt, có nút xem bản tiếng Anh và bảng từ khóa.

### Độ khó và thành thạo

- Mỗi mảng có một thang ải 6 bậc, ghép mức nội dung với kiểu trả lời: bậc 1 Dễ trắc nghiệm, bậc 2 Dễ điền số, bậc 3 Vừa trắc nghiệm, bậc 4 Vừa điền số, bậc 5 Khó trắc nghiệm, bậc 6 Khó điền số. Bé lên một bậc khi đúng từ 8 trên 10 câu gần nhất, xuống một bậc khi đúng dưới 5 trên 10. Đáp án nhiễu của câu trắc nghiệm là các lỗi sai hay gặp. Bố khóa được kiểu trả lời cho từng bé trên web admin.
- Bậc 6 là trần của lớp bé đang học, app không đẩy sang đề lớp trên.
- Một dạng bài được tính là thành thạo khi bé đúng ngay lần đầu 4 trong 5 câu gần nhất ở mức cao nhất mà dạng đó hỗ trợ, và không thấp hơn mức Vừa nếu dạng có mức Vừa. Thành thạo là thước đo để pet lớn, mở tòa nhà và nhận sticker.

### Khi bé trả lời sai

1. Sai lần đầu: hiện gợi ý, bé làm lại. Đúng ở lần này được nửa số xu.
2. Sai lần hai: hiện lời giải từng bước.
3. Dạng bài đó vào sổ ôn tập. App hỏi lại một câu cùng dạng nhưng khác số sau 1 ngày, 3 ngày và 7 ngày. Đúng cả ba lần thì ra khỏi sổ, sai thì tính lại từ đầu.

### Thi thử

Đề 25 câu có bấm giờ, không gợi ý, chấm điểm khi nộp: 60 phút trắc nghiệm kiểu vòng loại hoặc 90 phút điền đáp án kiểu vòng quốc gia. Tính năng này thuộc bản sau.

## Phần game

Bé có một nhân vật, một pet và một căn phòng. Mọi thứ mới đều đến từ việc giải toán.

### Nhân vật

- Hai dáng riêng cho nam và nữ. Mỗi món quần áo có hai phiên bản, bản đầu ưu tiên đủ đồ cho dáng nữ.
- Các lớp ghép chồng: thân, mắt, miệng, tóc sau, tóc trước, áo, quần hoặc váy, giày, phụ kiện đầu, phụ kiện tay.
- Màu da, tóc, mắt, miệng chọn từ bảng màu. App tự tô màu, họa sĩ không cần vẽ từng màu.
- Quần áo cũng được nhân bản bằng đổi màu và phủ họa tiết (chấm bi, kẻ sọc, hoa).
- Bé tự đặt tên nhân vật, app không có tên đặt sẵn.

### Pet

- Bé chọn một trong ba quả trứng: Chó Tinh Anh, Mèo Mũm Mĩm hoặc Thỏ Bánh Bao. Trứng nở sau chặng toán đầu tiên.
- Ba giai đoạn: mới nở, nhỡ, lớn. Pet lên giai đoạn nhỡ khi bé thành thạo 10 dạng bài, lên lớn khi thành thạo 30 dạng.
- Bé cho pet ăn và chơi bằng đồ mua ở cửa hàng. Pet phản ứng vui khi được chăm, không có trạng thái đói, ốm hay buồn.
- Hai loài còn lại mua bằng kim cương.

### Phòng và thị trấn

- Căn phòng là màn chính. Bé đặt nội thất, chạm vào đồ vật để chúng phản ứng.
- Thị trấn Diệu Kỳ có 5 khu ứng với 5 mảng toán. Tên đề xuất: Lâu đài Lôgic, Tiệm bánh Số học, Tháp Con số, Vườn Hình học, Hội chợ Tổ hợp.
- Mỗi khu có một cư dân nhờ bé giúp. Chặng toán là việc cư dân nhờ, ví dụ cô chủ tiệm bánh cần đếm bánh.
- Phòng mới và tòa nhà mới (cửa hàng thú cưng, tiệm làm tóc, sân chơi) mở khóa dần theo số dạng bài thành thạo.

### Luật xu và kim cương

Xu dùng mua đồ thường, kim cương dùng mua đồ hiếm và pet mới. Một ngày làm đủ đề cho khoảng 100 đến 130 xu, đủ mua 2 đến 3 món thường. Các mức này chỉnh được từ web admin.

| Việc bé làm | Thưởng |
| --- | --- |
| Đúng lần đầu, mức Dễ / Vừa / Khó (bậc 1-2 / 3-4 / 5-6) | 2 / 3 / 5 xu |
| Đúng sau gợi ý | Nửa số xu, làm tròn lên |
| Đúng câu từ sổ ôn tập | Gấp đôi số xu |
| Xong một chặng | 5 xu |
| Xong đề ngày | 20 xu và 1 kim cương |
| Thành thạo một dạng bài mới | 1 sticker và 2 kim cương |

| Món | Giá |
| --- | --- |
| Đồ thường (quần áo, thức ăn pet, nội thất) | 30 đến 80 xu |
| Đồ hiếm | 3 đến 8 kim cương |
| Pet mới | 10 kim cương |

### Các tính năng gắn kết, theo thứ tự ưu tiên

1. **Thư và quà từ bố.** Bố viết lời nhắn và chọn món quà trên web admin. Bé mở app thấy hộp thư có quà.
2. **Pet lớn theo giai đoạn**, như mô tả ở trên.
3. **Cư dân thị trấn nhờ giúp.** Mỗi cư dân có vài câu thoại mở đầu và cảm ơn.
4. **Sổ sticker thành tích.** Mỗi dạng bài thành thạo là một sticker dán vào sổ, xếp theo 5 mảng.
5. **Bộ sưu tập theo mùa.** Tết, Trung thu, Giáng sinh. Mỗi bộ là một gói nội dung có ngày bắt đầu và kết thúc.

## Màn hình trong app

App có 12 màn hình, tất cả nằm ngang và tự co giãn cho điện thoại lẫn máy tính bảng.

| Màn hình | Bé làm gì ở đây |
| --- | --- |
| Cài đặt lần đầu | Bố đăng nhập, chọn hoặc tạo hồ sơ bé, chọn lớp |
| Chọn hồ sơ | Chọn bé nào đang chơi (chỉ hiện khi có từ 2 bé) |
| Tạo nhân vật | Chọn giới tính, da, tóc, mắt, miệng, màu sắc, đặt tên |
| Chọn trứng | Chọn 1 trong 3 quả trứng |
| Phòng của bé | Màn chính: nhân vật, pet, nội thất, hộp thư, cửa ra thị trấn |
| Thị trấn | Bản đồ 5 khu, cư dân đang chờ, tiến độ đề ngày, tòa nhà còn khóa |
| Làm toán | Câu hỏi, hình vẽ, ô trả lời, nút tiếng Anh, gợi ý, lời giải |
| Kết quả chặng | Số câu đúng, xu nhận được, lời cảm ơn của cư dân |
| Tủ đồ | Kéo thả trang phục lên nhân vật |
| Cửa hàng | Mua quần áo, đồ cho pet, nội thất |
| Hộp thư | Đọc lời nhắn và mở quà từ bố |
| Sổ sticker | Xem các dạng bài đã thành thạo theo 5 mảng |

## Web admin cho phụ huynh

Web admin là một trang web tĩnh riêng, bố đăng nhập bằng cùng tài khoản với app để xem thống kê và điều khiển nội dung. Trong app không có màn phụ huynh.

| Khu vực | Chức năng |
| --- | --- |
| Thống kê | Chọn bé, xem số câu đã làm, tỉ lệ đúng theo 5 mảng, thời gian học mỗi ngày, số ngày hoàn thành đề |
| Dạng bài | Danh sách dạng bài đã thành thạo, đang yếu, đang nằm trong sổ ôn tập |
| Thư và quà | Viết lời nhắn, đính kèm một món đồ, xu hoặc kim cương, gửi cho một bé |
| Nạp đề | Tải lên file CSV hoặc nhập từng câu, gắn mảng, mức và lớp |
| Nội dung | Thêm đồ mới vào cửa hàng, đặt giá, bật tắt bộ sưu tập theo mùa |
| Cài đặt | Quản lý hồ sơ các bé, lớp của từng bé, mức thưởng xu, khóa kiểu trả lời cho từng bé |

Số liệu trên web chỉ cập nhật sau khi máy của bé có mạng và đồng bộ xong. Trang thống kê hiện thời điểm đồng bộ gần nhất.

## Kiến trúc và dữ liệu

Hệ thống không có backend tự viết: app và web admin cùng gọi thẳng Data API của một Neon project riêng, nằm trong gói miễn phí.

```
App Android (Flutter, SQLite trên máy, chạy offline)
        <-- đồng bộ khi có mạng -->  Neon project TimoKid (Postgres, Data API, Auth)  <-- đọc và ghi -->  Web admin (trang tĩnh, Cloudflare Pages)
GitHub repo và Actions: build file APK cho app, deploy trang web admin
```

App ghi mọi thứ vào SQLite trên máy trước, rồi đẩy lên Neon khi có mạng. Web admin đọc thống kê và ghi thư, quà, cài đặt vào cùng database đó.

### Đồng bộ

- Bé chơi được hoàn toàn khi không có mạng. Mất mạng hoặc Neon tạm dừng chỉ làm chậm việc đồng bộ.
- Chiều lên: lượt trả lời và giao dịch xu là các dòng chỉ thêm, không sửa, nên không có xung đột. App xếp chúng vào hàng chờ và gửi theo lô.
- Chiều xuống: thư, quà, cài đặt, câu hỏi nạp thêm và gói nội dung. App chỉ tải phần thay đổi kể từ lần đồng bộ trước để tiết kiệm egress.
- Phân quyền theo dòng (RLS): mỗi tài khoản phụ huynh chỉ đọc ghi được dữ liệu của gia đình mình.

### Các bảng dữ liệu

| Bảng | Chứa gì |
| --- | --- |
| families | Tài khoản phụ huynh |
| children | Hồ sơ từng bé: tên, lớp, nhân vật đã tạo |
| attempts | Mỗi lượt trả lời: dạng bài, mức, đúng hay sai, số lần thử, thời gian |
| skill_progress | Mức hiện tại theo mảng và trạng thái thành thạo theo dạng bài |
| review_queue | Sổ ôn tập: dạng bài, ngày hỏi lại, số lần đã đúng |
| daily_sets | Đề từng ngày và tiến độ 5 chặng |
| wallet_ledger | Mọi lần cộng trừ xu và kim cương, kèm lý do |
| inventory | Đồ bé sở hữu, món đang mặc, nội thất đã đặt |
| pets | Pet của bé và giai đoạn lớn |
| messages | Thư và quà từ bố, trạng thái đã mở |
| custom_questions | Câu hỏi phụ huynh nạp |
| content_packs | Gói nội dung: danh mục đồ, giá, hình, thời gian hiệu lực |
| settings | Mức thưởng, khóa mức khó và các cài đặt khác |

Cách cấu hình cụ thể của Neon Auth và Data API sẽ được kiểm tra theo tài liệu Neon khi bắt đầu dựng phần đồng bộ. Hình của gói nội dung nằm trong repo và được phát qua Cloudflare Pages, không dùng hạn mức egress của Neon.

## Hướng dẫn vẽ cho họa sĩ

Mọi lớp của nhân vật được vẽ trên cùng một khung hình và xuất thành file riêng, để app chồng lên nhau là khớp mà không cần căn chỉnh. Phong cách chuẩn là tông pastel mềm, viền trắng kiểu sticker, theo các tấm phác ý tưởng hiện có (nhân vật nữ, pet, trứng, căn phòng). Các tấm này vẽ bằng AI. Từ 18/11/2026 chủ dự án chốt dùng chúng làm nguồn hình chính: tách nền, cắt từng lớp và món, sửa lỗi theo bảng trong `assets/concept/README.md`; món thiếu hoặc hỏng thì vẽ bổ sung cùng phong cách (PLAN điểm (k)). Họa sĩ có thể thay dần bằng hình vẽ tay theo cùng quy cách dưới đây.

### Quy cách file

- Khung hình nhân vật: 1024 x 1536 px, nền trong suốt. Dáng nam và dáng nữ mỗi dáng có một khung riêng, nhân vật đứng thẳng, nhìn chính diện. File khung phác: `assets/templates/`.
- Mỗi lớp là một file PNG nền trong suốt, đúng kích thước khung, chỉ chứa phần của lớp đó ở đúng vị trí. JPEG chỉ dùng cho hình nền phòng và thị trấn, vì JPEG không có nền trong suốt nên không chồng lớp được.
- Phần cần đổi màu (da, tóc, mắt, miệng, vải quần áo) tô một màu xám sáng duy nhất, bóng đổ dùng xám đậm hơn. App nhân màu lên lớp xám này.
- Nét viền và chi tiết không đổi màu (khuy áo, họa tiết cố định) xuất thành file riêng đặt tên thêm đuôi `_line`.
- Tên file: `<dáng>_<lớp>_<tên món>.png`, ví dụ `girl_hair_front_bob.png`, `girl_top_tshirt.png`, `girl_top_tshirt_line.png`.
- Pet và đồ vật: 512 x 512 px, PNG nền trong suốt, mỗi hình một file.

### Thứ tự lớp, từ dưới lên

1. Tóc sau
2. Thân (da)
3. Giày
4. Quần hoặc váy
5. Áo
6. Mắt, miệng
7. Tóc trước
8. Phụ kiện đầu, phụ kiện tay

### Danh sách hình cho bản đầu

| Hình | Số lượng | Ai vẽ |
| --- | --- | --- |
| Thân nhân vật | 2 (nữ vẽ trước, nam sau) | Họa sĩ |
| Kiểu mắt | 3 | Họa sĩ |
| Kiểu miệng | 3 | Họa sĩ |
| Kiểu tóc | 3 cho nữ, 2 cho nam | Họa sĩ |
| Trang phục và phụ kiện chủ đạo | 5 đến 10 món cho dáng nữ | Họa sĩ |
| Pet | 3 loài (mèo, chó, thỏ), mỗi loài 3 giai đoạn, kèm 3 quả trứng | Họa sĩ |
| Nội thất, thức ăn pet, đồ chơi, nơ, kẹp tóc, túi | 20 đến 30 món | Claude vẽ theo phong cách mẫu, họa sĩ duyệt |
| Nền phòng, nền thị trấn, 5 cư dân | Bản đầu dùng hình tạm | Claude vẽ tạm, thay sau |

Ba loài pet thêm 9 hình pet và 3 quả trứng. Cách giảm tải: bản đầu chỉ cần 3 quả trứng và giai đoạn mới nở của cả ba loài; giai đoạn nhỡ, lớn và dáng nam vẽ dần sau.

## Lộ trình

App ra theo 5 bản nhỏ, mỗi bản là một file APK bé cài và chơi được. Chưa có mốc ngày, thứ tự dưới đây là thứ tự làm.

1. **Bản 0.1, lõi học.** Repo, khung Flutter, GitHub Actions build APK. Màn làm toán song ngữ, khuôn sinh câu cho 5 mảng, đề ngày 5 chặng, gợi ý và lời giải, sổ ôn tập, độ khó tự chỉnh. Hình tạm.
2. **Bản 0.2, lõi game.** Mở đầu với tạo nhân vật và chọn trứng, phòng của bé, tủ đồ, cửa hàng, xu và kim cương, pet 3 giai đoạn, âm thanh và hiệu ứng. Thay hình thật của họa sĩ khi có.
3. **Bản 0.3, đồng bộ và web admin.** Neon project, đăng nhập, nhiều bé, đồng bộ hai chiều. Web admin có thống kê, thư và quà từ bố, cài đặt.
4. **Bản 0.4, thị trấn sống.** Cư dân nhờ giúp, sổ sticker, mở khóa phòng và tòa nhà mới.
5. **Bản 0.5, nội dung mở rộng.** Gói nội dung và bộ sưu tập theo mùa, nạp đề từ web admin, thi thử bấm giờ, chụp ảnh nhân vật.

Sau bản 0.1 và 0.2, bé chơi thử khoảng một tuần để chỉnh độ dài đề, mức thưởng và giá đồ trước khi làm tiếp.

## Các điểm đã chốt thêm (17/11/2026)

| Điểm | Đã chốt |
| --- | --- |
| Tên | App TimoKid, Thị trấn Diệu Kỳ |
| Pet đầu tiên | Ba quả trứng nở ra Chó Tinh Anh, Mèo Mũm Mĩm hoặc Thỏ Bánh Bao |
| Tên nhân vật | Bé tự đặt, app không có tên đặt sẵn |
| Phong cách hình | Tông pastel mềm, viền trắng kiểu sticker |
| Định dạng file vẽ | PNG nền trong suốt cho nhân vật, quần áo, pet, đồ vật; JPEG chỉ cho hình nền |
| Nhắc học bằng thông báo | Không làm |
| Kiểu trả lời | Ghép vào độ khó thành thang ải 6 bậc, xen kẽ trắc nghiệm và điền số |
| Lưu hình gói nội dung | Bộ hình ban đầu đóng gói trong APK; hình thêm sau để trong repo, phát qua Cloudflare Pages |
