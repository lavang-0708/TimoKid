# Dạng bài bổ sung TIMO lớp 2 (`gen_timo2.py`)

Các dạng được rút ra từ đề vòng loại TIMO lớp 2 năm 2026–2027 (ca 1, ca 2) và 4 đề ôn vòng loại lớp 2. Chỉ lấy **dạng bài**. Số và lời văn đều tự soạn lại, không chép nguyên văn đề.

Khuôn khổ lớp 2 được giữ trong mọi dạng:
- số trong phạm vi 100 (riêng dãy số được tới 200);
- nhân chỉ dùng bảng 2–5, chia luôn là chia hết;
- tổ hợp chỉ dùng số có 1–2 chữ số.

Lệnh chạy:

```
python3 tools/question_bank/gen_timo2.py    # sinh questions_timo2.json (300 câu)
python3 tools/question_bank/check_timo2.py  # giải lại độc lập từ params, phải ra 0 lỗi
```

Mỗi câu đều có:
- đề, gợi ý và lời giải bằng cả tiếng Việt và tiếng Anh;
- mức độ 1–3;
- `params` để giải lại;
- `answer_type` là `number` (kèm 3 đáp án nhiễu) hoặc `choice` (kèm `choices`, `answer` là chỉ số).

| Mảng | form | Nội dung | Mức 1 → 3 |
|---|---|---|---|
| logic | classsize | cao hơn a, thấp hơn b, cao bằng c → a+b+c+1 | số lớn dần, thêm c |
| logic | weekday_rel | k ngày trước hôm nay là thứ X; hỏi hôm qua/ngày mai/ngày kia/m ngày nữa | k 1–3 → 7–13 |
| logic | order3 | các câu "nặng hơn", tìm vật nặng/nhẹ nhất | 3 vật → 4 vật |
| logic | seq_grow | dãy có khoảng cách tăng dần (2, 6, 12, 20…) hoặc giảm dần | tăng → giảm |
| logic | interleave | hai dãy xen kẽ (50, 3, 45, 6…) | |
| logic | cyclepattern | hình lặp chu kỳ: hình thứ n / đếm hình X trong n hình đầu | chu kỳ 3 → 5 |
| logic | laps | n vòng × t phút + (n−1) lần nghỉ | |
| arith | altsum | a − b + c − d … ghép cặp | 5 → 8 số hạng |
| arith | runsum | tổng dãy cách đều ngắn, ghép đầu–cuối | |
| arith | cryptarith | AB ± A = KQ, tìm B (nghiệm duy nhất) | |
| arith | arrowchain | ? → +a → −b → … → KQ, tính ngược | 2 → 4 bước |
| arith | signs | điền + / − (đúng một cách), trắc nghiệm | 4 → 5 số |
| arith | flowerx | ✿+✿−a = ✿+b | 2 → 3 bông |
| arith | factor_out | m×a + b×m + … = m×(a+b+…) | m = 2 → 3–5 |
| number | digitcond | đếm số có 2 chữ số theo điều kiện chữ số | |
| number | parity_ops | đếm phép tính có kết quả chẵn/lẻ | |
| number | kth | số lớn/bé thứ k | |
| number | giveequal | cho bao nhiêu để bằng nhau / còn hơn c | |
| number | pages | chia làm tròn lên (tem, trứng, hộp) | |
| number | countsteps | đếm số trong dãy cách đều từ a đến b | bước 2 → 3, 5 |
| geo | pointsegs | n điểm không thẳng hàng → số đoạn thẳng | n 3 → 6 |
| geo | shapeparts | đếm cạnh/đỉnh/mặt (tam giác, vuông, chữ nhật, lập phương) | |
| comb | makenum_parity | lập số chẵn/lẻ 2 chữ số khác nhau (có thể có 0) | |
| comb | minsum2 | 4 chữ số → hai số 2 chữ số, tổng nhỏ/lớn nhất | |
| comb | freebie | mua k tặng 1 với M nghìn đồng | |
| comb | vases | n hoa giống nhau vào 3 lọ, không lọ trống | n 4 → 7 |
| comb | kth_choose | chọn 2 bạn (không thứ tự) / trưởng + phó (có thứ tự) | n ≤ 6 |

## Đã đưa vào app

24 dạng điền số đã được chuyển sang Dart trong `app/lib/features/questions/generators/timo2_generators.dart` và đăng ký trong `question_registry.dart`. Sau đợt này app có 72 dạng (logic 16, arith 13, number 16, geo 11, comb 16); đợt 3 thêm 12 dạng nên **hiện app có 84 dạng** (logic 18, arith 15, number 17, geo 17, comb 17) — xem `TIMO3_FORMS.md` và `generatorCountByTopic` trong `question_registry.dart`.

Ba dạng chỉ có trắc nghiệm vẫn chỉ nằm trong `questions_timo2.json`: weekday_rel, order3 và signs. Trong app, phần `cyclepattern` chỉ dùng biến thể "đếm hình". Tên dạng trong Dart:
- `seq_grow` → `logic.seqgrow`
- `factor_out` → `arith.factorout`
- `parity_ops` → `number.parityops`
- `makenum_parity` → `comb.makenumparity`
- `kth_choose` → `comb.pick2`

Test `question_generators_test.dart` sinh 500 câu cho mỗi mức của mỗi dạng. Đáp án được giải lại độc lập trong `question_solvers.dart`.

Đề ngày cũng đổi cách chọn dạng: trong các dạng chưa dùng ở chặng, app ưu tiên dạng bé ít gặp nhất trong 7 ngày qua, để các dạng được xoay vòng đều.
