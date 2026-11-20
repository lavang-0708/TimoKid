# D — Phòng v3b: nền + 5 đồ rời bấm được (giai đoạn 1, chỉ ảnh)

Nguồn: ảnh xem trước phòng v3b đã được chủ dự án duyệt 21/11 ~01:31 — phòng liền
một ảnh, phối cảnh 1 điểm tụ, một nguồn sáng (nắng từ cửa sổ lớn), phong cách 3D
mềm khối tròn pastel, hướng sáng trên-trái. Mọi tọa độ dưới đây theo khung
1600x900 của ảnh nền.

## 1. Nền

- Đích: `app/assets/images/backgrounds/room_v3.png`
- Khung 1600x900, PNG RGB, **694.028 byte** (≤ 1 MB).
- Ảnh gốc 2048x1152 resize về 1600x900, lượng tử hóa 256 màu + dithering
  Floyd–Steinberg (PNG đủ màu 2.243.101 byte vượt 1 MB — cùng cách làm PR #26
  và PR (C)).
- Đã xem bằng mắt: giường + gối + gấu, đèn sao, bàn học + cốc + bình hoa, kệ
  sách, tủ quần áo, thảm tròn, chậu cây, cửa sổ + bóng nắng trên sàn gỗ còn
  nguyên, không cắt cụt.

## 2. Đồ rời bấm được (5 món) — cách làm (b): VẼ RIÊNG

Không cắt từ nền (các món có viền mềm, phát sáng hoặc tương phản thấp với nền
nên cắt không sạch). Mỗi món vẽ riêng trên nền magenta rồi tách nền bằng
chroma-key, đặt đúng vị trí để phủ khít món đã vẽ sẵn trong nền (món vẽ sẵn
đóng vai trò nền, không lộ ra gây hình đôi). Đã ghép thử cả 5 món lên nền ở
đúng vị trí và xem bằng mắt: không hình đôi, món nằm đúng mặt phẳng
(giường/bàn/sàn), đúng phối cảnh, không nổi, không lệch.

| Món | Đích | PNG | Content bbox trong khung 512 | Ảnh 512 đặt tại (cỡ) | Rect hiển thị | Điểm neo (đáy) | Tỉ lệ |
|---|---|---|---|---|---|---|---|
| Gấu bông | `app/assets/images/furniture/gau_bong_v3.png` | 306.655 byte | (125,95,388,444) 264x350 | (296,341) 239x239 | x[354,477] y[385,548] | (415,548) | 0,466 |
| Đèn sao | `app/assets/images/furniture/den_sao_v3.png` | 242.411 byte | (96,91,418,449) 323x359 | (49,406) 196x196 | x[89,212] y[441,578] | (150,578) | 0,383 |
| Chậu cây | `app/assets/images/furniture/chau_cay_v3.png` | 222.629 byte | (99,119,373,440) 275x322 | (678,378) 358x358 | x[747,939] y[461,686] | (842,686) | 0,70 |
| Bình hoa | `app/assets/images/furniture/binh_hoa_v3.png` | 242.783 byte | (156,106,360,429) 205x324 | (1162,271) 283x283 | x[1248,1361] y[330,508] | (1305,508) | 0,553 |
| Cốc bút | `app/assets/images/furniture/coc_sao_v3.png` | 238.805 byte | (100,83,354,433) 255x351 | (1027,378) 161x161 | x[1059,1139] y[404,515] | (1099,515) | 0,315 |

Rect món vẽ sẵn trong nền (để đối chiếu — lớp rời phủ khít các rect này):

- Gấu bông: (355,425,475,550); đèn sao: (90,455,210,580); chậu cây:
  (785,530,900,670); bình hoa: (1250,365,1360,510); cốc bút:
  (1071,432,1127,515).
- Tỉ lệ điểm ảnh bán trong suốt (0 < alpha < 255) = **0,00%** cho cả 5 món
  (đo bằng code, sau khi dọn vệt magenta sót).
- Lưu ý riêng từng món:
  - Gấu bông: ngồi thẳng mặt trước, lông nâu nhạt; hiển thị lớn hơn món trong
    nền ~30% chiều cao (để phủ khít).
  - Đèn sao: sao vàng 5 cánh phát sáng, **vẽ riêng CÓ đế tròn** (món trong nền
    không có đế rõ) — đặt đế lên mặt tủ đầu giường; khe giữa 2 cánh dưới và
    đế là khoảng nền thật, để trong suốt.
  - Chậu cây: hiển thị lớn hẳn (193x225, tỉ lệ 0,70) vì chậu vẽ riêng thấp hơn
    chậu trong nền theo tỉ lệ — muốn phủ kín cả chậu trong nền thì phải phóng
    to; cây lớn trông vẫn tự nhiên như một chậu cây sàn.
  - Bình hoa: bình lavender 2 núm bên hông, hoa hồng/tím; hiển thị cao hơn món
    trong nền ~24% (hoa vươn lên trước kệ sách).
  - Cốc bút: cốc xanh nhạt, quai trái, 3 bút chì (đào/tím/vàng); lỗ quai để
    trong suốt.

