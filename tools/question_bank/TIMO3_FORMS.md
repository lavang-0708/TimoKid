# Đợt 3: 12 dạng bổ sung (21/11)

Ưu tiên mảng Hình học (trước đó mỏng nhất: 11 dạng). Sau đợt này app có
84 dạng: lôgic 18, số học 15, lý thuyết số 17, hình học 17, tổ hợp 17.

Code sinh câu: `app/lib/features/questions/generators/timo3_generators.dart`.
Hàm giải độc lập: `app/test/features/questions/question_solvers.dart`
(đếm trực tiếp hoặc thử từng trường hợp, không chép công thức của code sinh).
Test nghiệm thu sinh 500 câu mỗi dạng mỗi mức và đối chiếu đáp án.

Khuôn khổ lớp 2: số trong phạm vi 100, nhân chia trong bảng 2–5, chia hết.
Tất cả là câu điền số; ở bậc lẻ app tự đổi thành trắc nghiệm.

| Mã dạng | Mức 1 | Mức 2 | Mức 3 |
|---|---|---|---|
| `geo.fence` | Cọc quanh vườn hình vuông | Cọc quanh vườn hình chữ nhật | Biết số cọc, tìm cạnh vườn |
| `geo.segline` | AC = AB + BC | BC = AD − AB − CD | BC = AC + BD − AD |
| `geo.units` | dm → cm | a dm b cm → cm | 1 m trừ a dm b cm |
| `geo.cutsquares` | Cắt ô 1 cm | Ô 2–3 cm | Ô 4–5 cm |
| `geo.cubefaces` | Tổng số mặt của n khối | Mặt lộ ra khi xếp hàng trên bàn | Mặt được sơn của thanh n khối |
| `geo.perimchange` | Hình vuông, cạnh dài thêm | Chỉ kéo dài chiều dài | Dài thêm, rộng bớt |
| `logic.clock` | Cộng giờ, không qua 12 | Cộng giờ qua 12 | Lùi giờ qua 12 |
| `logic.calendar` | Cộng ngày trong tháng | Sang tháng sau | Đếm ngày đến tháng sau |
| `arith.sametotal` | Tổng, thêm một số hạng | Tổng, thêm và bớt | Hiệu, thêm số bị trừ, bớt số trừ |
| `arith.missingdigits` | Một chữ số bị che | Hai chữ số, không nhớ | Hai chữ số, có nhớ |
| `number.between` | Số nằm giữa | Số chẵn nằm giữa | Số tròn chục nằm giữa |
| `comb.dice` | Hai xúc xắc, tổng 3–5 | Tổng 6–8 | Tổng từ 9–11 trở lên |
