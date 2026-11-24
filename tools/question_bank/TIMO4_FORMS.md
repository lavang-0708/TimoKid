# Đợt 4: 6 dạng bổ sung (24/11)

Chủ dự án nhờ thu thập thêm dạng đề trong lúc chờ hình. Nguồn đề mở trên
mạng phần lớn bị khóa (Scribd, HoaTieu); các dạng dưới lấy từ phần mô tả
đề thử/đề quốc gia TIMO lớp 2 còn đọc được (ví dụ hỏi số cạnh của hình
chóp khi biết số đỉnh, bảng số theo quy luật hàng) và kiểu bài lớp 2 quen
thuộc chưa có trong app. Số và lời văn tự soạn. Sau đợt này app có 90
dạng: lôgic 19, số học 16, lý thuyết số 18, hình học 19, tổ hợp 18.

Code sinh câu: `app/lib/features/questions/generators/timo4_generators.dart`.
Hàm giải độc lập: `app/test/features/questions/question_solvers.dart`
(thử từng giá trị, dựng khối bằng danh sách đỉnh/cạnh, liệt kê cách tô).

| Mã dạng | Mức 1 | Mức 2 | Mức 3 |
|---|---|---|---|
| `logic.table` | Bảng 3 cột, cột 3 = cột 1 + cột 2 | Cột 3 = cột 1 × cột 2 | Nhân, thiếu ô cột 2 |
| `arith.pairsum` | 1 + 2 + … + n (ghép cặp) | 2 + 4 + … + 2n | Dãy cách đều bước 3–5 |
| `number.multiples` | Số chia hết cho k từ 1 đến ≤ 30 | Từ 1 đến ≤ 60 | Trong khoảng a..b |
| `geo.pyramid` | Chóp đáy n cạnh: số đỉnh | Số cạnh | Biết số đỉnh, tìm số cạnh |
| `geo.prism` | Lăng trụ đáy n cạnh: số đỉnh | Số cạnh | Biết số đỉnh, tìm số cạnh |
| `comb.flag` | Cờ 3 sọc, 3 màu, khác hết | 3 màu, sọc kề khác màu | 4 màu, sọc kề khác màu |