## 3. Các mặt phẳng phối cảnh (khung 1600x900)

- Sàn (đa giác, nơi nhân vật + pet đứng):
  (0,795), (400,645), (1200,645), (1600,795), (1600,900), (0,900).
- Mặt giường (nệm/chăn, nơi gấu ngồi): y≈540–560, x 155–760; gấu neo y=548.
- Mặt tủ đầu giường: y≈580, x 30–260; đèn neo y=578.
- Mặt bàn học: y≈490–515, x 1070–1470; bình neo y=508, cốc neo y=515.
- Mặt kệ sách (kệ gắn tường phía trên bàn): các đợt kệ y≈180, 330, 470
  (xấp xỉ), x 1150–1470.

## 4. Dấu chân trên sàn (cho PR (G) — vùng đi được = đa giác sàn trừ các dấu chân này)

- Giường: (155,645)–(760,700).
- Bàn học: (1070,645)–(1470,790).
- Tủ quần áo: (1460,645)–(1600,880).
- Kệ sách: gắn tường phía trên bàn (x 1150–1470, y 40–640) — **không có dấu
  chân riêng trên sàn**; hình chiếu xuống sàn trùng dấu chân bàn học.
- Tủ đầu giường: (30,700)–(260,800).

## 5. Ghế ở bàn học (cho PR (G) — tương tác ngồi ghế)

- Rect ghế: x 970–1240, y 490–790.
- Lưng ghế: x 970–1120, y 490–620.
- Mặt ghế: x 1000–1210, y 615–660; tâm mặt ghế ≈ (1105,640).
- Chân ghế chạm sàn y≈790.

## 6. Mốc tỉ lệ (đo từ ảnh thật, khung 1600x900)

- Giường: mặt trước cao 160 px (sàn y≈700 đến mặt nệm y≈540); đầu giường cao
  đến y≈390. Đầu giường x 155–350, y 390–560; thân giường x 155–760,
  y 540–700.
- Tủ quần áo: cao 810 px (y 70–880); x 1460–1600 (mép phải cắt ở x=1600).
- Cửa sổ: cao 350 px (y 100–450), bệ cửa y≈450; khung cửa x 590–1080;
  rèm trái x 590–750, rèm phải x 1300–1450.
- Bàn học: cao 300 px (sàn y≈790 đến mặt bàn y≈490).
- Ghế: mặt ghế cao 150 px so với sàn (sàn y≈790 đến mặt ghế y≈640).
- Lò sưởi (radiator): x 640–930, y 490–600.
- Thảm tròn: ellipse x 430–1080, y 640–790.
- Kệ mây (tường trái): x 60–220, y 200–300.
- Khung ảnh: x 230–310, y 180–320.
- Đèn mây trần: x 730–870, y 0–55 (cắt ở mép trên).
- Tủ đầu giường: x 30–260, mặt y≈580, đáy y≈795.
- Kệ sách: x 1150–1470, y 40–640.

## 7. Ghi chú cho giai đoạn 2 (code)

- Đồ rời **không có bóng đổ vẽ sẵn** (chroma-key đã gỡ bóng) — giai đoạn 2 vẽ
  bóng ellipse mềm đen 20% dưới mỗi món như PR (1) Phòng đã làm, neo theo
  điểm neo (đáy) ở bảng mục 2; không có món treo trong đợt này.
- Đồ vẽ riêng hơi lớn hơn món vẽ sẵn trong nền (để phủ khít, tránh hình đôi) —
  xem lưu ý riêng từng món ở mục 2.
- Cách tách nền: vẽ trên nền magenta rồi chroma-key theo hue (nền hue
  311–331°, cửa sổ ±18° (chậu cây ±24°), sat > 0,40), giữ các thành phần
  ≥ 100 px, **không** chỉ giữ thành phần lớn nhất (gấu tách đầu/thân),
  **không** fill lỗ bừa (khoảng trống giữa các lá/cành và khe sao là nền thật —
  fill sẽ tô magenta), dọn thêm điểm ảnh magenta sót (hue 280–350°,
  sat > 0,35) — trừ bình hoa (thân lavender + cánh hồng là màu thật, không
  dọn).
- Kiểm chứng: ghép thử cả 5 món lên nền ở đúng vị trí + xem bằng mắt (file
  kiểm chứng local `work/check_room_composite.png`, không đẩy lên) — không
  hình đôi, món nằm đúng mặt phẳng, đúng phối cảnh, không nổi, không lệch.
- Đồng bộ theo quy tắc chủ dự án 21/11: cùng phong cách 3D mềm, cùng hướng
  sáng trên-trái, cùng tỉ lệ — nhân vật đứng trong phòng phải đúng cỡ so với
  giường/tủ/cửa sổ (xem mốc mục 6), chân chạm sàn, có bóng đổ đúng mặt sàn.
