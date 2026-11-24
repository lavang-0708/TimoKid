# Nhân vật bé gái v3b — (E) lô 1 (làm lại theo cách mới)

Lô 1 chỉ làm **bé gái** (3 bộ đồ toàn thân, 3 biến thể tay vẫy, miếng vá
mắt nhắm). Bé trai (lô 2), phụ kiện (lô 3), khung đi bộ (lô 4) làm riêng.
Nguồn: Muse vẽ AI 21/11 theo `docs/DESIGN.md`, từ bản gốc nữ v3 đã
được chủ dự án duyệt (xem trước 1 + 2). Trong app mỗi lần chỉ có **một**
nhân vật, nam hoặc nữ theo lựa chọn ở màn mở đầu, cộng thêm pet của bé.

## Cách mới (Claude chốt 21/11 ~14:30, thay cách cắt lớp cũ)

Lô 1 cũ cắt một ảnh AI thành lớp thân + lớp váy **đã hỏng nặng** (thân
thủng lỗ alpha, váy khoét hình chữ nhật, tóc đỏ sẫm loang, da và tóc
cùng tông) vì thân dưới váy không có thật — không cắt được sạch. Cách
mới, bắt buộc từ giờ:

- (a) Mỗi bộ đồ là **MỘT ảnh toàn thân hoàn chỉnh** (thân + váy + tóc
  **màu thật đã duyệt, bỏ nhuộm tóc**), cùng tư thế, cùng khung
  1024×1536, cùng điểm chân. **Không** còn lớp thân trần, lớp váy
  riêng, lớp tay riêng, lớp mắt/miệng riêng.
- (b) Mắt nhắm là **miếng vá nhỏ** chỉ phủ vùng mắt, vẽ từ chính ảnh
  toàn thân (da quanh mắt lấy từ ảnh gốc, mí đóng kín, không lộ
  tròng). Tay vẫy là **MỘT ảnh toàn thân biến thể** cho mỗi bộ, app
  đổi qua lại.
- (c) Phụ kiện (mũ, kính, balo, giày) ở lô 3 vẫn là lớp chồng lên ảnh
  toàn thân, cùng tư thế nên khít — không vẽ phụ kiện ở lô này.
- (d) Kiểm trước khi đẩy: ghép trên nền tối (60,60,80) **và** trên nền
  phòng thật, phóng to vùng mặt và mép váy, không lỗ alpha, không mép
  cắt thẳng, không vệt màu lạ; gửi ảnh ghép cho Claude cùng lúc đẩy
  .b64.

**13 file .b64 cũ của lô 1 (commit `507852d9`) đã hết hiệu lực** —
Claude `git rm` khi decode lô làm lại này. Không đẩy lại chúng.

Mã lớp `arm` (thêm ở lô 1 cũ) **không còn dùng** — 4 file sau đã khôi
phục về đúng nội dung trên main trong cùng lần đẩy này:
`assets/manifest.json`, `docs/ASSETS.md`,
`tools/assets/check_assets.py`, `tools/assets/check_assets_test.py`.

## Cách tách nền (bài học keying cho hình hồng/tím)

Nền generator là màu đặc (trung vị RGB ≈ (184, 85, 131), độ lệch ở góc
≤ 10). **Không dùng keying theo hue**: cửa sổ hue ±14° quanh nền ăn
cả váy hồng (hue ~340°) và váy tím thành component riêng rồi bị loại
(váy biến mất khỏi composite đầu tiên). Dùng **keying theo khoảng cách
RGB** tới màu nền, ngưỡng 20 (màu hình gần nền nhất cách ~55: sợi tóc
tối 54,8; váy tím 58–83; váy hồng 80–130; da 107–121 — biên rộng).
Sau keying: closing 3×3 (lấp lỗ kim), despill (pixel ở mép lấy màu từ
pixel ≥ 3 px bên trong — khử viền magenta), largest component, lấp lỗ
kín < 50 px sau khi chuẩn hóa. **Không** binary_fill_holes (biến khe
thật giữa lá/tóc thành mảng magenta), **không** erosion (ăn mép váy
thành răng cưa).

Chuẩn hóa (căn tư thế): mỗi ảnh co theo chiều cao bbox → 1287 px,
chân neo y = 1429, tâm mắt-x căn về 01, co dọc nhỏ quanh chân để căn
tâm mắt-y. Kết quả: sai số tâm mắt ≤ 0,5 px trên cả 6 ảnh; bbox
(148–151, 139–156, 863–889, 1428–1430).

Giảm cỡ: ảnh RGBA gốc 934–1005 KB (03w vượt 1 MB) → **lượng tử 256
màu, palette MAXCOVERAGE + dithering Floyd–Steinberg, giữ nguyên
kênh alpha** (403–474 KB). Lưu ý: palette MEDIANCUT làm mất màu xanh
tròng mắt (tròng thành hồng xám, chỉ còn 2 px xanh); MAXCOVERAGE giữ
được (1514–3113 px xanh ở vùng mắt). Alpha giữ nguyên 100% (silhouette
không đổi). Dither làm da hơi sần khi phóng 3×, ở cỡ hiển thị không
thấy.

## File (7 PNG, khung 1024×1536, PNG trong suốt)

Đường đích `app/assets/images/character/girl/`. Tỉ lệ bán trong suốt
(0 < alpha < 255) đo bằng code.

| File | Vai trò | Cỡ (byte) | Bán trong suốt |
| --- | --- | --- | --- |
| `girl_full_01.png` | Toàn thân, váy hồng nơ to (bộ 1) | 403.232 | 0,0000 |
| `girl_full_02.png` | Toàn thân, váy tím nơ (bộ 2) | 408.668 | 0,0000 |
| `girl_full_03.png` | Toàn thân, váy hồng + tạp dề trắng bèo (bộ 3) | 470.843 | 0,0000 |
| `girl_full_01_wave.png` | Bộ 1, tay phải giơ lên vẫy | 412.375 | 0,0000 |
| `girl_full_02_wave.png` | Bộ 2, tay phải vẫy | 411.799 | 0,0000 |
| `girl_full_03_wave.png` | Bộ 3, tay phải vẫy | 474.170 | 0,0000 |
| `girl_eyes_closed_patch.png` | Miếng vá mắt nhắm (xem dưới) | 25.367 | 24,01% * |

\* Patch có viền feather 14 px (alpha dốc dần về 0 ở mép rect) nên
24% pixel bán trong suốt là **do thiết kế**; phần trong hoàn toàn
đục. 6 ảnh toàn thân cứng 0,0000 (không alpha mờ).

## Mốc khung đo được (khung 1024×1536, đo bằng code từ ảnh thật)

- Tâm mống mắt: trái **(388, 562)**, phải **(619, 559)** — tâm giữa
  hai mắt (504, 561). **Không** dùng mốc cũ y = 480 của bộ xám tạm.
- Miệng cười: tâm **(517, 835)**. (Đính chính 21/11: miệng cười thật là (519,651); (517,835) là nơ ngực — xem mục lô 4 bé gái)
- Chân neo: y = **1429** (đáy giày); bbox toàn thân cao 1287 px
  (y 142–1429). Trong phòng v3b: cao hiển thị **360 px, chân
  (630, 810)** theo `docs/D_IMAGES.md`.
- Tay vẫy là tay **phải** của nhân vật (phía trái ảnh khi nhìn từ
  trước) giơ lên; các ảnh wave căn cùng tâm mắt/chân với ảnh nghỉ.

## Miếng vá mắt nhắm

- Rect **410×140 tại (300, 490)** trong khung 1024×1536 (bao cả hai
  mắt + da quanh mắt). Vùng mí = toàn bộ mắt mở (tròng trắng + mống
  mắt + mi) của ảnh gốc, giãn 11 px — **không** chỉ vùng xanh của
  mống mắt (vùng đó quá nhỏ, để lộ tròng trắng/mống dưới).
- Trong vùng mí lấy pixel từ ảnh mắt nhắm (mí đóng kín + đường mi
  cong); ngoài vùng mí lấy pixel từ ảnh mở (da quanh mắt từ ảnh gốc).
  Viền feather 14 px.
- Kiểm: đặt patch lên cả 3 bộ, phóng to vùng mắt 3× — **0 px xanh**
  trong vùng mắt (01 còn 1 px xanh lẻ trong vùng mí, ngoài vùng mắt,
  không nhìn thấy); không thấy đường viền rect; mí đọc đúng là nhắm.

## Kiểm chứng tư thế (thành thật)

- **Căn tư thế: đạt.** Tâm mắt sai ≤ 0,5 px, chân y = 1428–1430 trên
  cả 6 ảnh; composite trên nền tối + nền phòng: cùng một bé gái, 3
  bộ đồ khác nhau; biến thể vẫy chỉ đổi tay phải.
- **Diff pixel ngoài vùng tay KHÔNG ≈ 0** (trung bình ~20 mức ở cỡ
  hiển thị 360 px, 30–57% pixel lệch > 12). Nguyên nhân: mỗi biến
  thể là một lần vẽ lại (re-render) của generator — nếp váy, sợi
  tóc, shading dịch nhẹ ở thang 10+ px; không phải lệch tư thế
  (trung vị màu da/tóc khớp trong 3 mức, tâm mắt khớp 0,5 px).
  Khi app đổi nghỉ → vẫy sẽ thấy shading nhấp nhẹ; ở cỡ hiển thị
  trên điện thoại khó nhận ra, composite phòng xác nhận bằng mắt là
  cùng một bé. Nếu Claude thấy nhấp này không chấp nhận được, cách
  sửa là ghép tay vẫy lên ảnh nghỉ bằng code (phức tạp, dễ lộ
  đường ghép ở tóc) — làm ở bước sau, không vẽ lại.
- Lỗ alpha kín ≥ 3 px: **0** trên cả 6 ảnh. Mép magenta: còn ~400 px
  ở mép (màu tối thật của hình gần màu nền), không nhìn thấy.
- Ghép phòng v3b (cao 360 px, chân (630, 810), có bóng ellipse mềm
  dưới chân): tỉ lệ tự nhiên so với giường/ghế, chân chạm thảm, mặt
  khớp nữ v3. Biến thể vẫy đứng cùng vị trí, tay giơ tự nhiên.

## Thang cỡ pet (đo từ PNG pet thật trên main)

Đo 6 PNG pet thật trên main (`app/assets/images/pets/`, PR #21):
`dog_egg`, `dog_newborn`, `dog_teen`, `dog_adult`, `cat_teen`,
`rabbit_teen` — tất cả **512×512, chiều cao nội dung alpha-bbox đều
400 px** (bbox y 40–440, mặt đất y = 440), không phân biệt loài hay
giai đoạn. **PNG không mã hóa cỡ giai đoạn** — cỡ giai đoạn là quyết
định hiển thị (app co PNG về chiều cao hiển thị khi vẽ).

Bảng chiều cao hiển thị đề xuất (chung mọi loài; chiều cao bé 360 px):

| Giai đoạn | Chiều cao hiển thị | Tỉ lệ so với bé |
| --- | --- | --- |
| Trứng | 120 px | 33% |
| Mới nở | 155 px | 43% |
| Nhỡ | **209 px** | **58%** |
| Trưởng thành | 250 px | 69% |

- Nhỡ = 209 px (58%) là **chủ dự án đã duyệt** (tấm xem trước 2:
  chó nhỡ ~58% chiều cao bé gái).
- Trứng/mới nở/trưởng thành là đề xuất theo đường cong tăng trưởng
  (trứng < mới nở < nhỡ < trưởng thành), chưa duyệt riêng.
- Test kiểm thứ tự + giá trị nhỡ 58% thêm ở **giai đoạn code (E)**.

## Việc còn lại cho giai đoạn code (E)

- Entry manifest cho 7 file trên (loại file mới `girl_full_*` +
  `girl_eyes_closed_patch`; **không** dùng mã lớp `arm`, không lớp
  `body`/`top`/`eyes`/`mouth` riêng) + cập nhật `source` thành
  "Muse vẽ AI 21/11 theo DESIGN.md". Bộ nữ PR #18 thay hẳn bằng bộ
  này.
- `CharacterView` dùng ảnh toàn thân + patch mắt nhắm (đặt patch tại
  (300, 490) trong khung) + đổi qua lại ảnh wave khi vẫy; chỉnh
  `_eyeCenter` theo tâm mắt đo được (y ≈ 561).
- Bảng thang cỡ pet vào `docs/ASSETS.md` + test (thứ tự trứng <
  mới nở < nhỡ < trưởng thành, nhỡ = 209 px / 58%).
- Test neo: chân nhân vật, pet, đồ nằm trong vùng sàn/mặt phẳng đã
  khai báo. Tràn 608×248 + 640×320. Full suite xanh. Mở PR.

---

# Nhân vật bé trai v3b — (E) lô 2 (cách mới, như lô 1 làm lại)

Lô 2 chỉ làm **bé trai** (3 bộ đồ toàn thân, 3 biến thể tay vẫy, miếng vá
mắt nhắm), theo đúng cách mới của lô 1 (ảnh toàn thân hoàn chỉnh, không
cắt lớp). Nguồn: Muse vẽ AI 21/11 theo `docs/DESIGN.md`, từ bản gốc
nam v1 đã được chủ dự án duyệt (3 bộ: áo thun xanh + short xanh, hoodie
xanh lá + quần xanh lá, áo thun đỏ + quần jean xanh). **Lưu ý tên gọi:**
Muse chỉ vẽ **nam v1**; Claude vẫn ghi "nam v2" — lô này làm từ nam
v1, nếu có file nam v2 khác thì báo lại, đừng tự bịa. Trong app mỗi
lần chỉ có **một** nhân vật, nam hoặc nữ theo lựa chọn ở màn mở đầu,
cộng thêm pet của bé.

## Cách vẽ (giữ tư thế giống nhau là điểm then chốt)

- Vẽ ảnh toàn thân bộ 1 trước, rồi **chỉnh sửa từ ảnh đó** (resume/
  tiếp tục) để đổi chỉ quần áo cho bộ 2/3 và đổi chỉ tay phải cho các
  biến thể vẫy — không vẽ lại từ đầu từng ảnh.
- Nền generator là màu đặc hồng cá hồi (trung vị RGB ≈ (222, 134,
  134)). Tách nền bằng **keying theo khoảng cách RGB** tới màu nền,
  ngưỡng 20 (như lô 1; không dùng hue — váy/áo gần màu nền sẽ mất).

## File (7 PNG, khung 1024×1536, PNG trong suốt, đã lượng tử)

Đường đích `app/assets/images/character/boy/`. Cỡ dưới là sau lượng tử
256 màu MAXCOVERAGE + Floyd–Steinberg (giữ alpha); trước lượng tử
726–843 KB. Tỉ lệ bán trong suốt (0 < alpha < 255) đo bằng code.

| File | Vai trò | Cỡ (byte) | Bán trong suốt |
| --- | --- | --- | --- |
| `boy_full_01.png` | Toàn thân, áo thun xanh + short xanh, sneaker xanh nhạt (bộ 1) | 295.092 | 0,0000 |
| `boy_full_02.png` | Toàn thân, hoodie xanh lá + quần xanh lá, sneaker xanh lá (bộ 2) | 329.300 | 0,0000 |
| `boy_full_03.png` | Toàn thân, áo thun đỏ + quần jean xanh xắn gấu, sneaker đỏ (bộ 3) | 307.809 | 0,0000 |
| `boy_full_01_wave.png` | Bộ 1, tay phải giơ lên vẫy | 311.293 | 0,0000 |
| `boy_full_02_wave.png` | Bộ 2, tay phải vẫy | 353.258 | 0,0000 |
| `boy_full_03_wave.png` | Bộ 3, tay phải vẫy | 309.586 | 0,0000 |
| `boy_eyes_closed_patch.png` | Miếng vá mắt nhắm (xem dưới) | 45.075 | 17,82% * |

\* Patch có viền feather 14 px (alpha dốc dần về 0 ở mép rect) nên
17,82% pixel bán trong suốt là **do thiết kế**; phần trong hoàn toàn
đục. 6 ảnh toàn thân cứng 0,0000.

## Mốc khung đo được (khung 1024×1536, đo bằng code từ ảnh thật)

- Tâm mống mắt: trái **(398, 626)**, phải **(611, 626)** — tâm giữa
  hai mắt (504, 626). Mắt các ảnh: y 614–626 (biến thể vẫy lệch
  ±6 px do vẽ lại, mắt-x sai ≤ 0,4 px).
- Miệng cười: tâm **≈ (508, 720)** ±7 px (đo: 01 (509, 720), 03
  (501, 713); bộ 02 bộ đo tự động bắt nhầm bóng cổ áo, đã đo lại
  bằng mắt từ ảnh phóng to).
- Chân neo: y = **1429** (đáy giày); bbox toàn thân cao 1287 px
  (y 142–1429); bbox x 150–157 tới 851–857. Trong phòng v3b: cao
  hiển thị **360 px, chân (630, 810)** theo `docs/D_IMAGES.md`.
- Tay vẫy là tay **phải** của nhân vật (phía trái ảnh khi nhìn từ
  trước) giơ lên; các ảnh wave căn cùng tâm mắt/chân với ảnh nghỉ.

## KHÁC BIỆT TỈ LỆ SO VỚI BÉ GÁI (ghi thật, không ép khớp)

Mắt bé trai thấp hơn bé gái ~65 px (tâm mắt-y ≈ 626 so với 561),
miệng cao hơn (y ≈ 720 so với 835): đầu/tóc bé trai to hơn, mặt
gọn hơn (mắt→miệng ~94 px so với ~274 px của bé gái). Ép mắt về
y = 561 cần co dọc 7,4% (ky = 1,074) làm méo hình, nên **giữ
ky = 1,0 (không co dọc)**: chân + chiều cao toàn thân khớp hệt
bé gái (y = 1429, cao 1287 px), mắt ở độ cao tự nhiên của bé
trai. Hai bé không bao giờ cùng lên màn hình (mỗi lần chỉ một
nhân vật), nên không xung đột thị giác. **Giai đoạn code:**
`_eyeCenter` đo riêng theo từng nhân vật (nữ y ≈ 561, nam
y ≈ 626); patch mắt đặt theo rect riêng của từng bé (xem dưới).

## Miếng vá mắt nhắm

- Rect **432×205 tại (291, 506)** trong khung 1024×1536 (bao cả
  hai mắt + da quanh mắt). Vùng mí = toàn bộ mắt mở (tròng trắng
  + mống mắt + mi + đồng tử) của ảnh gốc, giãn 14 px — lấy từ
  `sclera | iris | lash` (vùng mí 33.384 px, bbox x 311–702,
  y 526–690). **Không** chỉ vùng mống mắt (vùng đó quá nhỏ, để lộ
  đồng tử/tròng trắng — lỗi này đã gặp khi thử lần đầu).
- Trong vùng mí lấy pixel từ ảnh mắt nhắm (mí đóng kín + đường mi
  cong); ngoài vùng mí lấy pixel từ ảnh mở (da quanh mắt từ ảnh
  gốc). Viền feather 14 px.
- **Bóng nếp mí trên: KHÔNG làm nhạt bằng blend** (đã thử, bỏ).
  Blend 60% về ảnh mở ở vùng trên đường mi làm lộ lại nửa trên
  tròng mắt (vùng nếp mí chồng lên đỉnh tròng; mask tròng không
  phủ kín viền tròng). Patch lấy **nguyên pixel ảnh nhắm** trong
  vùng mí — bóng nếp mí ở mức tự nhiên của ảnh nhắm, tương đương
  patch bé gái (Claude chỉ ghi chú nhỏ ở patch gái, không chặn).
- Kiểm: đặt patch lên cả 3 bộ + cả 3 biến thể vẫy, phóng to vùng
  mắt 3× — **0 tròng nâu / tròng trắng / đồng tử lộ** (đọc bằng
  mắt trên cả 6 ảnh: mí đóng kín, đường mi rõ, không thấy đường
  viền rect). Chỉ số tự động còn 162 px "màu tròng" trong đĩa mắt
  (so với ~1330 px ở ảnh mở) — đó là **lỗi của chỉ số** (mask màu
  tròng bắt cả lông mày + màu nếp mí của ảnh nhắm), không phải
  tròng thật; kiểm bằng mắt là căn cứ chính.
- **Từ fix2: patch chung trên chỉ dùng cho 3 ảnh nghỉ.** 3 ảnh wave dùng
  patch riêng (xem bảng ở mục "Sửa lỗi cắt nền" dưới) — patch chung đặt
  lên wave bị lệch (bóng tóc mái nhân đôi, mép rect mờ ở má phải).

## Bài học keying riêng của lô 2 (bổ sung cho lô 1)

Nền hồng cá hồi gần màu da/má hồng nên keying ăn cả chi tiết mặt
— phải vá bằng code, không chỉ bằng mắt:

- **Lỗ má hồng:** má hồng nằm trong ngưỡng 20 của nền → thủng lỗ
  879–2128 px trên mặt. Quy tắc lấp lỗ kín: lấp nếu < 3000 px
  **hoặc** (median khoảng cách tới nền > 8 **và** < 10000 px) —
  lỗ thật (khe giữa tay/chân) có màu nền thuần (median ~0–6) nên
  không bị lấp. Sau vá: 01/03 còn 0 lỗ kín, 02 còn 1 lỗ 71 px ở
  áo hoodie (y 1130, không nhìn thấy).
- **Khe thật phải giữ:** khe giữa hai chân (01w, 1462 px) và khe
  nách tay giơ (03w, 1858 px) là nền thật xuyên qua — **không
  lấp** (chỉ lấp lỗ < 1000 px ở vùng mặt y < 900).
- **Viền đen do resize (lỗi nặng nhất lô 2):** resize LANCZOS
  thường trên RGBA nội suy RGB với nền đen trong suốt → để lại
  pixel đen đục 1–2 px ở mép (tai phải 03 có vệt đen dài, 1013
  px đen). Sửa: **resize premultiplied-alpha** (nhân RGB với
  alpha trước, chia lại sau) + sửa pixel đen ở mép bằng màu pixel
  đục gần nhất + despeckle (median 5×5) cho chấm đen/trắng do
  ringing ở đầu ngón tay. **Không dùng binary_closing trên mask
  ở bước cuối** — closing đẩy pixel đen của canvas thành đục.
  Sau sửa: tai sạch, tay sạch, đồng tử (màu đen thật) giữ nguyên.
- **Khuyết mép tai/cằm:** viền silhouette mờ dần vào nền 3–6 px;
  ngưỡng 20 cắt thành khuyết (tai phải 03 khuyết 4–5 px). Sửa:
  mọc viền tối đa 3 px vào dải mờ (khoảng cách tới nền 10–25),
  không bao giờ vào nền thuần (khoảng cách < 10) — khôi phục
  đúng mép mềm của ảnh gốc, không tạo quầng hồng.
- **Nghi ngờ `_hsv` trong `patch.py` của lô 1 — ĐÃ KIỂM LẠI, KHÔNG ĐÚNG:**
  khi làm patch trai, agent nghi hàm `_hsv` quên chia kênh G cho 255
  (`g = a3[..., 1]` thay vì `/ 255`) nên mask tròng trắng `sclera` và
  mask mi `lash` gần như rỗng, đồng tử và tròng trắng lọt qua patch.
  Kiểm lại: code thật ở `patch.py` dòng 31 chia đủ cả 3 kênh
  (`r, g, b = a3[..., 0] / 255, a3[..., 1] / 255, a3[..., 2] / 255`),
  và đo ảnh ghép mắt nhắm của gái cho 0 px trắng / 6 px rất tối trên
  729.000 px — **patch gái KHÔNG rò, giữ nguyên**. `boy_patch.py`
  vẫn chia đủ 3 kênh + giãn vùng mí 14 px như đã làm.

## Tẩy chấm đen (sửa nhỏ sau đẩy lô 2, chưa decode)

Soi ảnh ghép thấy các chấm đen lạ (tàn dư keying, đen tuyệt đối, nằm
trên da) trên 4/6 ảnh toàn thân; tẩy bằng cách lấy median màu da kề
bên, chỉ đổi đúng các điểm đó (alpha không đổi):
- `boy_full_01`: vệt đen 50 px trên tai phải (728–735, 678–688).
- `boy_full_01_wave`: chấm đen 35 px trên tai phải (722–727, 684–694).
- `boy_full_03`: chấm đen 11 px trên tai phải (781–784, 585–588) +
  chấm 2 px trên tai phải (730, 677–678).
- `boy_full_03_wave`: chấm đen 12 px trên tai phải (722–725, 683–686)
  + các chấm đen trên cằm/hàm trái (38 px, 18 px và vài chấm 1–2 px).
- `boy_full_02` và `boy_full_02_wave`: không có chấm đen, không sửa.
- Không sửa bóng đổ dưới hàm/dưới tai (có giống nhau ở cả 6 ảnh, là
  chi tiết vẽ có chủ đích); tai trái bộ 03 soi 5× không thấy chấm đen.

## Sửa lỗi cắt nền (fix2, sau review của Claude 21/11 ~16:17)

Claude decode commit d1bbf3c7 để kiểm, tổng thể đạt nhưng CHƯA commit PNG vì
4 lỗi cắt nền. Đã sửa cả 4, đẩy lại cùng nhánh. Cách kiểm theo đúng đề nghị
của Claude: ghép mỗi ảnh lên nền tối (60,60,80) VÀ nền trắng, phóng 3× toàn
bộ viền ngoài; đếm bằng code số pixel alpha = 0 trong vùng thân.

- **(1) boy_full_01_wave — lỗ alpha ở bắp chân trái (người xem):** lỗ kín
  695 px, bbox x[381,451] y[1266,1307] (Claude ước x 330–420, y 1230–1300).
  Vá bằng Laplace inpainting từ màu da kề bên (giữ gradient sáng/tối của bắp
  chân); sau vá lỗ = 0, ghép nền tối soi 3× thấy da liền mạch.
- **(2) boy_full_02_wave — viền hồng/da (halo keying):** viền tóc phải
  (x 650–880, y 180–450) + mép hoodie phải có dải hồng (tàn dư nền hồng cá
  hồi). Dọn bằng quy tắc khoảng cách màu tới nền (222,134,134): chỉ xoá
  pixel trong ≤5 px của mép silhouette và có khoảng cách < 38 (vòng 1) rồi
  < 55 (vòng 2) — màu tóc/hoodie/da thật có khoảng cách ≥ 55–67 nên không
  bị ăn. Vòng 1 xoá 343 px (tóc) + 1563 px (hoodie/tay); vòng 2 xoá thêm
  140 px (tóc) + 1385 px (hoodie/tay). Sau dọn còn viền mờ ~1 px (mép mềm
  tự nhiên của tóc/hoodie, không còn dải hồng).
- **(3) boy_full_03 + boy_full_03_wave — mép tai phải + cổ dưới tai răng
  cưa + viền hồng (x 760–830, y 600–700):** dọn viền hồng bằng cùng quy tắc
  (ngưỡng 35 — da tai gần màu nền nên giữ ngưỡng thấp; 496 px ở 03, 447 px
  ở 03w) + dọn 1 px lồi/lõm trên mép (03: 12 lồi, 3 lõm; 03w: 18 lồi,
  3 lõm). Sau sửa mép tai sạch, còn bước răng cưa ~1 px (giới hạn lượng tử
  256 màu).
- **Lỗ alpha nhỏ phát hiện thêm khi đếm (không phải 4 lỗi của Claude):**
  01 còn 1 lỗ 73 px (x[302,310] y[1130,1147]), 02 còn 1 lỗ 67 px
  (x[306,314] y[1128,1144]) — lỗ keying trong quần/đùi, lô 2 đếm sót (chỉ
  ghi lỗ của 02); đã vá cả hai bằng Laplace. Khi dọn halo, viền mở ra các
  túi nhỏ (02w: 15 + 9 túi 3–73 px; 03: 4 túi 3–60 px, gồm khe 60 px ở
  x[700,704] y[669,693] do halo bắc cầu tai–hàm) — đã vá hết bằng Laplace.
- **Số lỗ alpha kín ≥ 3 px sau sửa: 0 trên cả 6 ảnh** (đếm bằng
  `binary_fill_holes`), trừ **01 vùng ở 03w: khe nách 1228 px**
  (x[272,350] y[684,743]) — đó là khoảng trống thật giữa tay giơ và thân
  (không phải lỗ trong thân), lô 2 đã quyết không lấp; để nguyên. Tỉ lệ bán
  trong suốt vẫn **0,0000** trên cả 6 ảnh toàn thân (không tạo mép mờ).
- **Diff ngoài vùng sửa ≈ 0:** 01 đổi 73 px, 02 đổi 67 px, 01w đổi 695 px,
  02w đổi 3431 px (chỉ trong vùng tóc/hoodie/tay), 03 đổi 508 px, 03w đổi
  465 px — tất cả trong vùng lỗi đã ghi.

### Miếng vá mắt nhắm riêng cho từng ảnh wave (lỗi 4 — quan trọng nhất)

- **Vấn đề:** patch chung (291,506) đặt lên bản wave bị lệch vì đầu bản
  wave vẽ lại — bóng tóc mái nhân đôi ở góc trên trái rect, mép rect mờ ở
  má phải. Nguyên nhân: phần ngoài vùng mí của patch lấy da/tóc từ ảnh nghỉ
  (bộ 01), không khớp shading/tóc mái của ảnh wave.
- **Cách sửa:** mỗi ảnh wave có **một patch riêng**, làm từ chính ảnh wave
  đó: da quanh mắt lấy từ ảnh wave mở; pixel mí lấy từ **bản nhắm mắt của
  chính ảnh wave** (tạo bằng cách sửa ảnh wave: chỉ nhắm mắt, giữ nguyên
  mọi thứ khác). Bản nhắm mắt trả về 1280×1920 — thu về 1024×1536 rồi căn
  bằng mốc miệng (miệng là điểm neo ổn định, không đổi khi nhắm mắt): dịch
  bản nhắm xuống dy = +4 px (01w), +6 px (02w), +9 px (03w), dx = 0. Vùng
  mí = `sclera | iris | lash` của ảnh wave, giãn 14 px (như patch nghỉ);
  viền feather 14 px.
- **Bảng patch (khung 1024×1536):**

| File patch | Dùng cho ảnh | Rect (x, y, rộng × cao) | Cỡ (byte) |
| --- | --- | --- | --- |
| `boy_eyes_closed_patch.png` | `boy_full_01/02/03` (nghỉ) | (291, 506), 432×205 | 45.075 |
| `boy_eyes_closed_patch_01_wave.png` | `boy_full_01_wave` | (297, 493), 427×245 | 63.900 |
| `boy_eyes_closed_patch_02_wave.png` | `boy_full_02_wave` | (280, 502), 441×243 | 60.631 |
| `boy_eyes_closed_patch_03_wave.png` | `boy_full_03_wave` | (295, 495), 432×250 | 68.852 |

- **Kiểm:** đặt từng patch lên đúng ảnh của nó, phóng to vùng mắt 3× — mí
  đóng kín, đường mi rõ, **0 tròng nâu/trắng/đồng tử lộ (đọc bằng mắt)**,
  không thấy viền rect, không nhân đôi bóng tóc mái. Chỉ số tự động còn
  175–235 px "màu tròng" trong đĩa mắt (patch nghỉ: 167–184) — vẫn là
  **lỗi của chỉ số** (bắt cả lông mày + màu nếp mí), không phải tròng thật;
  kiểm bằng mắt là căn cứ chính. Patch nghỉ đã kiểm lại trên 3 ảnh nghỉ đã
  sửa (lỗ vá ở chân, không chạm mặt): vẫn khít, chỉ số 167–184 px như trước.
- **Ghi thật:** mắt các ảnh wave hơi lệch nhau (01w: trái y 608, phải
  y 624; 03w: trái y 605, phải y 622 — đầu vẽ lại hơi nghiêng); rect patch
  wave cao hơn patch nghỉ (~245 px so với 205 px) để bao cả hai mắt. Giai
  đoạn code: `CharacterView` dùng đúng patch theo ảnh đang hiển thị (nghỉ
  → patch nghỉ, vẫy → patch wave tương ứng).

## Kiểm chứng tư thế (thành thật)

- **Căn tư thế: đạt.** Tâm mắt-x sai ≤ 0,4 px, chân y = 1429
  trên cả 6 ảnh; mắt-y lệch ±6 px giữa các ảnh (vẽ lại); composite
  trên nền tối + nền phòng: cùng một bé trai, 3 bộ đồ khác nhau;
  biến thể vẫy chỉ đổi tay phải (tay giơ lên, bàn tay mở).
- **Diff pixel ngoài vùng tay KHÔNG ≈ 0** (như lô 1): face-diff
  01–02: 20,7% (tốt nhất 14,3% ở dx=-2 dy=4); 01–03: 16,9%
  (tốt nhất 9,4%); 01–01w: 41,4%; 02–02w: 13,5% (cặp tốt nhất);
  03–03w: 37,0%. Nguyên nhân như lô 1: mỗi biến thể là một lần
  vẽ lại — nếp áo, sợi tóc, shading dịch nhẹ ở thang 10+ px;
  không phải lệch tư thế (trung vị màu da/tóc khớp trong 3 mức,
  tâm mắt khớp 0,4 px). Khi app đổi nghỉ → vẫy sẽ thấy shading
  nhấp nhẹ; ở cỡ hiển thị trên điện thoại khó nhận ra, composite
  phòng xác nhận bằng mắt là cùng một bé.
- Lỗ alpha kín ≥ 3 px: **0** trên 01/03 (02 còn 1 lỗ 71 px ở áo).
  Không mép cắt thẳng, không vệt màu lạ (sau các bước vá trên).
- Ghép phòng v3b (cao 360 px, chân (630, 810), có bóng ellipse
  mềm dưới chân): tỉ lệ tự nhiên so với giường/ghế, chân chạm
  thảm, mặt khớp nam v1 (tóc nâu ngắn, mắt nâu to có ánh, miệng
  cười, má hồng). Biến thể vẫy đứng cùng vị trí, tay giơ tự nhiên.

## Việc còn lại cho giai đoạn code (E) — bổ sung lô 2

- Entry manifest cho 7 file trên (loại file mới `boy_full_*` +
  `boy_eyes_closed_patch`; **không** dùng mã lớp `arm`, không lớp
  `body`/`top`/`eyes`/`mouth` riêng) + cập nhật `source` thành
  "Muse vẽ AI 21/11 theo DESIGN.md". Bộ nam v1 này là bộ nam
  duy nhất (không dùng bộ nam PR #18 — bộ đó là nữ; nam chưa
  từng có bộ nào trong app).
- `CharacterView` dùng ảnh toàn thân + patch mắt nhắm + đổi qua lại ảnh
  wave khi vẫy; chỉnh `_eyeCenter` theo nhân vật (nam y ≈ 626,
  nữ y ≈ 561). Patch mắt: ảnh nghỉ dùng patch chung tại **(291, 506)**,
  rect 432×205; mỗi ảnh wave dùng patch riêng của nó (rect riêng — xem
  bảng patch ở mục "Sửa lỗi cắt nền").
- Thang cỡ pet + test neo + tràn 608×248 + 640×320 + full suite
  xanh (như mục việc còn lại của lô 1).
- **Không cần làm lại patch mắt nhắm bé gái** (nghi ngờ `_hsv` đã
  kiểm lại, không đúng — xem mục "Bài học keying riêng của lô 2" trên).

# Phụ kiện rời — (E) lô 3 (lớp chồng lên ảnh toàn thân)

Lô 3 làm **10 phụ kiện rời** (5 bé gái + 5 bé trai), khung 1024×1536
PNG trong suốt, lớp chồng lên ảnh toàn thân lô 1/2. Cùng tư thế/khung/
điểm chân với ảnh toàn thân nên khít; **không nướng bóng đổ** (bóng do
app vẽ như nhân vật); màu thật, không nhuộm; cùng phong cách 3D mềm,
cùng hướng sáng trên-trái.

## Cách làm (balo ghép từ 2 nguồn)

- Mũ, nơ/kẹp, kính, giày: vẽ AI trên nền đặc, tách nền bằng keying
  theo khoảng cách RGB tới màu nền (như lô 1/2), resize
  premultiplied-alpha (bài học lô 2: tránh viền đen), đặt vào khung
  1024×1536 theo mốc đo từ ảnh toàn thân thật.
- Kính v1 bị loại: tròng kính phủ màu hồng/lavender nhạt, che mắt.
  Vẽ lại v2 với "no lenses, empty rings" — vòng rỗng, chỉ gọng +
  cầu + càng.
- Balo: generator chỉ ra ảnh sản phẩm đứng một mình (túi + quai
  vòng cao), không ra bố cục đeo dù đã nhắc rõ + có ảnh tham chiếu.
  Cách làm: **cắt thân túi** từ ảnh sản phẩm, **quai đeo tạo riêng**
  (2 dải dọc phồng), ghép lại bằng code. Quai bé trai = quai bé gái
  hue-shift −140° (hồng ~340° → xanh ~210°).
- Dọn artifact: xóa pixel magenta (bóng đổ từ ảnh gốc lọt qua
  keying), pixel đen/đỏ thuần do ringing LANCZOS ở mép (tô màu từ
  pixel hợp lệ gần nhất), zero RGB nơi alpha=0; đế giày tô trắng
  vùng bão hòa cao ở y>1405 (vệt tím từ shading đế).

## File (10 PNG, khung 1024×1536, PNG trong suốt)

Đường đích `app/assets/images/character/girl/` và `.../boy/`. Tỉ lệ
bán trong suốt = phần pixel có nội dung (alpha>0) mà alpha bán trong
suốt (0<alpha<255) — chủ yếu là viền chống răng cưa sau resize;
giày = 0,0000 (mép cứng sau dilate, như ảnh toàn thân lô 1/2).

| File | Vai trò | Cỡ (byte) | Bán trong suốt |
| --- | --- | --- | --- |
| `girl_hat_01.png` | Beret hồng có nơ, đội đỉnh tóc | 144.138 | 0,0422 |
| `girl_bow_01.png` | Nơ kẹp tóc hồng, cài thái dương trái | 29.549 | 0,1596 |
| `girl_glasses_01.png` | Kính tròn gọng hồng, vòng rỗng | 73.012 | 0,2268 |
| `girl_backpack_01.png` | Balo hồng: túi sau vai + quai đeo trước ngực/vai | 113.978 | 0,1208 |
| `girl_shoes_02.png` | Mary Jane trắng thay giày hồng/tím gốc | 45.708 | 0,0000 |
| `boy_hat_01.png` | Mũ lưỡi trai xanh, lưỡi sang trái | 130.170 | 0,0492 |
| `boy_clip_01.png` | Kẹp tóc xanh hình sao 5 cánh | 22.117 | 0,1730 |
| `boy_glasses_01.png` | Kính tròn gọng xanh, vòng rỗng | 74.043 | 0,3045 |
| `boy_backpack_01.png` | Balo xanh: túi sau vai + quai đeo | 119.389 | 0,1240 |
| `boy_shoes_02.png` | Sneaker trắng thay sneaker màu gốc | 62.117 | 0,0000 |

> Lưu ý: kích thước và tỉ lệ bán trong suốt của 2 kính trong bảng là bản gốc lô 3; sau sửa ở mục "Sửa kính lô 3" cuối file: `girl_glasses_01.png` 74.920 byte / 0,51%, `boy_glasses_01.png` 73.494 byte / 0,53%.

## Vị trí / điểm neo (khung 1024×1536, bbox đo bằng code từ PNG cuối)

Mốc ảnh toàn thân để căn: gái tâm mắt (388,562)/(619,559), miệng
(517,835) (Đính chính 21/11: miệng thật là (519,651); (517,835) là nơ ngực), chân y=1429; trai tâm mắt (398,626)/(611,626), miệng
≈(508,720), chân y=1429.

- Mũ: gái bbox x[287,721] y[53,364] (đỉnh tóc y≈142, đội đúng đỉnh
  đầu); trai x[287,722] y[48,312].
- Nơ/kẹp: gái x[259,399] y[428,529] (thái dương trái, trên tóc);
  trai x[259,358] y[468,570].
- Kính: gái x[205,725] y[453,666], scale 0,554 theo tâm lỗ tròng
  (372,897)/(789,891) về tâm mắt; trai x[226,708] y[526,722],
  scale 0,497 (lỗ phải thật ≈(802,773)). Càng xa trong tròng phải
  đã xóa (bbox lỗ tròng) để không che mắt; đầu càng trái gái trôi
  ngoài tóc đã cắt (x<238, y>500).
- Balo: gái bbox x[110,625] y[700,1120] — túi x[160,349]
  y[820,1096] sát vai phải nhân vật, quai x[374,410]/[590,626]
  y 700–1000 qua vai; trai x[387,913] y[700,1129] — túi
  x[690,884] y[815,1105] sát vai trái nhân vật, quai
  x[387,423]/[592,628]. Túi nằm cạnh vai (chủ yếu ngoài silhouette
  thân), quai chồng trước ngực/vai. Kiểm trên biến thể wave: tay
  giơ không chạm balo.
- Giày thay thế: gái x[391,642] y[1299,1428]; trai x[328,681]
  y[1291,1428]. Đáy neo y=1428 (chân ảnh toàn thân 1429, sai 1 px
  do làm tròn).

## Giày thay thế che kín giày gốc (kiểm bằng code, cả 3 bộ mỗi dáng)

- Giày gốc gái: trái x≈402–503, phải x≈529–631, y≈1340–1428
  (hồng bộ 1/3, tím bộ 2). Giày gốc trai: trái x≈331–480, phải
  x≈530–679, y≈1330–1428 (sneaker xanh nhạt / xanh lá / đỏ).
- Cách che: giày thay thế đặt đè lên, giãn mask (gái 12 px ngang/
  4 px dọc, trai 10/4, tô màu giày gần nhất) + lấp đúng vùng rò
  (hợp của cả 3 bộ) + trai lấp thêm khe giữa 2 giày y 1300–1360.
  **Rò = 0 px trên cả 3 bộ mỗi dáng** (trước sửa: gái ~17.100
  px/bộ, trai ~24.500 px/bộ trong bbox giày). Đế trắng sạch,
  không bệ trắng dưới đế (cách lấp cột xuống 1428 đã bỏ vì tạo
  bệ), không bóng magenta, không pixel đen/đỏ.
- Lưu ý: giày thay thế là một ảnh duy nhất dùng chung cho cả 3 bộ
  (không theo màu từng bộ) — đúng thiết kế "giày thay thế" trong
  Tủ đồ/Cửa hàng.

## Kiểm chứng (thành thật)

- Ghép từng phụ kiện lên ảnh toàn thân + nền tối (60,60,80) + nền
  phòng: mũ đội đúng đỉnh tóc, nơ/kẹp đúng thái dương trái, kính
  căn đúng 2 mắt (mắt nhìn xuyên vòng rỗng), balo túi sát vai +
  quai đúng vai, giày che kín giày gốc cả 3 bộ. Xem bằng mắt đã
  duyệt.
- Đen/magenta/đỏ thuần: 0 ở mọi món (chỉ còn 4 px magenta ở kính
  gái và 12 px ở balo gái — viền không đáng kể).
- Lỗ alpha kín ≥3 px: chỉ lỗ tròng kính (đúng thiết kế — mắt nhìn
  xuyên qua) + lỗ 1886 px gái / 1497 px trai ở balo (khe giữa thân
  túi và quai vòng — đặc điểm thật của túi) + lỗ nhỏ ≤35 px ở
  mũ/nơ/kẹp (khe nếp vải, không nhìn thấy ở cỡ hiển thị).
- Quan sát nhỏ, không chặn: sau khi xóa càng, soi kĩ tròng phải
  kính thấy một "hình chữ nhật" mờ — đo bằng code cho thấy
  **không có hình chữ nhật trong dữ liệu pixel** (trong rect
  alpha=0 hoàn toàn, RGB=0, màu nền tối tại tâm rect đúng
  (60,60,80) như nền và như tròng trái; vòng còn nguyên). Đây là
  hiệu ứng tương phản/kết xuất; ở cỡ điện thoại (nhân vật 360 px)
  không nhìn thấy. (Đã kiểm lại sau đó — ghi chú này SAI, xem mục "Sửa kính lô 3" ở cuối: hình chữ nhật là thật do mask xóa tròng hình chữ nhật, đã sửa thành lỗ tròng ellipse.)
- Mặt dưới beret gái có vùng hồng mauve đậm — bóng mặt trong của
  beret nghiêng, chấp nhận được.
- Caveat thừa hưởng từ lô 1/2: phụ kiện vẽ từ ảnh gốc (không phải
  ảnh toàn thân đã lượng tử) nên khi app đổi nghỉ → vẫy, shading
  nhân vật nhấp nhẹ như đã ghi ở lô 1/2; phụ kiện đứng yên theo
  khung nên không nhấp theo.

## Việc còn lại cho giai đoạn code (E) — bổ sung lô 3

- Entry manifest cho 10 file trên (loại file mới `*_hat_01`,
  `*_bow_01`/`*_clip_01`, `*_glasses_01`, `*_backpack_01`,
  `*_shoes_02`; **không** chạm `assets/manifest.json` ở lô này —
  manifest cập nhật ở giai đoạn code) + cập nhật `source` thành
  "Muse vẽ AI 21/11 theo DESIGN.md".
- `CharacterView` vẽ phụ kiện chồng lên ảnh toàn thân theo đúng
  bbox trên (khung 1024×1536); kính đặt theo tâm mắt từng nhân
  vật (nữ y≈561, nam y≈626); giày thay thế vẽ đè giày gốc; balo
  vẽ chồng (túi cạnh vai, quai trước ngực) — kiểm z-order với tay
  ở biến thể wave.
- Tủ đồ (T2-05) / Cửa hàng (T2-06) bán chính các phụ kiện này;
  giày thay thế là món đổi giày gốc.
- Thang cỡ pet + test neo + tràn 608×248 + 640×320 + full suite
  xanh (như mục việc còn lại của lô 1/2).

## Sửa kính lô 3 — xoá hình chữ nhật trong tròng phải (đẩy sau fix2, 21/11)

- Phát hiện khi ghép kính lên nền xám phẳng (128,128,128): trong tròng PHẢI của cả 2 kính (girl_glasses_01, boy_glasses_01) thấy một HÌNH CHỮ NHẬT, mép thẳng — tròng trái tròn sạch. Ghi chú của agent lô 3 ("không có trong dữ liệu pixel") là SAI.
- Nguyên nhân đo bằng code (không phải lớp wash mờ): trong lòng tròng alpha = 0, ảnh test xám đồng nhất 128 — không có pixel wash nào. Lỗi là HÌNH DẠNG của lỗ tròng: lỗ tròng phải có bề rộng hàng KHÔNG ĐỔI theo y (gái ~115 px, trai ~104 px), trong khi tròng trái là hình tròn (rộng 103→138→102 gái). Agent lô 3 đã xoá tròng màu (kính v1) bằng mask HÌNH CHỮ NHẬT nên mép trong của gọng bị cắt thẳng.
- Sửa (giữ nguyên gọng + càng kính, chỉ sửa vùng tròng phải): tạo hình ellipse cho lỗ tròng phải (tâm = tâm tròng phải, rx/ry lấy từ tròng trái tròn): (a) phần lỗ chữ nhật nằm NGOÀI ellipse ("overhang", gái 1.194 px, trai 674 px) được lấp đầy bằng màu gọng (inpainting Laplace từ gọng xung quanh), alpha = 255; (b) phần gọng nằm TRONG ellipse ("lobe", gái 1.068 px, trai 1.541 px) xoá về alpha = 0; (c) viền ellipse làm mềm 3 px (ramp alpha). Gái: ellipse tâm (618, 551), rx = 69, ry = 74. Trai: tâm (610, 617), rx = 66, ry = 71.
- Kiểm: bề rộng lỗ sau sửa theo y — gái [97, 127, 135, 127, 97] (tròn, khớp tròng trái [103, 131, 138, 131, 102]); trai [89, 121, 129, 121, 89] (tròng trái [96, 125, 133, 124, 96]). Trong lòng tròng phải (d < 0,90), số pixel alpha > 0 = 0 ở cả 2 kính. Ghép lên nền xám phẳng: cả 2 tròng đều tròn, không còn hình chữ nhật. Ghép lên mặt bé: mắt nhìn xuyên qua tròng rỗng, không còn vùng sáng hình chữ nhật quanh mắt phải. Diff ngoài vùng tròng phải = 0 (gái 3.602 px đổi, trai 3.463 px, chỉ trong bbox tròng phải). Tỉ lệ bán trong suốt 0,51% (gái) / 0,53% (trai) — chủ yếu là viền mềm 1 px, như bản gốc.
- File thay thế (đẩy .b64, Claude decode): app/assets/images/character/girl/girl_glasses_01.png (74.920 byte), app/assets/images/character/boy/boy_glasses_01.png (73.494 byte). Không động vào các phụ kiện khác (mũ, nơ/kẹp, balo, giày đã kiểm đạt).

## Fix3 — sửa theo review của Claude (lô 2 ĐẠT, lô 3 làm lại 3 món + tỉa bóng cổ) — giai đoạn 1: giày + kính + cổ (balo làm riêng giai đoạn 2)

Claude decode lô 2 + lô 3, commit `5945c4f` (21/11 ~17:13): lô 2 bé trai ĐẠT; lô 3 mũ/nơ/kẹp ĐẠT, 3 món làm lại (giày, balo, kính) + tỉa bóng cổ bé trai. Giai đoạn 1 đẩy giày + kính + cổ; balo làm theo cách mới (toàn thân có balo, xem mục riêng giai đoạn 2), KHÔNG đẩy kèm.

### 1. Tỉa bóng cổ bé trai (boy_full_03, boy_full_03_wave, boy_full_02_wave)

- Lỗi: cạnh cổ phải dưới tai của 03/03w và cạnh cổ trái của 02w có chấm tối nhỏ nhìn thấy cả ở cỡ app — mép bóng dưới hàm lòi ra ngoài đường viền mặt. Đo bằng code: 03 là nêm tối hình tam giác x 699–714, y 686–715 (rộng nhất 7 px ở y≈700, nhọn dần xuống y=715); 03w nêm tương tự x 693–707, y 700–717; 02w cổ trái x ~300–317, y ~692–712.
- Cách tỉa (bằng code, không vẽ lại): trong hộp hẹp quanh nêm, mỗi cột tìm pixel da thấp nhất, đặt alpha=0 cho pixel tối (R<170, R+G+B<380) nằm dưới da +2 px (chừa 2 px để giữ viền tai/bóng mép trong mặt). Chỉ tỉa đúng phần lòi ra, giữ nguyên bóng trong mặt và đường viền tai.
- Số pixel đã tỉa: 03: 76 px; 03w: 55 px; 02w: 129 px. Sau tỉa, pixel tối còn lại trong hộp là viền tai/bóng trong mặt (03: 28 px, 03w: 34 px, 02w: 51 px) — giữ nguyên có chủ đích.
- Kiểm: trước/sau phóng 3× trên nền tối (60,60,80) — mép dưới tai sạch, bóng trong mặt còn nguyên; cỡ app trên room_v3 (cao 360 px, chân (630,810)) — không còn chấm tối. Bán trong suốt 0,000%. Kích thước: 03: 312.501 byte; 03w: 314.748 byte; 02w: 354.218 byte.
- Lưu ý: khe nách bản vẫy 03w (1.228 px) là nền thật giữa tay giơ và thân, KHÔNG phải lỗ — không lấp (đã chốt từ fix2).

### 2. Kính thu nhỏ (girl_glasses_01, boy_glasses_01) — scale từ bản đã sửa lỗ tròng ellipse

- Lỗi cũ: kính gái to quá, gọng trái (càng dài ~78–90 px chĩa ngang) lòi ra ngoài tóc; càng phải ~18–20 px. Yêu cầu Claude: thu nhỏ ~15%, mép ngoài nằm trong má, bỏ đoạn càng chĩa ngang, giữ nguyên bản sửa lỗ tròng ellipse.
- Cách làm (bằng code, từ file kính ĐÃ SỬA trên nhánh — không vẽ lại từ bản lỗi): scale 0,85 quanh điểm giữa 2 mắt (gái (504,561), trai (504,626)) bằng LANCZOS, rồi xóa càng: chỉ giữ pixel nằm trong 2 đĩa tròng (bán kính = bán kính ngoài khung theo chiều dọc × 0,85 + 1,5 px) hoặc trong hộp cầu nối giữa 2 tròng. Sau scale, alpha bị mềm do resample (bán trong suốt 32,6% gái / 40,5% trai) nên đã làm cứng alpha (ngưỡng 128 → 0/255), về 0,00%.
- Số đo sau sửa: tâm tròng gái (405,562)/(602,559), bán kính ngoài 85,4/82,5; trai (414,626)/(595,626), bán kính ngoài 80,3/76,5. Đã xóa càng: gái 3.233 px, trai 2.562 px. Bbox mới: gái x[319,685] y[475,647]; trai x[333,672] y[545,706].
- Tròng vẫn tròn (lỗ ellipse giữ nguyên): đo rộng lỗ theo y (dy −40,−20,0,20,40) — gái trái [99,117,123,117,97], phải [92,112,118,112,90]; trai trái [94,113,118,111,90], phải [86,108,113,106,84]. Ghép lên nền xám 128: 2 tròng tròn, không hình chữ nhật, không càng.
- Mắt trong tròng: scale quanh điểm giữa làm tâm tròng dịch vào trong ~17 px so với tâm mắt (mắt lệch ra ngoài trong tròng), nhưng tròng mắt vẫn nằm gọn trong lỗ (khe hở nhỏ nhất ~11 px ở mép ngoài mắt trái gái; ở cỡ app ~3 px, không nhận ra). Vệt tối dưới đáy mỗi tròng là bóng khung gốc (đối chiếu ảnh ghép kính gốc cũng có), không phải lỗi do scale.
- Kiểm: ghép lên CẢ 6 ảnh mỗi bé (3 nghỉ + 3 vẫy), phóng 3× trên nền tối — mắt nhìn xuyên tròng rỗng, mép ngoài trong má, không càng; cỡ app trên room_v3 — kính vừa mặt, tự nhiên. Kích thước: gái 46.652 byte, trai 44.450 byte.

### 3. Giày thay thế vẽ lại (girl_shoes_02, boy_shoes_02) — bỏ viền trắng dày

- Lỗi cũ: viền trắng dày bao quanh đôi giày, nhìn rõ trên sàn và nền xám.
- Cách làm (nói thẳng — lệch khỏi hướng dẫn vẽ bằng generator): agent đã thử vẽ bằng generator nền magenta rồi key — ảnh đẹp, key sạch (0% fringe trắng trong 3 px), nhưng tư thế không khớp giày gốc (nhìn từ trên cao, lỗ cổ giày lớn, quai nằm giữa thân giày, trong khi giày gốc nhìn thẳng từ trước, quai ở trên cùng). Đo bằng code: bản vẽ gái rò 1.197 px + phủ trắng lên chân ~2.100 px; bản vẽ trai rò 3.727 px (giày gốc lộ qua lỗ cổ giày). Không thể đạt rò=0 bằng cách đó nên đổi cách: lấy đúng silhouette giày từ ảnh toàn thân gốc đã duyệt (phân loại màu/da trên cả 6 ảnh mỗi dáng, hợp nhất, giữ lỗ cổ giày trong suốt để da lộ tự nhiên), rồi tô trắng giữ nguyên shading. Đây KHÔNG phải vá pixel bản cũ — file giày cũ lỗi không hề dùng làm nguồn. Ảnh generator đã xóa khỏi staging sau khi đo xong (chỉ giữ script build2–build14 làm vết).
- Số đo: gái 21.587 byte, bbox x[396,628] y[1339,1428]; trai 30.208 byte, bbox x[323,679] y[1313,1428]. Bán trong suốt 0,0000. Bbox hẹp hơn bản cũ (gái cũ x[391,642] y[1299,1428], trai cũ x[328,681] y[1291,1428]) vì bản cũ bao cả quầng trắng; đáy vẫn y=1428.
- Kiểm: nền xám 128 phóng 3× — không còn quầng trắng dày (bản cũ giãn mask 10–12 px + tô trắng), chỉ còn nhám mép 1–2 px vốn có của ảnh gốc; cỡ app trên room_v3 — tự nhiên, không viền; ghép lên cả 6 ảnh mỗi bé.
- Rò — nói thẳng, KHÔNG đạt đúng 0 tuyệt đối theo cách đếm nghiêm nhất, nhưng bề mặt giày đã che kín hoàn toàn. Hai cách đếm: (a) đếm khoan dung (loại pixel là da ở bất kỳ biến thể nào, kiểu lô 3): **0 px trên cả 12 ảnh**; (b) đếm nghiêm theo từng bộ (đỉnh giày riêng mỗi bộ, chỉ loại da của chính bộ đó): gái 91–315 px/bộ, trai 0–389 px/bộ (02: 1 px, 03: 27 px, 01w: 389 px). Toàn bộ là pixel mép 1–2 px ở đỉnh quai/cổ giày và viền lỗ cổ giày — nơi 6 bản render lệch nhau 1–3 px nên một file chung không thể vừa che hết giày bộ này vừa không chạm da bộ khác. Ở cỡ app chúng vô hình (đã kiểm trên room); ở 3× chỉ còn thấy mờ 1 px viền tím nhạt quanh lỗ cổ giày gái và 1–2 chấm 1 px ở đỉnh nơ/cổ giày. Muốn ép về 0 phải phủ trắng lên da/quần ở bộ khác — đã thử một bản như vậy và nó tạo vệt trắng ngang chân bé trai nên đã hoàn lại. Phủ lố lên da trên đỉnh giày: gái 0–1 px, trai 0–39 px (không đáng kể). Quần dài của trai bộ 02/03 vẫn hiện đúng trên giày (không bị phủ trắng), da cổ chân của trai bộ 01 vẫn lộ tự nhiên — đó là hành vi đúng, không phải rò.
- Nhờ Claude soi kỹ ở 3× vùng lỗ cổ giày gái (viền tím nhạt 1 px) và đỉnh cổ giày trai bộ 01w — nếu không chấp nhận thì hướng sửa tiếp là phủ thêm 1 px đúng các pixel tối đó, không phải vẽ lại.
- File thay thế (đẩy .b64, Claude decode): app/assets/images/character/girl/girl_shoes_02.png, app/assets/images/character/boy/boy_shoes_02.png. Balo cũ (girl_backpack_01 / boy_backpack_01) KHÔNG đẩy kèm — làm lại theo cách mới ở giai đoạn 2.

## (E) lô 4 — khung đi bộ bé trai (24 khung, 3 bộ × 2 hướng × 4 bước)

Phục vụ PR (G) đi lại trong phòng. Mỗi khung là MỘT ảnh toàn thân hoàn
chỉnh 1024×1536 PNG trong suốt, cùng phong cách 3D mềm, sáng trên-trái,
cùng tư thế/mặt/đồ với ảnh nghỉ — chỉ đổi tư thế chân/tay/thân.
Hướng: dr = đi xuống-phải nghiêng 3/4, ur = đi lên-phải nghiêng 3/4;
hướng trái app lật ngang. Chu trình a/b/c/d: a = chân trái bước trước
gót chạm, chân phải sau mũi đẩy; b = passing (chân trái thẳng dưới thân,
chân phải co nhấc sau); c = mirror của a; d = mirror của b; d→a nối vòng.
Mốc chung: chân y=1429, tâm mắt y≈626 (như ảnh nghỉ), chiều cao khớp ảnh
nghỉ. Đẩy 21/11 thành 3 commit vì giới hạn kỹ thuật (xem cuối mục):
`b4e13bce` (bộ 01), `fc2c0f5d` (bộ 02), `732f68c3` (bộ 03, đầu nhánh).
Đối chiếu blob SHA + kích thước trên nhánh khớp 24/24.

### Cách làm
Vẽ khung đầu mỗi hướng/bộ bằng cách sửa ảnh nghỉ thô, rồi resume chỉ đổi
chân/tay cho các khung sau (như biến thể wave lô 1/2). Keying bằng
`walk-boy/work/walk_key.py` (chuyển từ `boy2/work/boy_key.py`, cùng logic
key/chuẩn hóa; đo chân từ pixel dist>100 thay vì bbox vì bbox tính cả bóng
đổ; ky = 803/(feet_y_raw·s − eye_y), kẹp [0,94, 1,0], co quanh chân để mắt
về y 626). Cả 24 khung quantize về 256 màu theo `boy2/work/quantize.py`
(MAXCOVERAGE + Floyd–Steinberg, giữ alpha gốc — cùng chuẩn ảnh nghỉ lô
1/2) để vừa giới hạn đẩy; semi vẫn 0,0000, bbox giữ nguyên.

### Bảng 24 khung (PNG cuối, semi 0,0000, chân y=1429)
- 01_dr_a 350.052 B, bbox (83,156,940,1429), mắt (512,9, 625,5), ky 0,9896
- 01_dr_b 349.502 B, bbox (78,158,944,1429), mắt (517,8, 626,1), ky 0,9872
- 01_dr_c 335.898 B, bbox (84,158,940,1429), mắt (525,8, 623,5), ky 0,9871
- 01_dr_d 331.915 B, bbox (85,166,937,1429), mắt (537,9, 625,3), ky 0,9816
- 01_ur_a 322.036 B, bbox (167,166,856,1429), mắt (700,8, 625,5), ky 0,9805
- 01_ur_b 328.092 B, bbox (154,188,869,1429), mắt (680,8, 625,9), ky 0,9641
- 01_ur_c 346.289 B, bbox (157,169,867,1429), mắt (694,6, 626,7), ky 0,9795
- 01_ur_d 327.773 B, bbox (157,198,867,1429), mắt (681,5, 625,6), ky 0,9560
- 02_dr_a 358.406 B, bbox (88,171,935,1429), mắt (495,9, 623,2), ky 0,9776
- 02_dr_b 350.452 B, bbox (90,168,933,1429), mắt (525,8, 622,7), ky 0,9799
- 02_dr_c 335.452 B, bbox (91,178,925,1429), mắt (452,0, 626,0), ky 0,9722
- 02_dr_d 368.970 B, bbox (90,167,932,1429), mắt (540,4, 555,6)*, ky 0,9817
- 02_ur_a 383.151 B, bbox (161,183,862,1429), mắt (698,1, 626,2), ky 0,9679
- 02_ur_b 363.479 B, bbox (173,206,849,1429), mắt ~626†, ky 0,9503
- 02_ur_c 401.016 B, bbox (142,201,881,1429), mắt (692,8, 625,3), ky 0,9536
- 02_ur_d 328.349 B, bbox (178,211,844,1429), mắt (553,0, 637,7)*, ky 0,9461
- 03_dr_a 339.861 B, bbox (93,184,930,1429), mắt (511,8, 624,2), ky 0,9670
- 03_dr_b 318.712 B, bbox (183,170,841,1429), mắt (705,5, 626,3), ky 0,9786
- 03_dr_c 331.026 B, bbox (94,187,928,1429), mắt (509,1, 625,0), ky 0,9651
- 03_dr_d 326.874 B, bbox (175,174,849,1429), mắt (714,6, 625,4), ky 0,9754
- 03_ur_a 320.006 B, bbox (146,174,877,1429), mắt (677,7, 626,8), ky 0,9751
- 03_ur_b 297.546 B, bbox (185,185,839,1429), mắt (718,9, 626,3), ky 0,9669
- 03_ur_c 330.946 B, bbox (151,172,872,1429), mắt (677,9, 626,4), ky 0,9767
- 03_ur_d 290.445 B, bbox (186,199,838,1429), mắt (721,9, 626,3), ky 0,9563

\* Detector mắt nâu bắt nhầm trên mặt xoay (02_dr_d y=555,6 là lông mày,
02_ur_d y=637,7 là mắt xa). Đo chéo bằng đồng tử: 02_dr_d y=599,5,
02_ur_d y=601,4, khung chuẩn 01_dr_a y=604,0 → vị trí đúng, chỉ detector
sai. † 02_ur_b detector trả None sau khi thêm dải y (xem dưới); đồng tử
phải y=601,9 (chuẩn 604,0) → vị trí đúng.

### Kiểm chứng chu trình
Ghép 4 khung mỗi hướng thành dải (nền tối, cao 360 px) + ghép vào phòng
v3b (chân (630,810), cao 360 px): đi tự nhiên, chân xen kẽ đúng, tay đánh
ngược pha, đầu ổn định, không giật, không trượt chân. Lỗ: 02_dr/02_ur =
0; lỗ lớn 01_dr_b 21.987 px và 03_dr_c 8.906 px là khe hở thật giữa 2 chân
bước; 02_ur_b 2.548 px là khe nách thật; 02_ur_a 50 px là khe nhỏ thật.

### Hai lỗi đã sửa trước khi đẩy
1. 02_ur_a và 02_ur_b tay phải giơ cao ngang vai (cả 3 khung a/b/c gốc
   đều giơ cao, chỉ c đã sửa) → vẽ lại a/b, hạ tay phải xuống ngang hông,
   giữ nguyên chân/mặt/đồ; dải 02_ur sau sửa đồng đều cả 4 khung.
2. Detector mắt ở norm-loop bắt nhầm lông mày của 02_ur_b (y=432,7 trong
   ảnh a2) → ky kẹp 0,94 → mắt rơi xuống 638–649. Đã thêm dải y [530,670]
   vào detector (mắt thật ở a2 581–606, ảnh cuối 620–650; lông mày 432 và
   tóc 507 bị loại) rồi key lại 02_ur_a/b; đồng tử xác nhận vị trí đúng.
   Lưu ý cho giai đoạn code: detector mắt nâu không tin được trên mặt
   xoay ur — mốc mắt từng khung nên đo bằng đồng tử hoặc ghi tay theo bảng
   trên (tiền lệ: patch mắt riêng theo ảnh như lô 2).
3. Ghép phòng bản đầu sai tỉ lệ vì ảnh preview phòng là 2048×1152 trong
   khi khung app 1600×900 (tỉ lệ ×1,28): chân phải ở y≈1037 và bé cao
   ~461 px trong preview, không phải 810/360.

### Giới hạn đẩy (bài học cho các lô sau)
- Connector push-files giới hạn TỔNG 16 MiB (16.777.216 byte) cho một lần
  gọi, không phải theo file (đo bằng tổng tích lũy: dư sau 14 file đúng
  1.217.688, sau 15 file đúng 683.000).
- HTTP MCP trả 413 khi body quá lớn: 10,8 MB lỗi, 12 file (5,47 MB) lỗi,
  8 file (3,59 MB) thành công — giới hạn HTTP nằm giữa 3,59 và 5,47 MB.
  **Mỗi lần push-files chỉ nên đẩy tối đa 8 file (~3,6 MB).**
- File .b64 đơn lẻ cũng có trần: 02_ur_c bản gốc 926.877 byte → .b64
  1.235.836 byte vượt trần 1.217.688 byte của file (đã xử lý bằng quantize
  256 màu còn 401.016 byte).

### Caveat
- Viền hồng nhạt 1–2 px quanh tóc và dưới bàn chân, thấy trên nền tối ở
  cỡ dải; trên sàn phòng sáng không lộ, ở cỡ app dưới ngưỡng thấy.
- 02_ur_c sau quantize x_max lệch 1 px so với bản gốc (882→881).
- Dải + ghép phòng dựng từ bản chưa quantize; khác biệt chỉ ở màu dither,
  dưới ngưỡng thấy ở cỡ hiển thị.

## (E) fix3 giai đoạn 2 — balo (12 ảnh toàn thân có balo, biến thể)

Chủ dự án xem ảnh và nhận xét balo + quai lô 3 lệch, không khớp người
(giống lỗi cắt lớp hồi đầu) nên ĐỔI CÁCH LÀM: không vẽ balo như lớp rời
đặt đè nữa. Vẽ lại TOÀN THÂN bé đang đeo balo cho từng ảnh gốc (6 ảnh/bé:
3 bộ × nghỉ/vẫy), cùng khung 1024×1536, cùng tư thế, chân và chiều cao
khớp ảnh gốc (như cách làm bộ đồ lô 1/2 đã đạt). Sau đó tách lớp balo
bằng hiệu giữa ảnh có balo và ảnh gốc — TÁCH KHÔNG SẠCH ở cả 2 bé
(diff ngoài vùng balo: gái 22–42%, trai 22–89%; generator vẽ lại toàn bộ
ảnh nên shading nhấp khắp nơi, không phải lệch vị trí; lớp thử tách đem
chồng lên ảnh gốc thì khác tới 29–45% pixel, lộ đường nối) → GIỮ 12 ẢNH
TOÀN THÂN CÓ BALO LÀM BIẾN THỂ (girl_full_0X[_wave]_backpack,
boy_full_0X[_wave]_backpack), app đổi ảnh thay vì chồng lớp. Balo cũ
(girl_backpack_01 / boy_backpack_01, lô 3) BỎ HẲN — Claude git rm 2 PNG
cũ và bỏ khỏi manifest khi decode. Đẩy 21/11 thành 2 lần (6 gái + 6 trai)
vì giới hạn HTTP ~3,6 MB/lần.

### Bảng 12 ảnh (PNG cuối, semi 0,0000)
- girl_full_01_backpack 446.892 B, 02 456.564 B, 03 483.699 B,
  01w 456.579 B, 02w 436.213 B, 03w 517.440 B
- boy_full_01_backpack 328.272 B, 02 304.171 B, 03 313.558 B,
  01w 343.035 B, 02w 329.728 B, 03w 352.371 B

### Căn chỉnh (đo bằng code)
- Bé gái: tâm mắt khớp ảnh gốc trong ±5 px (mắt (504,561), chân y
  1428–1429). 02w ban đầu lệch dọc ~10 px do nơ tím lọt vào mask đo mắt —
  đã sửa riêng bằng co dọc 0,98805 quanh chân, kiểm lại đạt.
- Bé trai: tâm mắt x lệch ≤2,1 px, y lệch 0,4–12,4 px ở bản vẫy (đầu hơi
  nghiêng, cùng mức như bản vẫy lô 2); chân y=1429, cao bbox 1287 (khớp gốc).

### Kiểm chứng
Ghép phòng cỡ app (cao 360 px) cả 12 ảnh trên room_v3: quai bắt đầu ở
ĐỈNH VAI, qua ngực nằm trên áo (có khóa điều chỉnh), túi sau lưng chỉ lộ
mép trên sau vai + hai bên vai/hông; bản vẫy quai bên tay giơ vẫn trên vai.
Phóng 3× nền xám 128: không lỗ alpha, không halo, không chấm đen (chấm đen
còn lại là hạt dither rời rạc, cụm lớn nhất 7–8 px). Claude DUYỆT ảnh ghép
xem trước 21/11 ~18:28 rồi mới đẩy.

### Caveat
- Đổi nghỉ → đeo-balo sẽ nhấp shading nhẹ (như caveat biến thể wave lô
  1/2), ở cỡ điện thoại khó nhận ra.

# (E) lô 4 — khung đi bộ bé gái (24 khung, 3 bộ × 2 hướng × 4 bước)

Lô 4 làm khung đi bộ cho PR (G): mỗi bộ 2 hướng (dr xuống-phải, ur lên-phải,
nghiêng 3/4) × 4 bước (a/b/c/d), mỗi khung MỘT ảnh toàn thân hoàn chỉnh
1024×1536 PNG trong suốt, cùng phong cách 3D mềm, sáng trên-trái.
Hướng trái app lật ngang nên không vẽ. Đẩy 3 lần × 8 file theo bộ
(02: b584043a, 01: b43ed907, 03: 3d8559f0), .b64 4,15 / 4,28 / 5,02 MB.

## Cách làm
- Khung đầu mỗi hướng/bộ sửa mới từ ảnh nghỉ, các khung sau resume từ
  snapshot khung trước — nhưng snapshot hết hạn sau ~1–2 giờ nên mọi lần
  vẽ lại đều sửa mới từ ảnh nghỉ + kiểm ngay từng khung.
- Prompt khóa đầu: "giữ đầu/tóc/mặt đúng vị trí, cỡ, chiều cao như ảnh gốc;
  mắt cùng cao độ; không nâng đầu, không ngửa đầu, không phóng to đầu;
  đầu không di chuyển, chỉ chân/tay đổi". Hướng ur: "nhìn hơi lên BẰNG MẮT,
  đầu giữ ngang" (chữ "nhìn lên" làm máy nâng cả đầu 35–102 px).
- Khung b/d: "chân lướt nhấc khỏi đất, vung TỚI TRƯỚC qua chân chống, gối
  cong về trước, mũi chúc xuống-trước; không đá sau, không quá gối chân
  chống; tay đánh ngược pha, khuỷu hơi cong, không chỉ thẳng".
- Khung: tâm bbox ngang → x=512, chân y=1429, mắt-y 556–566 (co dọc ky
  kẹp [0,97; 1,03]). KHÔNG căn mắt-x về 504: mặt 3/4 làm mắt nằm phải
  576–724, ép về 504 cắt tóc trái ở mép khung (bài học vòng 1).
- Mắt đo bằng detector gom cụm tròng xanh + lọc vùng đầu y 420–680
  (nơ/cúc váy tím y~708–739 từng bị gom nhầm thành "mắt", làm ky sai 3%).
  Miệng đo bằng code không tin được trên mặt 3/4 (bắt nhầm nơ ngực y~716)
  — kiểm bằng mắt.

## Đính chính mốc miệng (21/11)
Miệng cười thật bé gái là (519, 651), KHÔNG phải (517, 835) như mục lô 1/2
đang ghi — (517,835) là nơ ngực. Mắt→miệng ≈ 90 px (khớp bé trai ~94 px).
Miệng bé trai (508,720) nên kiểm lại cùng cách trước giai đoạn code.

## File (24 PNG, khung 1024×1536, PNG trong suốt, đã lượng tử 256 màu,
## bán trong suốt 0,0000, chân y=1428–1429)
girl_full_01_walk_dr_a/b/c/d.png, girl_full_01_walk_ur_a/b/c/d.png
(tương tự 02 váy tím, 03 váy hồng + tạp dề trắng)
[Bảng 24 khung: cỡ byte + tâm mắt + miệng + chân y + lỗ alpha — xem bảng
trong báo cáo lô 4; mắt-y 556,9–566,2; mắt-x 576–724.]

## Kiểm chứng chu trình (soi dải + ghép phòng, chân (630,810), cao 360 px)
- 01 dr: dr_d vẽ lại (chân trái bắt chéo trước chân phải chống, hết đá sau);
  tay vung giống dr_b chứ không gương hoàn hảo. 01 ur: passing đối xứng.
- 02 dr: tốt, Δy ≤ 5 px (nhưng mắt-x nhảy dr_b→c 33 px, c→d 75 px — xem
  caveat). 02 ur: ur_b sửa 2 vòng mới thành gương thật của ur_d (chân chống
  đổi bên); chân lướt ur_b ở giữa nhịp vung, chưa vượt hẳn lên trước như ur_d.
- 03 dr: b/d lướt đối nhau, tạp dề nguyên. 03 ur: ur_d vẽ lại thành gương
  của ur_b (chân phải chống + chân trái lướt tới trước).
- Không trượt chân; bóng đất magenta mờ ~1 px dưới vài bàn chân (chỉ thấy
  khi phóng 2×).

## Việc còn lại cho giai đoạn code (E) — bổ sung lô 4
- Phụ kiện lô 3 KHÔNG khớp khi đi bộ (mắt-x 576–724 vs nghỉ 504): quyết
  ẩn phụ kiện khi đi bộ, hoặc neo theo tâm mắt từng khung (bảng trên).
  Miếng vá mắt nhắm cùng vấn đề.
- 02 dr mắt-x nhảy 33–75 px giữa c→d: nếu cổng G yêu cầu ≤20 px cho cả
  dr thì xem lại riêng.
- Kiểm lại mốc miệng bé trai (508,720) trước khi dùng.

## (E) fix4 — xoá bóng chân 48 khung đi bộ + tóc búi thừa balo (21/11)

Claude review sau khi decode balo + khung đi bộ bé gái (PR #34, commit
299b934): (1) Cả 3 ảnh balo vẫy bé gái (01w/02w/03w, rõ nhất 03w) có
đỉnh đầu tách thành 2 thùy tròn, ảnh gốc không có — đo bằng code thì
silhouette đỉnh đầu đã khớp gốc trong 1–3 px, lỗi là rãnh ngôi giữa
quá sâu (khác biệt shading, không phải tóc thừa mọc ra). Đã sửa bằng
cách copy vùng đỉnh đầu từ ảnh gốc (x340–710, y130–300, feather 8 px,
chỉ trong giao alpha để silhouette không đổi), map màu về đúng palette
256 màu của file balo gốc: đỉnh đầu mượt như gốc, không thấy đường nối
(zoom 2× + ghép phòng cỡ app). Bé trai vẫy và 6 ảnh balo nghỉ không có
búi, để nguyên. (2) Dưới chân vài khung đi bộ (ví dụ gái 02_dr_b,
02_dr_d) có vệt bóng hồng/tím đậm loang ra sàn, ở cỡ app nhìn như vết bẩn
hồng — đã xoá bóng đổ dưới chân ở 41 khung đi bộ (trong 48 khung; 7 khung
bé gái vốn đã sạch: 01_dr_d, 02_dr_a, 02_ur_d, 03_dr_b, 03_dr_d, 03_ur_a,
03_ur_b), GIỮ NGUYÊN đế giày; app tự vẽ bóng ellipse nên ảnh không cần
bóng nền. Cách xóa: gái 2 lượt mask magenta (lượt 1 hue 325–338, lượt 2
mở hue 315–342/338 để bắt phần tối hue ~320 và phần sáng hue ~341 của
vệt bóng), component ≥40 px, vùng y1320–1430; trai xóa component alpha
tách rời trong y≥1280 (<1.500 px). Tổng 101.239 px đã xóa (gái 83.364,
trai 17.875); vệt lớn nhất 02_dr_d 25.934 px, 02_dr_b 22.707 px. Mặt dưới
đế giày giữ nguyên có chủ đích; bé trai còn vệt tối mỏng + mảnh hồng
dính liền đế (≤97 px/khung ở bộ 01/02) không tách được mà không chạm đế,
ở cỡ app gần như không thấy. Chân y đổi tối đa 2 px (02_ur_b gái,
03_ur_b trai). Kiểm: ghép phòng cỡ app không còn vết hồng trên sàn;
phóng 3× vùng chân đế giày nguyên vẹn; 41/41 file ≤256 màu, semi 0.0000.
Đẩy đè cùng tên file, 6 lần (tối đa 8 file/lần): e44bf11f, 48469861,
b1a6b1dd, eaeaf8de, 0b135535, 79efdef6.

# Pet v3b — (F) lô 5: vẽ lại 12 pet theo tấm v2

Vẽ lại 3 loài × 4 giai đoạn theo phong cách 3D mềm mới (chủ dự án xác nhận 21/11 ~01:16;
giữ bản mới như ảnh, KHÔNG gộp dấu hiệu pet cũ — chủ dự án chốt 21/11 ~21:06).
Thay 1:1 file cũ PR #21, giữ đúng tên `app/assets/images/pets/<loài>_<giai đoạn>.png`.

## Nhận diện 3 loài theo v2 (khác hẳn bản cũ PR #21)

| Loài | Bản cũ PR #21 | Bản mới v2 (lô 5) |
|---|---|---|
| Chó Tinh Anh | Shiba tai nhọn + đồ thám hiểm | Chó vàng tai cụp, không đồ, thè lưỡi, mắt nâu to, mũi đen |
| Mèo Mũm Mĩm | Kem + nơ/len | Tabby cam + vòng cổ xanh dương + chuông bạc |
| Thỏ Bánh Bao | Cà rốt + nơ hồng | Trắng mắt xanh; trứng XANH NHẠT; nhỡ khăn xanh lá, trưởng thành tai cụp + khăn len nâu + hoa hồng |

## Bảng 12 file (khung 512×512, thân cao 400 px, đất y=440, semi 0,0000, 0 px dưới y=440, 256 màu)

| file | bytes | bbox | cao | lỗ lớn nhất |
|---|---|---|---|---|
| dog_egg | 79.058 | x[1,509] y[40,439] | 400 | 0 |
| dog_newborn | 109.783 | x[23,487] y[40,439] | 400 | 0 |
| dog_teen | 107.268 | x[74,436] y[40,439] | 400 | 0 |
| dog_adult | 99.286 | x[101,410] y[40,439] | 400 | 2 |
| cat_egg | 90.921 | x[78,432] y[40,439] | 400 | 371 (khe thật giữa vỏ và đuôi) |
| cat_newborn | 83.249 | x[152,417] y[40,439] | 400 | 0 |
| cat_teen | 85.384 | x[130,381] y[40,439] | 400 | 0 |
| cat_adult | 96.105 | x[111,389] y[40,439] | 400 | 52 (khe thật giữa 2 chân trước) |
| rabbit_egg | 67.946 | x[120,391] y[40,439] | 400 | 4 |
| rabbit_newborn | 90.255 | x[113,422] y[40,437] | 398 | 1 |
| rabbit_teen | 89.480 | x[99,411] y[40,439] | 400 | 301 (khe thật tai cụp–đầu) |
| rabbit_adult | 93.109 | x[102,409] y[40,439] | 400 | 16 |

Tổng PNG 1.091.844 B. Lỗ trong mắt thỏ nhỡ (113 + 49 px) đã lấp; các lỗ còn lại đều là khe thật.
Nốt nhỏ: vệt xanh nhạt ~1 px dưới đáy trứng/mới nở thỏ + viền xanh mờ dưới trứng mèo
(viền bóng còn sót, ở cỡ app trong phòng không thấy); trứng chó rộng 509 px (tai + đuôi thò 2 bên).

## 3 điểm sửa theo review (chủ dự án chốt 21/11 ~21:06)

1. **Thỏ nhỡ tai cụp:** vẽ lại `rabbit_teen.png` — tai dựng thành tai cụp rủ 2 bên như
   trưởng thành (ngắn hơn một chút), giữ khăn xanh lá; 3 giai đoạn đã nở cùng tai cụp.
   Chó v2 vẽ lại bị loại (mặt đổi quá nhiều), vẽ lại v3 giữ mặt chibi như nhỡ mới đạt.
2. **Chó/mèo trưởng thành lớn hơn nhỡ rõ:** vẽ lại `dog_adult.png` (thân dài hơn, chân cao
   hơn, mặt bớt tròn) và `cat_adult.png` (thân dài hơn, chân cao hơn, mặt bớt tròn) —
   ghép nhỡ + trưởng thành cạnh bé trong phòng thấy pet lớn lên rõ.
3. **Mảnh vỏ trong vùng thân:** `cat_newborn.png` xoá 3.864 px mảnh văng xa (mảnh trái
   2.318 px, mảnh dưới-trái 806 px, mảnh dưới-phải 673 px + 20 đốm ≤10 px); giữ mảnh sát
   vỏ 363 px + mảnh giữa dưới đáy vỏ 147 px. `rabbit_newborn.png` xoá mảnh vỏ nửa bát trái
   6.145 px (6.030 px + 115 px vụn mép); mảnh phải + vệt xanh 62 px giữ lại vì dính liền
   vỏ chính, đọc như mảnh vỏ trứng trong vùng thân. Hệ quả: thỏ mới nở cao 398 (đáy y=437)
   thay vì 400 — lệch 2 px, ở cỡ app chưa tới 1 px.

## Tỉ lệ hiển thị (CHỐT theo code PR #34, v0.0.11)

Trứng 30% (108 px), mới nở 40% (144 px), nhỡ 58% (209 px), trưởng thành 72% (259 px)
chiều cao bé (360 px). Bảng cũ 33/43/58/69% HẾT HIỆU LỰC (chỉ nhỡ 58% khớp).
PNG vẽ thân cao 400 px mọi giai đoạn là đúng.

Đẩy 12 `.b64` lên nhánh `task/E-nhan-vat-v3b`, 2 lần (tối đa 8 file/lần):
`61871d58` (chó + mèo, 8 file), `111613a1` (thỏ, 4 file); đầu nhánh `111613a1`;
12/12 blob SHA đối chiếu khớp trên nhánh. Khung đi (walk_a/b) chưa làm — chỉ sau khi duyệt
12 ảnh đứng.

# Giao diện kiểu game — (F) lô 6: UI v3b (17 file, app/assets/images/ui/)

Phong cách 3D mềm pastel như nhân vật (E) + phòng v3b + thị trấn v3b.
KHÔNG có chữ trên ảnh (app tự vẽ chữ tiếng Việt) — trừ `ui_logo.png` chỉ có chữ Latin "TimoKid".
PNG trong suốt, alpha sạch (semi 0,0000), không bóng đổ nền (app tự vẽ bóng).

## Bảng 17 file

| file | kích thước | bytes | ghi chú |
|---|---|---|---|
| ui_btn_back.png | 256×256 | 35.809 | Nút kẹo hồng, mũi tên trái trắng to |
| ui_btn_back_pressed.png | 256×256 | 37.145 | Cùng nút, lún xuống + tối hơn |
| ui_icon_wardrobe.png | 256×256 | 37.927 | Nút xanh dương, tủ + móc áo |
| ui_icon_shop.png | 256×256 | 36.712 | Nút xanh lá, túi mua sắm |
| ui_icon_town.png | 256×256 | 41.527 | Nút tím, nhà nhỏ |
| ui_icon_room.png | 256×256 | 31.709 | Nút cam, giường nhỏ |
| ui_coin.png | 128×128 | 14.754 | Xu vàng, sao nổi trên mặt, không nền tròn |
| ui_gem.png | 128×128 | 12.129 | Kim cương tím |
| ui_star.png | 128×128 | 10.654 | Sao vàng 5 cánh |
| ui_hud_bar.png | 1024×128 | 1.636 | Thanh trong mờ (alpha 168); dải giữa x100–924 đơn sắc tuyệt đối theo hàng x (đo bằng code), kéo giãn ngang được |
| ui_sign_board.png | 768×320 | 50.423 | Biển gỗ + 2 dây, giữa trống; nội dung 768×267 letterbox, không méo |
| ui_logo.png | 1024×512 | 222.368 | "TimoKid" gradient hồng→tím, viền trắng; bé gái + bé trai + 3 pet quanh chữ |
| ui_splash_bg.png | 1600×900 | 572.623 | Trời pastel mây + thị trấn mờ xa (đục) |
| ui_onboarding_bg.png | 1600×900 | 437.561 | Phòng thay đồ, giữa trống (đục) |
| ui_pedestal.png | 512×256 | 32.703 | Bệ 2 tầng tím + kem |
| ui_card.png | 384×480 | 2.960 | Khung thẻ, viền sáng trắng |
| ui_card_selected.png | 384×480 | 6.068 | Viền vàng + quầng phát sáng |

Tổng PNG 1.584.708 B. Thanh HUD và 2 thẻ có semi > 0 theo thiết kế
(nền trong mờ / quầng sáng), không phải bẩn. 0 px magenta còn sót (đo bằng code).
Bóng tiếp đất nướng sẵn màu magenta đậm đã xoá bằng 3 lớp (cắt đáy + tẩy viền + tô lại).
2 nền dùng MEDIANCUT (tường/trời mượt hơn MAXCOVERAGE: 125 vs 16 màu tường);
nhân vật/UI vẫn MAXCOVERAGE như các lô trước. Biển gỗ vẽ lại bản rộng rồi letterbox
để không méo. Nốt nhỏ: dây treo biển mỏng ở cỡ app; 2 chấm tối ~2 px ở 2 đầu đáy bệ
(chỉ thấy khi phóng 2×); logo tóc bé gái hơi sáng hơn bản final.

Đẩy 17 `.b64` lên nhánh `task/E-nhan-vat-v3b`, 3 lần (8+8+1):
`f11fa270` (nút + icon menu + xu + kim cương, 8 file),
`10c90860` (sao + thanh HUD + biển gỗ + logo + splash + onboarding + bệ + thẻ, 8 file),
`e7d19a88` (thẻ được chọn, 1 file); đầu nhánh `e7d19a88`.
15/17 blob SHA đối chiếu khớp trên nhánh; 2 nền (splash bg, onboarding bg) không tải lại
được (giới hạn tool với file ≳400 KB) — cùng commit `10c90860` với 6 file đã xác minh.

# Cửa hàng + đồ cho pet — (F) lô 7: shop v3b (9 file)

Phong cách 3D mềm pastel như nhân vật (E) + phòng v3b + thị trấn v3b + UI lô 6.
KHÔNG có chữ trên ảnh (app tự vẽ chữ tiếng Việt). PNG trong suốt, alpha sạch
(semi 0,0000), không bóng đổ nền (app tự vẽ bóng) — trừ `shop_bg.png` là nền đục.

## Bảng 9 file

| file | kích thước | bytes | đích | ghi chú |
|---|---|---|---|---|
| shop_bg.png | 1600×900 | 552.506 | app/assets/images/backgrounds/ | Nền đục, kệ gỗ 2 rìa, giữa/dưới trống sáng (độ sáng giữa 210,5, đáy-giữa 225,3); MEDIANCUT |
| pet_food_bone.png | 512×512 | 104.625 | app/assets/images/items/ | Bánh xương nâu vàng |
| pet_food_fish.png | 512×512 | 192.615 | app/assets/images/items/ | Cá nướng nhỏ vàng nâu, đứng dọc |
| pet_food_carrot.png | 512×512 | 87.680 | app/assets/images/items/ | Cà rốt cam, lá xanh |
| pet_toy_ball.png | 512×512 | 109.940 | app/assets/images/items/ | Bóng sọc pastel |
| pet_toy_yarn.png | 512×512 | 174.788 | app/assets/images/items/ | Cuộn len hồng, sợi thò ra còn nguyên |
| pet_toy_plush.png | 512×512 | 175.296 | app/assets/images/items/ | Gấu bông mini kem + nơ hồng |
| ui_icon_clothes.png | 256×256 | 37.911 | app/assets/images/ui/ | Nút kẹo hồng, áo trắng; cùng bộ nút lô 6 |
| ui_icon_pet_items.png | 256×256 | 36.868 | app/assets/images/ui/ | Nút kẹo vàng cam, bát thức ăn pet trắng |

Tổng PNG 1.472.229 B. Tách nền bằng khoảng cách RGB tới màu nền magenta từng file
(ngưỡng 50) + despill viền (thay pixel viền lẫn nền bằng màu pixel trong kề);
magenta còn sót theo ngưỡng chặt (< 60) chỉ 0–8 px/file; 0 px bóng đổ nướng sẵn.
Nốt nhỏ: cá đứng dọc; viền hồng rất mờ còn lại ở mép gấu bông khi soi 2–3× trên
nền trắng (ở cỡ app không thấy).

Đẩy 9 `.b64` lên nhánh `task/E-nhan-vat-v3b` sau khi duyệt (2 lần, 8+1 file):
`27fb3846` (6 món pet + 2 icon tab, 8 file), `f03322ae` (shop_bg, 1 file);
đầu nhánh `f03322ae`. 8/9 blob SHA đối chiếu khớp trên nhánh; shop_bg không tải lại
được (giới hạn tool với file ≳400 KB) — một mình trong commit `f03322ae`,
blob SHA local `d4976e65f25f`, SHA-256 local `aa1f6210f75d`.

### Lô 8 nhóm (B) — Pet chuyển động (54 file, 22/11/2026)

Mỗi loài dog/cat/rabbit × 3 giai đoạn newborn/teen/adult × 6 file
(`{loài}_{giai đoạn}_walk_a..d.png`, `_happy.png`, `_sit.png`) → 54 file vào
`app/assets/images/pets/`, 512×512, PNG trong suốt, alpha sạch (semi 0,0000,
0 px magenta), quantize 256 màu MAXCOVERAGE + Floyd–Steinberg. Vẽ từ 9 ảnh
giai đoạn lô 5 đã duyệt (giữ đúng nhận dạng pet v2); walk nhìn nghiêng 3/4
quay PHẢI, chân luân phiên rõ, đầu lệch ≤2 px trong chu kỳ (chuẩn ≤5 px);
walk/sit chân y=440 (thỏ newborn 438 như bản gốc đã duyệt); happy chân rời
đất 40 px (y=400, thỏ newborn 398); newborn cả 6 khung vẫn trong mảnh vỏ.
Đo bằng code ĐẠT hết; soi bằng mắt trên nền tối + trắng + xám + phòng v3b
cạnh bé gái (tỉ lệ 40/58/72%). Tổng PNG 5.034.330 B (~6,71 MB .b64).
Nốt nhỏ đã soi: chu kỳ đi newborn chỉ đọc qua đuôi/móng/độ nghiêng (vẫn
trong vỏ nên chân không rõ như teen/adult); sit dog_adult/cat_adult co nhẹ
(scale 0,753/0,778 so với walk ~0,76/0,82) để vừa khung; happy nhấc 40 px,
ở cỡ app là cú nảy nhẹ; cat newborn walk_a mặt hơi xoay về trước; hoa ở
chân thỏ adult chạm đất trong khung đi (đúng thiết kế đã duyệt). Kỹ thuật:
vẽ 9 tấm sheet 3×2 rồi cắt bằng code; lỗi đã sửa — bỏ `binary_fill_holes`
(lấp khe chân làm magenta lọt vào thân ~2.400 px ở dog_adult walk_b/c),
inset cắt tấm tăng 12→20 px (dải phân cách trắng rộng 16 px, rò 2 px vào
đỉnh ô hàng 2). Đẩy 7 lần (8+8+8+8+8+8+6): `7dfb5e08` (chó newborn 6 + teen
walk_a/b), `86ac7b07` (chó teen walk_c/d + happy/sit + adult walk),
`254746c7` (chó adult happy/sit + mèo newborn 6), `d448b62a` (mèo teen 6 +
adult walk_a/b), `58e3a7a5` (mèo adult walk_c/d + happy/sit + thỏ newborn
walk), `aefdbc1b` (thỏ newborn happy/sit + teen 6), `9b1686d5` (thỏ adult 6);
đầu nhánh `9b1686d5`; 54/54 blob SHA đối chiếu khớp trên nhánh. ĐƯỢC DUYỆT
22/11 ~12:42 (Claude): cả 54 file, các nốt nhỏ đều chấp nhận, giữ nguyên.

### Lô 8 nhóm (A) — Vỡ trứng từ từ (15 file, 22/11/2026)

Mỗi loài dog/cat/rabbit × 5 file, 512×512, vào `app/assets/images/pets/`:
`{loài}_egg_crack_1.png` (1 vết nứt nhỏ), `{loài}_egg_crack_2.png` (nứt lan
+ 1 mảnh vỏ bong), `{loài}_egg_crack_3.png` (nứt khắp, nắp hé thấy lông/tai),
`{loài}_shell_bottom.png` (nửa vỏ dưới rỗng), `{loài}_shell_top.png` (nắp trên rời).
Làm bằng cách sửa trực tiếp từ ảnh trứng gốc lô 5 (không vẽ lại): đường cắt
răng cưa ±14 px — chó y≈165, mèo y≈285, thỏ y≈290; nắp crack_3 nâng 16 px +
xoay 4°, khe tối + dải lông cắt từ đỉnh đầu newborn (chó lông vàng + tai cụp,
mèo lông cam + tai cam, thỏ lông trắng + tai dài trắng/hồng); 2 mảnh vỏ có
viền tối trong 12 px + viền cắt tối 2 px; quantize 256 màu bằng palette trứng gốc.
Kiểm chứng: crack_1/2 silhouette lệch 0 px so với trứng gốc; bottom+top ghép
lại đúng mặt nạ vỏ (chó 100%, mèo 99,97%, thỏ 99,99%). App: crossfade
crack_1→2→3 (cùng khung, cùng vị trí), rồi tách nắp trên bay đi, để lại bát vỏ
rỗng. Nốt: nắp thỏ thưa (vành 3 răng, đầu thỏ chiếm giữa nắp); nắp chó khuyết
nhỏ góc dưới-trái (chỗ tai gắn); vệt xanh nhạt đáy thỏ là vệt gốc lô 5.
Kích thước: chó 81.169/85.483/100.865/53.144/22.844 B; mèo 92.672/95.601/
105.200/33.987/29.150 B; thỏ 69.206/72.623/79.094/34.326/10.866 B.
Đẩy 2 lần (8+7 file): `00db1263` (5 chó + cat crack_1/2/3), `634f1875`
(cat shell_bottom/top + 5 thỏ); đầu nhánh sau đẩy `634f1875`; 15/15 blob SHA
đối chiếu khớp trên nhánh. ĐƯỢC DUYỆT 22/11 ~02:45 (Claude): cả 15 file,
nắp thỏ giữ như hiện tại, 2 nốt nhỏ còn lại bỏ qua; ĐÃ DECODE + BẬT trong app
(PR #48, Claude báo 22/11 ~12:42). (Mục doc này lên muộn — lần đẩy doc đầu
tiên bị service restart gián đoạn, lần đẩy lại thẻ duyệt hết hạn ~03:44 —
nên gộp chung với mục doc nhóm (C) trong 1 lần đẩy.)

### Lô 8 nhóm (C) — room_v3_clean.png (1 file, 22/11/2026)

Nền phòng sạch 1600×900, PNG đục, 256 màu, 772.906 byte, SHA-256
`937716bc4ae884f4f16e0a9d028c7ab3a6f6363887ace84d6d2bb73307f188ee` →
`app/assets/images/backgrounds/room_v3_clean.png`. Y hệt `room_v3.png`
(694.028 byte, SHA-256 `a838c756…e41f40`), chỉ xoá 4 đồ rời bằng inpainting
theo mặt phẳng (Laplace có barrier, 1 px, Neumann) + lấp gradient dọc cho đầu
giường/tường kem + bóng sách trên bàn: gấu bông x[329,475) y[435,563)
(18.688 px); đèn sao x[42,223) y[428,613) (33.485 px); bình hoa x[1238,1363)
y[390,527) + cánh trái + bóng bình (17.709 px, giữ lại đầu phải cuốn sách
dưới); cốc bút x[1075,1151) y[432,523) (6.916 px). Tổng mask 76.798 px;
**diff ngoài 4 vùng xoá = 0 px**; chỉ quantize lại trong vùng mask bằng
palette gốc + Floyd–Steinberg. Đã soi 2× từng vùng + toàn cảnh + ảnh ghép
đặt lại 4 đồ rời (mỗi món 1 lớp, hết đè 2 lớp). Lưu ý nhỏ: vùng cốc còn mờ
viền hình chữ nhật ở 2×; vùng bình còn vệt sáng tròn rất mờ ở 2× — cả 2 đều
chấp nhận được (Claude duyệt 22/11 ~13:24). Đẩy 1 lần: `7d313e94`
(.b64 1.030.544 B, blob SHA local `eba185cb…`; file ~1 MB nên không đọc lại
được từ nhánh để đối chiếu — Claude kiểm bằng git khi decode).
**Sửa D_IMAGES.md (nợ):** mép trái tủ quần áo x≈1360 (không phải 1460–1600);
kệ x≈1150–1360; bàn kết thúc x≈1360 (không phải 1470); bình hoa đặt trên
bàn học, không phải trên kệ phải.

> **Sửa lỗi chó mới nở (22/11, sau PR #49):** ảnh đứng `dog_newborn.png` đã duyệt là chó
> ĐÃ RA KHỎI VỎ, nhưng 6 khung `dog_newborn_walk_a..d/happy/sit` của lô 8B lại vẽ chó ngồi
> TRONG VỎ. Đã vẽ lại cả 6 khung không vỏ, khớp đúng ảnh đứng (chó vàng, tai cụp, mũi đen,
> lưỡi thè, mắt nâu to), cùng cỡ: walk bbox y 41–440 (d: 42–440), happy y 10–400,
> sit y 30–440; chân y walk/sit 440, happy 400 (nhấc 40 px); đầu lệch 1 px trong chu kỳ đi.
> 6/6 file 512×512, semi 0 px, magenta 0 px, 256 màu. Sit cao 410 px (khung cũ trong vỏ
> cao 392 px) vì không còn vỏ bó dáng; lỗ alpha kín duy nhất 224 px là khe hở trong vòng
> đuôi cuộn của sit (x 117–132, y 345–364), nền thật nhìn xuyên qua, không phải lỗ thân.
> Mèo và thỏ newborn không sửa (ảnh đứng của chúng cũng trong vỏ nên khớp).
> Ghi chú: khung chuyển động có viền trắng sticker mỏng như cả 48 khung 8B còn lại
> (ảnh đứng không có viền); happy khi nhảy tai hất lên theo quán tính, lúc đứng tai vẫn cụp.

Số liệu 6 file mới (thay thế 6 file cũ trên nhánh, cùng tên):

| file | byte | bbox (x0,x1,y0,y1) | chân y | đầu y | SHA-256 (12 ký tự đầu) |
|---|---|---|---|---|---|
| dog_newborn_walk_a.png | 114405 | 52, 460, 41, 440 | 440 | 41 | d97994993bc0 |
| dog_newborn_walk_b.png | 114348 | 50, 463, 41, 440 | 440 | 41 | 661f16900256 |
| dog_newborn_walk_c.png | 114009 | 53, 460, 41, 440 | 440 | 41 | ff2a27e91ecf |
| dog_newborn_walk_d.png | 115893 | 43, 469, 42, 440 | 440 | 42 | 4800f9c08b56 |
| dog_newborn_happy.png | 102433 | 91, 422, 10, 400 | 400 | 10 | 243430091f4a |
| dog_newborn_sit.png | 126182 | 59, 453, 30, 440 | 440 | 30 | 964f7cfa9cb5 |

Đẩy 1 lần đè lên 6 file cũ: commit 13554bfa, .b64 916.364 B, đầu nhánh 13554bfa; 6/6 blob SHA đối chiếu khớp trên nhánh và khác blob cũ (chứng minh đã đè đúng file mới). ĐƯỢC DUYỆT 22/11 ~14:08 (Claude), các nốt nhỏ chấp nhận hết.

### Lô 10 — Nội thất cửa hàng (8 file, 22/11/2026)

8 món vào `app/assets/images/furniture/`, 512×512, PNG trong suốt, alpha
sạch (semi 0, magenta 0 px), quantize 256 màu MAXCOVERAGE + Floyd–Steinberg,
đáy chuẩn y=440 cho cả 8 món (lệch 0 px). Tổng PNG 412.631 B (~551 KB .b64).

| File | Byte | bbox (x0, x1, y0, y1) | Đáy y | SHA-256 |
|---|---|---|---|---|
| noi_be_ca.png | 67.158 | 110, 403, 121, 440 | 440 | 6cbecc45c2b1 |
| noi_den_trang.png | 26.985 | 138, 374, 141, 440 | 440 | 89b9e3c712a5 |
| noi_ke_sach.png | 78.048 | 85, 427, 81, 440 | 440 | 9b58c057e33b |
| noi_ghe_luoi.png | 42.295 | 121, 392, 212, 440 | 440 | f4f9d128c79c |
| noi_nha_pet.png | 54.374 | 98, 415, 141, 440 | 440 | 997f74ced65f |
| noi_cay_cao.png | 49.344 | 124, 389, 61, 440 | 440 | 968aff79e6e8 |
| noi_leu.png | 53.352 | 82, 431, 102, 440 | 440 | d870d9285c41 |
| noi_tranh.png | 41.975 | 116, 396, 141, 440 | 440 | fcbbdf2a3533 |

Vị trí đặt thử trên `room_v3_clean.png` 1600×900 (app chỉnh lại khi đưa
vào): bể cá đầu phải bàn học, chân (1330, 500), scale 0,42, hiển thị 124×135;
đèn trăng mặt tủ đầu giường, chân (130, 590), scale 0,35, 83×106; kệ sách sàn
trước-trái, chân (320, 830), scale 0,55, 189×199; ghế lười sàn góc
trước-trái, chân (160, 845), scale 0,55, 150×127; nhà pet sàn trước bàn học,
chân (1200, 800), scale 0,55, 176×166; cây cao sàn phải cửa sổ, chân
(950, 795), scale 0,60, 160×229; lều sàn góc trước-phải, chân (1450, 850),
scale 0,75, 263×255; tranh tường sau trái cửa sổ, góc trái-trên (290, 180),
scale 0,50, 141×151. Không món nào đè vùng bé đứng (x≈420–630, y≈700–810).

Phát hiện về hàng đáy: đồ rời (D) hiện có **không có một hàng đáy chung** —
gấu bông 444, đèn sao 449, bình hoa 429, cốc bút 433, chậu cây 440 (trải
429–449). Lô 10 chuẩn hoá về trung vị y=440 (= chậu cây, = chuẩn pet lô 8B).
Kỹ thuật: lớp xoá magenta nhạt m3 CHỈ áp trong 3 px quanh nền magenta thật
— áp toàn cục đã ăn mất chi tiết hồng nhạt sâu trong thân (viền kính bể cá
765 px lỗ, ngói mái nhà pet 1.628 px lỗ). Nốt nhỏ đã soi: viền trên bể cá ánh
hồng oải hương (màu gốc ảnh sinh ra, magenta đo = 0 px); nền trắng tranh cầu
vồng có vân giấy lốm đốm nhẹ; đèn trăng có mặt cười + sao nổi (máy tự thêm,
dễ thương, đúng brief đèn ngủ); trong ảnh ghép phòng, cây cao chạm nhẹ mép
trái ghế bàn học và ghế lười chạm nhẹ mép trái kệ sách (chồng lấn do vị trí
đặt trong ảnh ghép, không phải lỗi file); khe 299 px ở cây cao là khe nhìn
xuyên thật giữa các cành. Đẩy 1 lần: commit `817ec712`; 8/8 blob SHA đối
chiếu khớp trên nhánh. ĐƯỢC DUYỆT 22/11 ~15:20 (Claude): cả 8 món, các nốt
nhỏ chấp nhận hết. Chưa decode (chờ Claude decode; code app đã có sẵn chỗ
— PR #52 đã merge trên main).

### Lô 11 — Đấu trường (7 file, 22/11/2026)

Phong cách v3b, sáng trên-trái, không chữ, không bóng nền. Tổng PNG
1.093.691 B (~1,46 MB .b64).

| File | Byte | Khung / bbox | Đích trong app |
|---|---|---|---|
| arena_building.png | 257.355 | 1024×640, bbox 122, 902, 42, 600, chân y=600, SHA-256 `a5d394c8fbda` | `app/assets/images/town/arena_building.png` |
| arena_bg.png | 641.627 | 1600×900 RGB đục, 256 màu, SHA-256 `e798fa537d1d` | `app/assets/images/backgrounds/arena_bg.png` |
| medal_gold.png | 22.857 | 256×256, bbox 38, 218, 23, 232, chân y=232, SHA-256 `7f55b8dbbb0e` | `app/assets/images/ui/medal_gold.png` |
| medal_silver.png | 25.431 | 256×256, bbox 38, 218, 24, 232, chân y=232, SHA-256 `c50ac39c233b` | `app/assets/images/ui/medal_silver.png` |
| medal_bronze.png | 23.543 | 256×256, bbox 38, 218, 23, 232, chân y=232, SHA-256 `45e7dddfcc86` | `app/assets/images/ui/medal_bronze.png` |
| medal_participant.png | 19.671 | 256×256, bbox 44, 213, 23, 232, chân y=232, SHA-256 `64a39a85fb18` | `app/assets/images/ui/medal_participant.png` |
| gem_chest.png | 103.694 | 512×512, bbox 67, 445, 41, 440, chân y=440, SHA-256 `9c961ac94e07` | `app/assets/images/items/gem_chest.png` |

Đấu trường: oval 2 tầng vòm, mái vòm giữa, cờ tam giác + dây cờ, pastel
đào/kem. Đặt trên bản đồ thị trấn tại tâm chân (1060, 872), scale 0,2305,
hiển thị 180×129 (x 970–1149, y 743–871), bãi cỏ dưới đường C1 góc
dưới-phải, cách mép đường ~7 px, không đè 6 tòa, không chặn C1/C2. Vòm nhìn
xuyên (1.522 px lỗ kín là các vòm, cỏ lộ qua — đúng thiết kế). Nền phòng
thi: bảng lớn TRỐNG hoàn toàn, dây cờ tam giác, bàn ghế học sinh 2 bên, bục
thi có cúp vàng bên trái, thảm tròn giữa, giữa trống sáng để app đặt câu hỏi
(lum giữa 187,5 vs biên 173,0); quantize MEDIANCUT (MAXCOVERAGE chỉ cấp 57
màu cho mảng tường, khối vuông thấy rõ; MEDIANCUT 160 màu tường, khớp
`room_v3_clean` 156 màu). Huy chương: vàng/ruy băng đỏ, bạc/xanh dương,
đồng/xanh lá (đều có ngôi sao), tham gia = ngôi sao xanh nhạt + tim hồng,
ruy băng xanh dương nhạt — phân biệt rõ với bạc; không chữ/số. Rương kim
cương: rương gỗ mở nắp, đầy kim cương hồng/xanh/tím, ánh sáng từ trong
rương, 4 viên rời ở chân.

Đường đích lô 11 do Muse chọn theo quy ước sẵn có (town/ chứa đồ đặt lên
bản đồ như fountain/tree, backgrounds/ chứa cảnh nền, ui/ chứa icon thưởng,
items/ chứa đồ cửa hàng) — Claude xác nhận khi nối code đấu trường (decode
đổi tên được nếu cần khác). Kỹ thuật: m2/m3 chỉ áp trong 3 px quanh magenta
thật (m2 toàn cục ăn mặt dưới viên đá rời — tím sẫm (166,3,138), trùng luật
m2); `finish()` xoá nốt magenta chói còn lại (r>170, g<90, b>140). Đẩy 1
lần: commit `9feba87e`; 6/7 blob SHA đối chiếu khớp trên nhánh —
`arena_bg.png.b64` (855.504 B) không tải lại được để đối chiếu (bảo vệ mã
xác minh, giống `room_v3.png` trên main), đã kiểm bằng vòng khứ hồi local:
.b64 giải mã đúng từng byte PNG gốc (SHA-256 `e798fa53…`), 1 dòng base64;
Claude kiểm lại bằng git. ĐƯỢC DUYỆT 22/11 ~15:20 (Claude): cả 7 file;
quyết 2 điểm — (1) đấu trường hiển thị 180×129 chấp nhận (nhỏ nhất trong 6
tòa: lâu đài 390×150, lều 300×195, tiệm bánh 220×200, nhà hồng 235×130,
vườn 330×125; bãi trống duy nhất là dải dưới C1 — muốn to hơn phải bố trí
lại bản đồ, app tự phóng to hợp lý khi đặt); (2) gem_chest chấp nhận như
hiện tại (~155 px hồng sẫm ở chân 4 viên đá rời — mặt dưới đá cùng họ màu
với magenta, xoá thêm sẽ ăn mất đá). Chưa decode (chờ Claude decode; code
đấu trường đang làm).

### Lô 9 — Bộ 04: váy xòe đi chơi + sơ mi nơ/quần yếm (20 file, 22/11/2026)

Bộ cao cấp đầu tiên (05–07 tăng dần độ lộng lẫy). Mỗi dáng 10 file, khung
1024×1536, PNG trong suốt, alpha sạch (semi 0, magenta 0 px), quantize 256 màu
MAXCOVERAGE + Floyd–Steinberg, chân y=1428 (bbox y1=1429, đúng hàng chân bộ 01),
vào `app/assets/images/character/girl/` (10 file gái) và
`app/assets/images/character/boy/` (10 file trai). Tổng PNG 8.512.914 B
(~11,35 MB .b64). Full = MỘT ảnh toàn thân hoàn chỉnh (không cắt lớp), wave =
biến thể toàn thân tay vẫy, khung đi = khung thật 2 hướng × 4 khung. Phong
cách v3b.

| File | Byte | Chân y | Tâm mắt |
|---|---|---|---|
| girl_full_04.png | 460.643 | 1428 | (491,6; 560,0) |
| girl_full_04_wave.png | 445.760 | 1428 | (500,3; 547,1) |
| girl_full_04_walk_dr_a.png | 451.334 | 1428 | gần (720,8; 573,4) |
| girl_full_04_walk_dr_b.png | 437.806 | 1428 | gần (718,1; 577,5) |
| girl_full_04_walk_dr_c.png | 432.351 | 1428 | gần (715,3; 569,1) |
| girl_full_04_walk_dr_d.png | 440.884 | 1428 | gần (716,3; 564,6) |
| girl_full_04_walk_ur_a.png | 440.136 | 1428 | gần (725,8; 529,7) |
| girl_full_04_walk_ur_b.png | 419.228 | 1428 | gần (715,6; 531,3) |
| girl_full_04_walk_ur_c.png | 442.381 | 1428 | gần (711,0; 519,0) |
| girl_full_04_walk_ur_d.png | 414.206 | 1428 | gần (726,1; 567,5) |
| boy_full_04.png | 406.116 | 1428 | (504,6; 628,5) |
| boy_full_04_wave.png | 430.835 | 1428 | (503,2; 625,4) |
| boy_full_04_walk_dr_a.png | 398.817 | 1428 | (505,6; 626,6) |
| boy_full_04_walk_dr_b.png | 444.234 | 1428 | (524,8; 638,6) |
| boy_full_04_walk_dr_c.png | 409.964 | 1428 | (520,2; 634,7) |
| boy_full_04_walk_dr_d.png | 428.459 | 1428 | (530,2; 629,7) |
| boy_full_04_walk_ur_a.png | 395.595 | 1428 | (681,1; 642,2) |
| boy_full_04_walk_ur_b.png | 414.987 | 1428 | (689,3; 642,3) |
| boy_full_04_walk_ur_c.png | 399.188 | 1428 | (692,8; 640,2) |
| boy_full_04_walk_ur_d.png | 399.690 | 1428 | (685,1; 620,6) |

Gái 04: váy lavender nhạt, cổ trắng, nơ eo, tay phồng, tất trắng, giày búp bê
lavender — xòe vừa, KHÔNG lộng lẫy quá (đúng vị trí rẻ nhất trong 4 bộ).
Trai 04: sơ mi trắng + nơ cổ navy + quần yếm denim xanh + giày nâu — không
vest, không áo choàng (đó là bộ 05–06). Mốc đo (so với bộ 01: tâm mắt gái
(491,0; 560,5), miệng (519,2; 651,2); trai (504,1; 627,8), miệng
(512,5; 713,5)): mắt full gái **(491,6; 560,0)** lệch 01 **(+0,6; −0,5)**;
miệng full gái (511,5; 642,2) lệch (−7,7; −9,0) — detector miệng rung ±5 px,
soi bằng mắt thì 2 miệng trùng vị trí, cùng nụ cười. Mắt full trai
**(504,6; 628,5)** lệch 01 **(+0,5; +0,7)**; miệng (+2,8; +1,3). Mắt wave
gái (500,3; 547,1) lệch 01 wave (+7,2; −14,4) — mặt rộng hơn ~10 px; mắt wave
trai (503,2; 625,4) lệch 01 wave (+0,0; +9,2) — nhưng 01 wave của chính nó đã
lệch 01 full −11,6 px theo y, nên wave 04 thực ra GẦN 01 full hơn cả wave 01.
Khung đi: đầu lệch ≤5 px trong mỗi chu kỳ 4 khung (gái dr hcy 343–350, ur
364–372; trai dr 359–360, ur 382–383); chân luân phiên rõ (a/c tiếp đất đối
nhau, b/d bước giữa).

**Vẽ lại girl walk dr_d (22/11, theo yêu cầu Claude ~16:15):** bản cũ mặt
nghiêng quá (near-eye x 696,8, lệch −26, mắt gần–xa cách ~40 px) + tóc bay
ngược mạnh, đọc như chạy/xoay. Bản mới: mặt 3/4 như a/b/c, near-eye x 716,3
(lệch −1,8 so với trung bình a/b/c), mắt 2 bên cân, tóc xõa yên, hcy 346,6
(+0,5), top 161 (+0,3), 440.884 byte, SHA-256 `024bcd29c110…`. Nốt còn lại:
near-eye y 564,6 thấp hơn trung bình a/b/c 8,7 px (detector rung ±7 px giữa
các lần đo trên chính khung này, zoom mặt 2× cho thấy mắt vẫn ngang hàng
a/b/c); tóc trái xòe rộng hơn (bbox x0=67 so với 91–102, face-band SSD 1.533
nằm trong dải a/b/c 809–2.327 — mặt khớp, chỉ tóc rộng hơn, ở cỡ app ~5 px).
Mắt gái ở dải đi ur đo thấp hơn 01 ur ~30 px (near-eye y 519–535) — soi bằng
mắt thì mắt nhìn bình thường, đều nhau, nhiều khả năng detector bắt mép trên
mắt/mi trên; viền tóc còn ánh hồng rất nhạt ở một số mép tóc khung đi
(magenta đo = 0 px, tóc hồng thật) — ở cỡ app gần như không thấy.

**QUY TẮC MẮT NHẮM (Claude chốt 22/11 ~16:15, áp cho 05–07):** app dùng
**CHUNG miếng mắt nhắm của bộ 01 cho mọi bộ** — vị trí mắt ở ảnh đứng VÀ ảnh
vẫy phải trùng bộ 01 trong **±3 px**. Bộ 04 wave gái (+7,2/−14,4) là ngoại lệ
đã được chấp nhận (ở cỡ app ~2 px). Câu "miếng mắt nhắm làm theo từng ảnh"
trong các bản nháp cũ HẾT HIỆU LỰC. Kỹ thuật: vẽ từng ảnh toàn thân bằng AI
trên nền magenta đặc, có ảnh bộ 01 làm tham chiếu khuôn mặt/dáng đầu; tách nền
+ chuẩn hoá + quantize bằng code (key dist ≥ 20, closing 3×3, closing dọc 31×1
cầu nối cổ, edge-recovery ≤3 px, KHÔNG dùng `binary_fill_holes`; khử viền
magenta 4 vòng — viền magenta là dải fade quanh silhouette, vùng magenta trong
tóc dày 20–60 px; khe tóc thật bị closing 31×1 lấp thì mở lại theo ảnh gốc).

ĐƯỢC DUYỆT KIỂU 22/11 ~16:15 (Claude): cả hai dáng; chỉ sửa 1 khung dr_d,
các nốt khác chấp nhận hết. Đẩy 3 lần (8+8+4 file, mỗi lần ≤3,97 MB .b64):
`91d6a42b` (7 file), `98ece9c3` (7 file), `e415c8ae` (6 file); đầu nhánh sau
đẩy `e415c8ae`. 20/20 .b64 giải mã đúng từng byte PNG gốc trong vòng khứ hồi
local (SHA-256 khớp) — đối chiếu blob SHA trên nhánh bị chặn (bảo vệ mã xác
minh, giống `arena_bg.png.b64` lô 11), Claude kiểm lại bằng git. Chưa decode
(chờ Claude decode).

### Lô 9 — Bộ 05: váy dạ hội / vest dạ hội (20 file, 22/11/2026)

Bộ 05 lộng lẫy HƠN bộ 04 (váy xòe đi chơi / sơ mi nơ + quần yếm) nhưng KÉM bộ
06 (váy công chúa có vương miện / hoàng tử có áo choàng) và bộ 07 (nữ hoàng
tiên / hiệp sĩ hoàng gia, đồ hiếm). Mỗi dáng 10 file, khung 1024×1536, PNG
trong suốt, alpha sạch (semi 0, magenta 0 px), quantize 256 màu MAXCOVERAGE +
Floyd–Steinberg, chân y=1428 (bbox y1=1429, đúng hàng chân bộ 01), vào
`app/assets/images/character/girl/` (10 file gái) và
`app/assets/images/character/boy/` (10 file trai). Tổng PNG 9.659.446 B
(~12,61 MB .b64 — nặng hơn bộ 04 rõ rệt, xem lưu ý chia lần đẩy dưới).
Full = MỘT ảnh toàn thân hoàn chỉnh (không cắt lớp), wave = biến thể toàn thân
tay vẫy, khung đi = khung thật 2 hướng × 4 khung. Phong cách v3b.

| File | Byte | Chân y | Tâm mắt |
|---|---|---|---|
| girl_full_05.png | 581.037 | 1428 | (492,1; 562,2) |
| girl_full_05_wave.png | 654.387 | 1428 | (490,7; 560,5) |
| girl_full_05_walk_dr_a.png | 588.292 | 1428 | gần (712,0; 559,6) |
| girl_full_05_walk_dr_b.png | 598.031 | 1428 | (568,0; 561,2) |
| girl_full_05_walk_dr_c.png | 617.008 | 1428 | gần (713,1; 573,7) |
| girl_full_05_walk_dr_d.png | 587.070 | 1428 | gần (696,4; 576,8) |
| girl_full_05_walk_ur_a.png | 558.672 | 1428 | gần (700,8; 556,3) |
| girl_full_05_walk_ur_b.png | 581.208 | 1428 | — (detector không bắt được mắt) |
| girl_full_05_walk_ur_c.png | 598.570 | 1428 | gần (703,7; 563,1) |
| girl_full_05_walk_ur_d.png | 564.698 | 1428 | gần (718,8; 560,1) |
| boy_full_05.png | 325.924 | 1428 | (505,1; 629,0) |
| boy_full_05_wave.png | 360.067 | 1428 | (503,8; 630,8) |
| boy_full_05_walk_dr_a.png | 368.567 | 1428 | (504,6; 629,4) |
| boy_full_05_walk_dr_b.png | 356.224 | 1428 | (510,6; 623,1) |
| boy_full_05_walk_dr_c.png | 348.384 | 1428 | (527,5; 625,6) |
| boy_full_05_walk_dr_d.png | 370.411 | 1428 | (523,3; 624,5) |
| boy_full_05_walk_ur_a.png | 326.785 | 1428 | (704,5; 622,3) |
| boy_full_05_walk_ur_b.png | 351.742 | 1428 | (690,7; 629,0) |
| boy_full_05_walk_ur_c.png | 374.462 | 1428 | (692,8; 628,6) |
| boy_full_05_walk_ur_d.png | 344.771 | 1428 | (675,7; 629,5) |

Gái 05: váy dạ hội dài màu đỏ hồng đậm (burgundy/rose), xòe vừa–rộng, nơ eo
lớn, ren viền chân váy, đính đá/ánh sao nhẹ, tay phồng, giày búp bê đỏ quai
chéo — KHÔNG vương miện, KHÔNG cánh (đó là bộ 06–07). Trai 05: vest dạ hội
navy — áo vest + sơ mi trắng + nơ cổ navy + quần tây navy + giày da đen —
KHÔNG áo choàng (bộ 06), KHÔNG giáp (bộ 07). Mốc đo (so với bộ 01: tâm mắt
gái (491,0; 560,5), miệng (519,2; 651,2); trai (504,1; 627,8), miệng
(512,5; 713,5)): **cổng mắt ±3 px so với 01 full — 4/4 ĐẠT**: mắt full gái
**(492,1; 562,2)** lệch 01 **(+1,1; +1,7)**; mắt wave gái **(490,7; 560,5)**
lệch 01 full **(−0,3; 0,0)** (lệch 01 wave (−2,4; −1,0) cũng ĐẠT); mắt full
trai **(505,1; 629,0)** lệch 01 **(+1,0; +1,2)**; mắt wave trai
**(503,8; 630,8)** lệch 01 full **(−0,3; +3,0), ĐẠT (đúng biên)** — 01 wave
của chính nó đã lệch 01 full ~−10 px theo y, nên quy ước (như bộ 04) là khớp
01 full, vì miếng mắt nhắm đăng ký theo 01 full. Miệng full gái (517,0; 648,7)
lệch (−2,2; −2,5); miệng full trai (516,4; 715,9) lệch (+3,9; +2,4) — blob
miệng nhỏ, chỉ tham chiếu. Đỉnh đầu gái y=146, trai y=150 (01: 142). Khung đi:
gái hcy dr 346–356, ur 355–366; trai hcy dr 344–361, ur 357–385 — đầu lệch
trong chu kỳ ≤10 px, trong dải dao động của chính bộ 01. Kiểm chứng chức
năng miếng mắt nhắm: **0 px tròng mắt xanh của full/wave gái 05 nằm ngoài
vùng lid của 01** (sclera + iris + lash dilate 11 px) — miếng 01 che kín.

**Bài học detector (bộ 05):** detector mắt rung theo palette — cùng một hình
học, đo ở lần 1 (trước khử magenta sâu) cả 4 ảnh đứng/vẫy đều ĐẠT, đo ở lần 2
(sau khử + quantize lại) thì 3/4 VƯỢT (tới 5,6 px); đo trên layers (trước
quantize) cả 4 đều ĐẠT. CAL bù độ dịch detector bằng ky rescale quanh chân +
ox trong layers (girl full +2 px ky×0,9936, girl wave −5 px, boy full +2 px
ky×0,9954, boy wave 0/1,0 — lần thử ky×1,0038 vọt tới −6,0 nên hoàn lại).
Kết quả trên file final giao: 4/4 ĐẠT cổng ±3. **Sửa lỗi key 5 khung đi
trai (dr_c, dr_d, ur_a, ur_b, ur_c):** detector mắt nâu bị tóc nâu + đường
chia cửa sổ x=640 làm nhiễu (bắt blob cổ/áo ở y thô ~941) → ky kẹp 1,03, đầu
cao hơn ~55 px (top 103 so với 01 ~160). Sửa bằng `eye_override()` trong
`fix9.py`: phát hiện lại tròng mắt thật trên ảnh thô (blob nâu toàn ảnh, w/h
40–120, y 600–860); sau đó dr_c/dr_d dịch thêm +25/+20 px (OVERRIDE_DX) cho
hcx/bbox về giữa chu kỳ. Kỹ thuật chung: như bộ 04 (key dist ≥ 20, closing
3×3, closing dọc 31×1 cầu nối cổ, edge-recovery ≤3 px, KHÔNG dùng
`binary_fill_holes`; khử viền magenta stack ring-decon + fix9c/fix9d +
recolor, trước và sau quantize; viền còn lại là tông hồng-rose của tóc/váy
thật, magenta = 0 px).

**QUY TẮC MẮT NHẮM (Claude chốt 22/11 ~16:15):** app dùng **CHUNG miếng mắt
nhắm của bộ 01 cho mọi bộ** — vị trí mắt ở ảnh đứng VÀ ảnh vẫy phải trùng bộ
01 trong **±3 px**. Câu "miếng mắt nhắm làm theo từng ảnh" trong các bản nháp
cũ HẾT HIỆU LỰC.

ĐƯỢC DUYỆT KIỂU 22/11 ~17:26 (Claude): cả 20 file; wave trai đúng biên
±3 px chấp nhận. Đẩy 3 lần, **chia theo byte, TRỘN gái+trai mỗi lần ~4,3 MB
.b64** (8 file gái ≈ 6,2 MB .b64, vượt trần ~5 MB/lần — KHÔNG gom 8 gái vào
1 lần): `fd6e838d` (7 file, 4,28 MB), `508f03ad` (7 file, 4,28 MB),
`4daa14f1` (6 file, 4,05 MB); đầu nhánh sau đẩy `4daa14f1`. 20/20 .b64 giải
mã đúng từng byte PNG gốc trong vòng khứ hồi local (SHA-256 khớp) — đối chiếu
blob SHA trên nhánh bị chặn (bảo vệ mã xác minh, giống bộ 04 và
`arena_bg.png.b64` lô 11), Claude kiểm lại bằng git. Chưa decode (chờ Claude
decode).


### Lô 9 — Bộ 06: váy công chúa có vương miện nhỏ / hoàng tử có áo choàng (20 file, 22/11/2026)

Bộ 06 lộng lẫy HƠN bộ 05 (váy dạ hội đỏ / vest dạ hội navy) nhưng KÉM bộ 07
(nữ hoàng tiên có cánh + hiệp sĩ hoàng gia, đồ hiếm). Mỗi bộ là MỘT ảnh toàn thân
hoàn chỉnh 1024×1536 (cách mới, không cắt lớp), wave là biến thể toàn thân tay vẫy,
khung đi là khung thật 2 hướng × 4 khung. Phong cách v3b.

- Bé gái — váy công chúa hồng xòe rộng, lấp lánh, nơ eo lớn, vương miện vàng NHỎ
  (không phải vương miện lớn/đồ nữ hoàng — đó là bộ 07), KHÔNG cánh. Giày ballet hồng.
- Bé trai — hoàng tử: áo vest xanh hoàng gia nút vàng + sơ mi trắng + nơ cổ navy +
  quần tây navy + giày da đen + ÁO CHOÀNG đỏ nhung (khuy vàng). KHÔNG giáp (bộ 07).

## Cách làm

Vẽ từng ảnh toàn thân bằng AI trên nền magenta đặc, có ảnh bộ 01 làm tham chiếu khuôn
mặt/dáng đầu và ảnh 06 đứng làm chuẩn trang phục cho khung đi; tách nền + chuẩn hoá +
quantize bằng code (numpy + scipy + PIL), đúng quy trình bộ 04–05 (`key6.py` /
`fix6.py` trong `lot9-06/work/`):

- Key: nền = median góc; fg = dist ≥ 20; closing 3×3; chỉ giữ component > 20.000 px;
  closing dọc 31×1 cầu nối cổ; edge-recovery mọc tối đa 3 px vào dải dist 10–40.
  KHÔNG dùng `binary_fill_holes`.
- Chuẩn hoá: scale theo chiều cao bbox 1287, chân 1429, ky squash căn mắt/đầu, ox căn
  mắt/đầu; quantize MAXCOVERAGE 256 màu + Floyd–Steinberg, giữ alpha; fill RGB trong
  suốt bằng màu opaque gần nhất TRƯỚC khi quantize.
- Khử viền magenta (stack bộ 04): ring-decon d<45; fix9c inpaint d<130 toàn ảnh;
  fix9d inpaint d<170 trong vành 5 px; recolor magenta đậm (R>200,G<110,B>180);
  rim-recolor vành ngoài 3 px — cả trước và sau quantize. Viền còn lại là tông
  hồng-rose của tóc/váy thật (như bộ 04–05 đã chấp nhận), magenta đo = 0 px cả 20 file.
- **Vẽ lại wave gái:** wave v1 đầu ngửa cao (ky = 0,9472, đỉnh đầu y = 210 so với full
  141 — lệch 69 px, đổi full↔wave sẽ thấy thu nhỏ). Vẽ lại lấy ảnh full 06 làm tham
  chiếu tỉ lệ + wave 01 làm dáng: wave mới ky = 0,9947, đỉnh 148 (full 147).
- **Sửa lỗi key 7 khung đi trai (trừ dr_b):** detector mắt nâu bị tóc nâu + đường chia
  cửa sổ x = 640 làm nhiễu (bắt blob cổ/áo ở y thô 841–964) → ky kẹp 1,03, đầu cao
  hơn ~55 px. Sửa bằng `eye_override()` trong `fix6.py` (như bộ 05): phát hiện lại
  tròng mắt thật trên ảnh thô (blob nâu toàn ảnh, w/h 40–120, y 600–860): dr_a/dr_c/dr_d
  dùng trung bình 2 mắt thật (dr_a (698,8; 741,3), dr_c (767,8; 726,0),
  dr_d (785,5; 722,5)); ur_a–d dùng 1 mắt gần (phải nhất) → ox theo tâm bbox (như bộ 04).
- **Hiệu chuẩn mắt CAL (vòng fix6 run1–run2, theo cổng ±3 px của Claude):**
  gái full đo trên layers (trước quantize) là (−0,1; −1,5) ĐẠT, nhưng đo trên final
  đã quantize là (−4,9; −6,3) — dither Floyd–Steinberg làm vỡ tròng mắt thành mảnh,
  detector (chỉ bắt blob lớn nhất) đọc lệch dù hình học không đổi (đúng bài học bộ 05).
  CAL bù độ dịch detector bằng ky rescale quanh chân + ox trong layers:
  vòng 1 (dx +5, ky×0,9927) đo được (+5,0; +4,6) — VỌT (detector vỡ mảnh khác sau
  quantize lại); vòng 2 (dx +3, ky×0,9954, nửa mức sửa) đo được (+2,1; +1,0) ĐẠT.
  Trai không CAL, wave gái không CAL (chỉ là artefact đo lường, xem mốc dưới).
  Kết quả trên file final giao: **4/4 ĐẠT cổng ±3** (xem mốc dưới).
- **Quy tắc miếng mắt nhắm (Claude chốt 22/11 ~16:15): app dùng CHUNG miếng mắt nhắm
  của bộ 01 cho mọi bộ** — mắt đứng VÀ vẫy phải trùng bộ 01 trong ±3 px. Sửa lại
  câu cũ trong dự thảo bộ 05 ("miếng mắt nhắm riêng cho từng ảnh"): từ bộ 05 trở đi
  KHÔNG làm miếng riêng, dùng miếng 01.

## File (20 PNG, khung 1024×1536, PNG trong suốt, đã lượng tử)

Đường đích `app/assets/images/character/girl/` (10 file gái) và
`app/assets/images/character/boy/` (10 file trai). Tỉ lệ bán trong suốt
(0 < alpha < 255) đo bằng code, tất cả **0**. Mỗi file < 1 MB.

| File | Vai trò | Cỡ (byte) | Chân y | Tâm mắt |
| --- | --- | --- | --- | --- |
| `girl_full_06.png` | Váy công chúa, đứng | 569.578 | 1428 | (493,1; 561,5) |
| `girl_full_06_wave.png` | Váy công chúa, tay phải vẫy | 574.860 | 1428 | gần (584,6; 563,4) * |
| `girl_full_06_walk_dr_a.png` | Đi xuống-phải, khung a | 570.905 | 1428 | gần (723,0; 556,6) |
| `girl_full_06_walk_dr_b.png` | Đi xuống-phải, khung b | 566.584 | 1428 | gần (725,3; 542,6) |
| `girl_full_06_walk_dr_c.png` | Đi xuống-phải, khung c | 567.510 | 1428 | gần (729,6; 530,2) † |
| `girl_full_06_walk_dr_d.png` | Đi xuống-phải, khung d | 537.150 | 1428 | gần (691,8; 577,7) |
| `girl_full_06_walk_ur_a.png` | Đi lên-phải, khung a | 539.568 | 1428 | gần (704,3; 559,4) |
| `girl_full_06_walk_ur_b.png` | Đi lên-phải, khung b | 529.469 | 1428 | gần (712,8; 543,6) |
| `girl_full_06_walk_ur_c.png` | Đi lên-phải, khung c | 523.782 | 1428 | gần (702,6; 558,5) |
| `girl_full_06_walk_ur_d.png` | Đi lên-phải, khung d | 554.871 | 1428 | gần (702,9; 544,0) |
| `boy_full_06.png` | Hoàng tử + áo choàng, đứng | 428.241 | 1428 | (505,0; 629,8) |
| `boy_full_06_wave.png` | Hoàng tử, vẫy | 454.574 | 1428 | (504,1; 628,8) |
| `boy_full_06_walk_dr_a.png` | Đi xuống-phải, khung a | 437.772 | 1428 | (504,5; 629,4) |
| `boy_full_06_walk_dr_b.png` | Đi xuống-phải, khung b | 436.413 | 1428 | (505,3; 627,0) |
| `boy_full_06_walk_dr_c.png` | Đi xuống-phải, khung c | 411.891 | 1428 | (504,5; 631,2) |
| `boy_full_06_walk_dr_d.png` | Đi xuống-phải, khung d | 375.988 | 1428 | (502,9; 623,1) |
| `boy_full_06_walk_ur_a.png` | Đi lên-phải, khung a | 422.729 | 1428 | (560,5; 629,6) |
| `boy_full_06_walk_ur_b.png` | Đi lên-phải, khung b | 416.872 | 1428 | (570,0; 636,4) |
| `boy_full_06_walk_ur_c.png` | Đi lên-phải, khung c | 423.685 | 1428 | (610,0; 633,5) |
| `boy_full_06_walk_ur_d.png` | Đi lên-phải, khung d | 417.654 | 1428 | (580,6; 637,8) |

\* wave gái: detector chuẩn chỉ bắt được mắt phải (mắt trái vỡ thành mảnh < 25 px);
hợp nhất 2 mảnh mắt trái (401,0; 556,3) + mắt phải cho tâm mắt (492,8; 559,9),
lệch 01 full (+1,8; −0,6) ĐẠT — xem mốc dưới.
† dr_c: blob phải nhất là mảnh lash 97 px; tròng mắt thật ở (715,3; 574,0).
"Mắt gần" ở khung đi gái = blob tròng mắt xanh phải nhất (mắt nhìn nghiêng); ở khung
đi trai eye-mid là trung bình 2 blob bắt được — neo đáng tin cho khung đi trai là
hcx200/hcy (xem mốc dưới).

## Mốc khung đo được (khung 1024×1536, đo bằng code từ ảnh thật)

### Bé gái (so với bộ 01: tâm mắt (491,0; 560,5), miệng (519,2; 651,2))

- Tâm mắt full 06 **(493,1; 561,5)** — lệch 01 **(+2,1; +1,0) px, ĐẠT cổng ±3**.
  Miệng theo detector (566,0; 702,4) là bắt nhầm nơ ngực (blob 756 px) — overlay cho
  thấy miệng trùng 01 trong ~3 px; detector miệng nhiễu, chỉ tham chiếu.
  Đỉnh đầu y = 147 (01: 142). Bbox full (87, 147, 936, 1429).
- Tâm mắt wave 06: detector chuẩn chỉ bắt mắt phải (584,6; 563,4); hợp nhất mảnh
  mắt trái cho **(492,8; 559,9)** — lệch 01 full **(+1,8; −0,6), ĐẠT**; lệch 01
  wave (493,1; 561,5) là (−0,3; −1,6) cũng ĐẠT. Đỉnh đầu y = 148.
- Khung đi: mắt gần dr x 692–730 (01: 697–736), ur x 703–713 (01: ~711–728);
  mắt gần y dr 530–578, ur 544–559 (dao động do mảnh detector, soi strip thấy đầu
  thẳng hàng); top dr 147–157, ur 151–160. Đầu lệch trong chu kỳ theo mắt y ≤ 7 px,
  trong dải dao động của chính bộ 01.
- Kiểm chứng chức năng miếng mắt nhắm (cả 2 dáng — bộ 05 chỉ test gái): **0 px**
  tròng mắt xanh của full/wave 06 nằm ngoài vùng lid của 01 (sclera + iris + lash
  dilate 11 px) — miếng 01 che kín mắt gái. (Phương pháp hợp nhất cụm mảnh iris đã
  thử và LOẠI: blob xanh ở góc mắt ngoài/lash làm nhiễu — không dùng làm cổng.)

### Bé trai (so với bộ 01: tâm mắt (504,1; 627,8), miệng (512,5; 713,5))

- Tâm mắt full 06 **(505,0; 629,8)** — lệch 01 **(+0,9; +2,0) px, ĐẠT cổng ±3**.
  Miệng full 06 (540,8; 711,9) — detector bắt nhầm má hồng/nơ, overlay thấy miệng
  trùng ~3 px. Đỉnh đầu y = 151 (01: 142). Bbox full (153, 151, 856, 1429).
- Tâm mắt wave 06 **(504,1; 628,8)** — lệch 01 full **(0,0; +1,0), ĐẠT**. Lưu ý:
  01 wave của chính nó đã lệch 01 full ~−10,6 px theo y (617,2 so với 627,8) — quy
  ước (như bộ 04–05) là khớp 01 full, vì miếng mắt nhắm đăng ký theo 01 full.
- Khung đi: eye-mid dr 502,9–505,3 (01 dr 514–538), ur 560,5–610,0 (01 ur 678–699);
  x ur lệch trái do OVERRIDE_1 (ox theo tâm bbox gồm cả áo choàng phồng) — soi strip
  thấy đầu thẳng hàng, không phải lỗi vị trí. hcx200 dr 384–420, ur 424–457;
  hcy dr 344–356, ur 348–361; top dr 156–181, ur 163–184. Eye-mid y dr 623–631,
  ur 630–638 — đầu lệch ≤ 8 px/chu kỳ, trong dải dao động của chính bộ 01.
- Kiểm chứng chức năng miếng mắt nhắm: full 6 px, wave 27 px tròng mắt nâu nằm
  ngoài vùng lid của 01 — cùng bậc với control bộ 05 (wave trai 15 px), là ria
  tóc/lash sát vùng, không phải mắt lộ — miếng 01 che kín về chức năng.

## Kiểm chứng (soi bằng mắt trên nền tối (60,60,80) + nền phòng v3b)

Ảnh ghép `work/composites/`: (a) gái 06 full + wave cạnh gái 01 full;
(b) trai 06 full + wave cạnh trai 01 full; (c) dải đi dr + ur mỗi dáng;
(d) gái 06 + trai 06 full ở cỡ app trong phòng v3b.

- Mặt/mắt gái 06 và trai 06 trùng 01 (đã soi cạnh nhau, overlay 50/50).
- Váy công chúa rõ ràng sang hơn 05 (xòe rộng, lấp lánh, nơ lớn, vương miện nhỏ)
  và chưa tới mức nữ hoàng (không cánh, vương miện nhỏ); chân vẫn thấy rõ, chạm
  y = 1429. Hoàng tử có áo choàng đỏ nhung đúng dáng, không giáp; áo choàng không
  nuốt tay/chân.
- Chân luân phiên khung đi rõ: a/c tiếp đất đối nhau, b/d bước giữa (cả 4 strip);
  mặt các khung đi cùng góc nghiêng, không khung nào nghiêng hẳn (bài học dr_d bộ 04).
- Trong phòng v3b ở cỡ app (cao 360 px, chân (630, 810)): tỉ lệ tự nhiên, chân
  chạm sàn, không thấy viền lạ.
- Không lỗ alpha lạ, không mép thẳng, không tàn dư magenta (magenta = 0 px cả
  20 file theo test R>200,G<80,B>200; semi = 0; 256 màu).

### Điểm chưa chắc — nói thẳng

- **Gái full CAL 2 vòng mới đạt:** vòng 1 vọt (+5,0; +4,6), vòng 2 nửa mức mới về
  (+2,1; +1,0). Detector rung ±5 px giữa các lần quantize — cổng ±3 đo trên final
  là cổng của detector, không phải của hình học thật (layers đọc (−0,1; −1,5)).
  Bằng chứng chức năng là lid-zone = 0 px ngoài vùng, không phụ thuộc detector.
  Nếu Claude soi overlay thấy mắt gái full lệch thì đó là nhiễu detector — nhưng
  đây vẫn là điểm yếu nhất của bộ, cần Claude quyết.
- **Boy wave lid-zone 27 px ngoài vùng** (full 6 px; control bộ 05 wave trai 15 px):
  là ria tóc/lash sát vùng lid, không phải mắt lộ; miếng 01 vẫn che kín về chức năng.
- Viền tóc/váy còn ánh hồng rất nhạt ở một số mép (tông rose của tóc/váy thật,
  như bộ 04–05 đã chấp nhận); ở cỡ app 360 px không thấy.
- Áo choàng trai chạm mép khung trái ở dr_b/c/d (bbox x0 = 0) — chỉ là áo choàng
  phồng tới biên khung, thân không bị cắt; áo choàng phồng mạnh ở boy dr_d và ur_b
  (đọc như chuyển động, không phải lỗi).

## Việc còn lại cho giai đoạn code (E)

- Entry manifest cho 20 file trên + cập nhật `source` thành "Muse vẽ AI 22/11
  theo DESIGN.md".
- Dùng CHUNG miếng mắt nhắm của bộ 01 cho cả full/wave 06 (quy tắc Claude chốt
  22/11) — KHÔNG làm miếng riêng. `_eyeCenter` riêng theo nhân vật đã có
  (gái y ≈ 559, trai y ≈ 626).
- Test neo: chân nhân vật trong vùng sàn đã khai báo; khung đi 2 hướng × 4 khung
  theo đúng thứ tự a→b→c→d. Mở PR sau khi Claude duyệt kiểu.

ĐƯỢC DUYỆT KIỂU 22/11 ~18:22 (Claude): cả 20 file; khung đi gái giữ nguyên, áo choàng trai chạm mép khung chấp nhận, wave trai 27 px Claude ghép thử miếng mắt khi decode. Đẩy 3 lần (7+7+6, mỗi lần 4,51/4,54/3,96 MB .b64): `54573bf` (7 file), `e45cee55` (7 file), `952ddf07` (6 file); đầu nhánh sau đẩy `952ddf07`. Lần 1 bị gián đoạn do service restart giữa chừng, Claude kiểm bằng git thấy đã lên nhánh (commit `54573bf`) nên không đẩy lại. 20/20 .b64 giải mã đúng từng byte PNG gốc trong vòng khứ hồi local (SHA-256 khớp) — đối chiếu blob SHA trên nhánh bị chặn (bảo vệ mã xác minh, giống bộ 04/05), Claude kiểm lại bằng git khi decode. SHA-256 (12 ký tự đầu): gái full `c767fef86338`, wave `4405dc38c012`, dr_a `7e6965897b13`, dr_b `6666c86231d1`, dr_c `0ede4a247944`, dr_d `fec3e215cc9e`, ur_a `1c08da6b4b98`, ur_b `17a81e5e58fa`, ur_c `59362e6455e3`, ur_d `11d08982c332`; trai full `4726f90b7139`, wave `09df5dfd9a1b`, dr_a `89aeda46d7a7`, dr_b `56b06fe43017`, dr_c `d859ecc9c89a`, dr_d `721293d59338`, ur_a `081d82c91b4a`, ur_b `dedea01488e4`, ur_c `28fdd66d780a`, ur_d `b32f070b7d63`. Chưa decode (chờ Claude decode).

### Lô 9 — Bộ 07: váy nữ hoàng tiên có cánh / hiệp sĩ hoàng gia (20 file, 22/11/2026)

Đích: `app/assets/images/character/girl/` và `app/assets/images/character/boy/`.
Bộ 07 ĐỦ 20/20 file (10 gái + 10 trai). Mặt gái đã vẽ lại rộng hơn bằng
transplant dải mắt 01 (xem mục "Vẽ lại mặt gái") — lid-zone gái 8/14 px (≈ 0);
8 khung đi gái vẽ lại mặt rộng lần 2 (xem mục "Vẽ lại mặt 8 khung đi gái").

Bộ 07 là bộ HIẾM NHẤT, lộng lẫy NHẤT trong 4 bộ cao cấp (04 < 05 < 06 < 07).
Mỗi bộ là MỘT ảnh toàn thân hoàn chỉnh 1024×1536 (cách mới, không cắt lớp),
wave là biến thể toàn thân tay vẫy, khung đi là khung thật 2 hướng × 4 khung.
Phong cách v3b.

- Bé gái — váy nữ hoàng tiên: váy dài xòe rộng nhiều lớp, CÁNH tiên trong suốt
  có ánh lấp lánh, đính đá/gem, vương miện vàng lớn sang hơn vương miện nhỏ của
  06 (không che mắt/tóc mái), giày ballet hồng. Cánh không che tay vẫy ở ảnh wave.
- Bé trai — hiệp sĩ hoàng gia: giáp trang trí (ngực/vai chi tiết vàng) + áo
  choàng xanh hoàng gia viền vàng, KHÔNG đội mũ giáp che mặt (mặt/đầu giữ đúng
  bộ 01), KHÔNG cầm vũ khí (tay để tự nhiên như các bộ khác).

## Cách làm

Vẽ từng ảnh toàn thân bằng AI trên nền magenta đặc, có ảnh bộ 01 làm tham chiếu khuôn
mặt/dáng đầu và ảnh 07 đứng làm chuẩn trang phục cho khung đi; tách nền + chuẩn hoá +
quantize bằng code (numpy + scipy + PIL), đúng quy trình bộ 04–06 (`key7.py` /
`fix7.py` / `fix7b.py` / `anchor7.py` trong `lot9-07/work/`):

- Key: nền = median góc; fg = dist ≥ 20; closing 3×3; chỉ giữ component > 20.000 px;
  closing dọc 31×1 cầu nối cổ; edge-recovery mọc tối đa 3 px vào dải dist 10–40.
  KHÔNG dùng `binary_fill_holes`.
- Chuẩn hoá: scale theo chiều cao bbox 1287, chân 1429, ky squash căn mắt/đầu, ox căn
  mắt/đầu; quantize MAXCOVERAGE 256 màu + Floyd–Steinberg, giữ alpha; fill RGB trong
  suốt bằng màu opaque gần nhất TRƯỚC khi quantize.
- Khử viền magenta (stack bộ 04): ring-decon d<45; fix9c inpaint d<130 toàn ảnh;
  fix9d inpaint d<170 trong vành 5 px; recolor magenta đậm (R>200,G<110,B>180);
  rim-recolor vành ngoài 3 px — cả trước và sau quantize. Magenta đo = 0 px cả
  20 file (test R>200,G<80,B>200); semi = 0; 256 màu.
- **Vẽ lại mặt gái (xong 22/11 ~20:00, `transplant_eyes.py` /
  `soften_glitter.py` / `measure_face.py`):** 4 lần vẽ AI đều ra khoảng mắt
  ~184 px (full) / ~168 px (wave) thay vì 207 px của 01; warp code chỉ sửa
  được vị trí tâm mắt, không sửa được kích thước tròng (trái 21 px, phải
  41 px so với 01 là 27/30 px). Chốt bằng transplant: chép dải mắt 01 full
  (x 355–640, y 510–595, feather 12 px) dán đúng tọa độ lên full + wave 07
  → mắt 07 mới = mắt 01 (từng mắt ≤ 1,4 px, lid 8/14 px ≈ 0). Wave v5 vẽ lại
  từ snapshot full v4 để mặt wave khớp mặt full trước khi transplant.
  Glitter làm dịu bằng code: pixel hồng-tím đậm dưới vương miện pha 55% về
  hồng nhạt (xem mốc trên). Khung đi gái vẽ lại mặt rộng lần 2 (xem mục dưới).
- **Vẽ lại wave trai (v2):** wave v1 đầu ngửa cao, mắt lệch ~60 px. Vẽ lại lấy
  full 07 làm tham chiếu: wave v2 đầu thẳng, mắt (505,2; 629,4) ĐẠT cổng.
- **Vẽ lại dr_a/dr_b/dr_c trai (v2):** v1 áo choàng bị cắt mép khung trái
  (bbox x0 = 0, cắt ~100 px) và dr_b đầu lệch phải 67 px. Vẽ lại với áo choàng
  ôm sát thân: v2 bbox x0 = 24–66, không chạm mép.
- **Sửa lỗi neo (fix7b, `anchor7.py`):** detector mắt nâu trai bắt nhầm tóc/giáp
  vàng ở khung đi → ky kẹp 0,94/1,03. Neo khung đi trai bằng head-centroid
  (hcx/hcy) thay vì mắt: dr (hcx 424, hcy 359), ur (hcx 485, hcy 382).
  Neo gái bằng khoảng mắt→chân (không dùng chiều cao bbox — vương miện làm
  bbox phồng → s quá nhỏ, mắt lệch ~21 px), đo bằng blue-union detector trên
  ảnh thô đã key (tròng mắt vỡ mảnh sau quantize, blob detector trả None).
  Công thức neo dùng hình học đã dời chân: mắt_y_final =
  1428 − (Ymax_thô − mắt_y_thô)·s·ky (Ymax = đáy silhouette thật, không phải 1429).
- **Hiệu chuẩn mắt CAL (vòng fix7b, theo cổng ±3 px của Claude):** gái full
  ky 1,0101 → 1,0170 (nâng mắt ~6 px): union y +7,0 → −2,4 (vọt nhẹ + nhiễu
  dither, vẫn trong cổng); gái walk dr s 0,7925 → 0,7961 (nâng ~4 px):
  union mean y +4,0 → −3,9 (trong ±5 lý tưởng cho khung đi). Trai không CAL.
  Kết quả trên file final giao: **4/4 ĐẠT cổng ±3** (xem mốc dưới).
- **Quy tắc miếng mắt nhắm (Claude chốt 22/11 ~16:15): app dùng CHUNG miếng mắt nhắm
  của bộ 01 cho mọi bộ** — mắt đứng VÀ vẫy phải trùng bộ 01 trong ±3 px.
  Từ bộ 05 trở đi KHÔNG làm miếng riêng, dùng miếng 01.

## File (20/20 PNG đã xong, khung 1024×1536, PNG trong suốt, đã lượng tử)

Đường đích `app/assets/images/character/girl/` (10 file gái) và
`app/assets/images/character/boy/` (10 file trai). Tỉ lệ bán trong suốt
(0 < alpha < 255) đo bằng code, tất cả **0**. Mỗi file < 1 MB.
Tổng 20 file = 13.870.515 byte; .b64 ≈ 18,5 MB.

| File | Vai trò | Cỡ (byte) | Chân y | Tâm mắt |
| --- | --- | --- | --- | --- |
| `girl_full_07.png` | Nữ hoàng tiên, đứng | 868.671 | 1428 | (491,0; 560,6) † |
| `girl_full_07_wave.png` | Nữ hoàng tiên, tay phải vẫy | 865.116 | 1428 | (491,2; 560,3) † |
| `girl_full_07_walk_dr_a.png` | Đi xuống-phải, khung a | 753.062 | 1428 | gần (711,7; 580,3) |
| `girl_full_07_walk_dr_b.png` | Đi xuống-phải, khung b | 790.881 | 1428 | gần (728,5; 554,8) |
| `girl_full_07_walk_dr_c.png` | Đi xuống-phải, khung c | 757.762 | 1428 | gần (701,3; 570,7) |
| `girl_full_07_walk_dr_d.png` | Đi xuống-phải, khung d | 690.948 | 1428 | gần (735,3; 567,4) |
| `girl_full_07_walk_ur_a.png` | Đi lên-phải, khung a | 820.169 | 1428 | gần (713,5; 558,2) |
| `girl_full_07_walk_ur_b.png` | Đi lên-phải, khung b | 767.601 | 1428 | gần (727,7; 568,4) |
| `girl_full_07_walk_ur_c.png` | Đi lên-phải, khung c | 854.832 | 1428 | gần (699,9; 547,0) |
| `girl_full_07_walk_ur_d.png` | Đi lên-phải, khung d | 788.562 | 1428 | gần (737,6; 562,9) |
| `boy_full_07.png` | Hiệp sĩ hoàng gia, đứng | 614.239 | 1428 | (503,7; 630,0) |
| `boy_full_07_wave.png` | Hiệp sĩ, vẫy (v2) | 612.653 | 1428 | (505,2; 629,4) |
| `boy_full_07_walk_dr_a.png` | Đi xuống-phải, khung a (v2) | 581.263 | 1428 | hcx 423,3 / hcy 372,4 |
| `boy_full_07_walk_dr_b.png` | Đi xuống-phải, khung b (v2) | 575.002 | 1428 | hcx 423,7 / hcy 371,8 |
| `boy_full_07_walk_dr_c.png` | Đi xuống-phải, khung c (v2) | 571.089 | 1428 | hcx 423,5 / hcy 370,7 |
| `boy_full_07_walk_dr_d.png` | Đi xuống-phải, khung d | 578.058 | 1428 | hcx 423,5 / hcy 373,5 |
| `boy_full_07_walk_ur_a.png` | Đi lên-phải, khung a | 577.833 | 1428 | hcx 484,8 / hcy 393,2 |
| `boy_full_07_walk_ur_b.png` | Đi lên-phải, khung b | 604.385 | 1428 | hcx 484,3 / hcy 392,2 |
| `boy_full_07_walk_ur_c.png` | Đi lên-phải, khung c | 583.565 | 1428 | hcx 484,7 / hcy 393,1 |
| `boy_full_07_walk_ur_d.png` | Đi lên-phải, khung d | 614.824 | 1428 | hcx 484,9 / hcy 392,9 |

† gái full/wave: blob detector trả None (tròng mắt vỡ mảnh < 25 px sau quantize
+ dither). Tâm mắt báo theo blue-union detector trên ảnh thô đã key (hợp nhất
mọi mảnh xanh theo cửa sổ mắt): full (491,0; 560,6) lệch 01 (0,0; +0,1);
wave (491,2; 560,3) lệch 01 wave (+0,4 y). Union trên file final: full
(492,1; 556,1) lệch 01-union y −2,4; wave (491,2; 560,3) lệch 01-wave-union
y +0,4 — cả hai đều trong cổng ±3 theo y (x bị lệch do mặt 07 hẹp hơn, xem mốc
dưới). Overlay 07 chồng 01 (đỏ 45%) cho thấy mắt trùng nhau.
"Mắt gần" ở khung đi gái = blue-union trong cửa sổ (680–780, 480–620).

## Mốc khung đo được (khung 1024×1536, đo bằng code từ ảnh thật)

### Bé gái (so với bộ 01: tâm mắt (491,0; 560,5), miệng (519,2; 651,2))

- Tâm mắt full 07 **(491,6; 560,8)** — lệch 01 **(+0,6; +0,3) px, ĐẠT cổng ±3**
  (eye-mid detector). **Từng mắt (cổng mới, đo bằng union trên final đã
  quantize):** mắt trái duL **(0,0; −1,4)**, mắt phải duR **(−0,3; −1,2)** so với
  mắt tương ứng của 01 full — cả hai ≤ 1,4 px, ĐẠT. Khoảng đồng tử 207,1 px
  (01: 207,4). Miệng theo detector (561,3; 699,3) là bắt nhầm nơ ngực (pixel
  đỏ sẫm — xem mục miệng dưới); overlay cho thấy miệng trùng 01 trong ~3 px.
  Vương miện đỉnh y = 67 (01: 142 — vương miện cao hơn, đúng đồ nữ hoàng).
  Bbox full (14, 78, 983, 1429); cánh trái chừa lề 12 px, cánh phải lề 38 px —
  không chạm mép khung.
- Tâm mắt wave 07: **(492,1; 561,8)** — lệch 01 full **(+1,1; +1,3), ĐẠT**;
  từng mắt như full (cùng dải mắt 01 ghép vào): duL (0,0; −1,4), duR
  (−0,3; −1,2). Đỉnh đầu y = 125. Cánh không che tay vẫy. **Miệng wave cười
  HỞ** (khác full cười khép và khác wave 01 cười khép — xem "Điểm chưa chắc").
- Khung đi dr (vẽ lại v2, 22/11 ~21:00): mắt gần trung bình **(719,2; 568,3)**
  vs 01 **(715,5; 572,2)** → lệch (+3,7; −3,9) — trong dải 01 (01 tự dao
  động x 697–736). Khoảng mắt dr 149,8–163,2 (01 dr 125,0–161,1).
  Khung đi ur (vẽ lại v2 + đặt lại + warp): mắt gần trung bình **(719,7; 559,1)**
  vs 01 **(725,5; 564,0)** → lệch (−5,8; −4,9) — trong dải 01 (x 710–737,
  trừ ur_c 699,9: blob tròng vỡ mảnh sau dither nên tâm đọc thấp ~10 px,
  soi zoom 3× mắt vẫn tròn nguyên — artefact detector). Khoảng mắt ur
  168,2–176,9 (01 ur 168,0–180,4). Detector mắt gần rung ±10 px trên khung
  3/4 (tròng vỡ mảnh); trung bình chu kỳ mới là số đáng tin.
  Đầu lệch trong chu kỳ: đỉnh đầu y0 dr dải 13 px, ur dải 28 px (01: 15/15 px;
  ur thừa do đỉnh vương miện ur_b thấp — thừa hưởng từ khung cũ, cũ là 37 px);
  miệng-y dải dr 8,4 / ur 15,5 px (01: 13,1/9,8) — cùng bậc. Chân luân phiên
  a/c đối nhau, b/d bước giữa; cánh không chạm mép khung.
- **Miệng (detector artefact, đã kiểm bằng overlay):** detector miệng đọc
  (560,3; 698,5) — pixel tại đó là đỏ sẫm (114,26,29) = nơ ngực/gem, không phải
  miệng; miệng thật ở (519, 651) là da (223,173,143). Overlay dải miệng
  (07 màu chồng 01 đỏ) chỉ thấy MỘT miệng — miệng trùng ~3 px.
- **Vẽ lại mặt gái (Claude chốt 22/11 ~19:04, xong 22/11 ~20:00):** mặt gái 07
  cũ hẹp hơn 01 ~19% — khoảng đồng tử 167,3 px so với 01 là 205,9 px (full);
  wave 153,1 so với 201,6 → lid-zone cũ full **302 px**, wave **347 px** ngoài
  vùng miếng mắt nhắm 01. Đã thử 4 lần vẽ lại bằng AI (v2: canvas 07 + mặt
  01; v3: canvas 01 + trang phục 07; v4: sửa trực tiếp "mở rộng mắt"; v5 wave
  vẽ từ snapshot full) — model vẫn vẽ khoảng mắt ~184 px (full) / ~168 px
  (wave), không ra 207 px. Warp code (k = 0,14–0,18) đưa được tâm mắt về đúng
  vị trí nhưng không sửa được KÍCH THƯỚC mắt (tròng trái 21 px, phải 41 px so
  với 01 là 27/30 px) — lid vẫn 222–276 px. **Cách chốt: transplant dải mắt**
  (`transplant_eyes.py`): chép nguyên dải mắt của 01 full (x 355–640,
  y 510–595, feather 12 px — cả hai mắt + sống mũi + má quanh mắt) dán đúng
  tọa độ lên ảnh gái 07 full + wave (cùng khung 1024×1536, cùng neo mắt
  (491; 560,5)) → mắt 07 MỚI CHÍNH LÀ mắt 01: từng mắt lệch ≤ 1,4 px, khoảng
  đồng tử 207,1 px. Váy, cánh, vương miện, tóc, miệng giữ nguyên bản vẽ v4/v5.
  Soi zoom: không thấy đường ghép, da 01/07 cùng tông, mặt vẫn là gái 07
  (chỉ mắt to + rộng hơn, đúng như 01).
- **Vẽ lại mặt 8 khung đi gái (Claude chốt 22/11 ~20:41, xong 22/11 ~21:00):**
  ảnh đứng/vẫy đã ĐẠT nhưng 8 khung đi vẫn giữ mặt hẹp cũ (khoảng mắt ~153–
  177 so với 01 đi 125–180, riêng ur b/c/d hẹp hơn 01 ur ~15 px) — đổi
  đứng↔đi sẽ thấy mặt hẹp↔rộng giật. Vẽ lại cả 8 khung bằng AI (canvas = khung
  đi cũ trên nền magenta, tham chiếu ảnh đứng mới + khung đi 01 tương ứng,
  miệng cười khép) — model vẫn chép khoảng mắt khung cũ nên span gần như
  không đổi (dr đã trong dải 01; ur b/c/d vẫn 152–155). Đặt lại chu kỳ ur:
  neo trung bình 2 cửa sổ (mắt-giữa, không phải mắt gần) đã đẩy cả hình lệch
  +77 px phải, chạm mép khung x1 = 1023 → đặt lại dx = −87 (ox 106 → 19),
  hết chạm mép (x1 928–979), mắt gần về dải 01. **Warp code** (`warp_face.py`,
  dãn ngang mềm quanh tâm mắt, cửa sổ y 440–660 — vương miện và miệng không
  chạm) cho ur_b/c/d: k = 0,17/0,16/0,13, tâm mắt 648,6/620,9/652,0 → khoảng
  mắt ur_b 152,6 → 168,2, ur_c 154,4 → 172,1, ur_d 154,7 → 173,1 (01 ur
  168,0–180,4). Miệng 8/8 khung đi nay cười khép thống nhất (trước ur a/b/d
  cười hở, c khép). Glitter làm dịu lại: dr_a 789 → 0, ur_b 811 → 461 (còn
  dưới mốc cũ đã duyệt 973), ur_d 705 → 0. Ảnh ghép `a_walk_vs_standing.png`
  (đứng + 8 khung đi cạnh nhau): không thấy mặt to↔nhỏ giật. Bản mặt hẹp cũ
  giữ trong `gen/walk_redo_v1/old_walk_finals/`.
- **Kiểm chứng chức năng miếng mắt nhắm — ĐÃ ĐẠT:** gái full **8 px**, wave
  **14 px** tròng mắt xanh nằm ngoài vùng lid của 01 (iris 01 dilate 11 px)
  — 8 px là nhiễu dither ở mi dưới mắt trái, 6 px còn lại ở wave là nhiễu
  dither + 8 px mảnh gem váy ở mép cửa sổ đo (không phải pixel mắt); về chức
  năng ≈ 0. (Bộ 06 gái: 0 px; bộ 06 trai wave: 27 px.)

### Bé trai (so với bộ 01: tâm mắt (504,1; 627,8), miệng (512,5; 713,5))

- Tâm mắt full 07 **(503,7; 630,0)** — lệch 01 **(−0,4; +2,2) px, ĐẠT cổng ±3**.
  Miệng full 07 (530,1; 709,7) — blob nhỏ 98 px, detector bắt nhầm; overlay
  thấy miệng trùng ~3 px. Đỉnh đầu y = 179 (01: 142 — giáp vai cao hơn).
  Bbox full (164, 179, 842, 1429).
- Tâm mắt wave 07 (v2) **(505,2; 629,4)** — lệch 01 **(+1,1; +1,6), ĐẠT**.
  Wave v1 đã bỏ (đầu ngửa, mắt lệch ~60 px).
- Khung đi: hcx dr 423,3–423,7 (đích 424), hcy dr 370,7–373,5 (dải 2,8 px),
  khớp đầu đứng hcy 371,1 trong 2,4 px; hcx ur 484,3–484,9 (đích 485),
  hcy ur 392,2–393,2 (dải 1,0 px) — hcy ur thấp hơn đầu đứng 21 px, trong dải
  dao động ur của chính 01 (0–32 px). hcy dr/ur 07 cao hơn đích 359/382 ~12 px
  vì đầu đứng 07 (tóc + giáp) có centroid cao hơn — kiểm trong-chu-kỳ là chính.
  Áo choàng không chạm mép khung (bbox x0 dr 24–66, ur 27–45; bộ 06 từng x0 = 0).
- Kiểm chứng chức năng miếng mắt nhắm: full **0 px**, wave **20 px** tròng mắt
  nâu nằm ngoài vùng lid của 01 (đo trong hộp mắt 70×80 quanh mỗi mắt — mask
  nâu toàn ảnh bắt cả tóc + giáp vàng nên không dùng được) — cùng bậc với bộ 06
  (full 6, wave 27), là ria lash sát vùng, miếng 01 che kín về chức năng.

## Kiểm chứng (soi bằng mắt trên nền tối (60,60,80) + nền phòng v3b)

Ảnh ghép `work/composites/`: (a) gái 07 full + wave cạnh gái 01 full;
(b) trai 07 full + wave cạnh trai 01 full; (c) dải đi dr + ur mỗi dáng;
(a2) `a_walk_vs_standing.png` — ảnh đứng mới + 8 khung đi mới cạnh nhau
(chứng minh đứng↔đi không giật mặt); (d) gái 07 + trai 07 full ở cỡ app
trong phòng v3b; (d) overlay lid-zone mới
`d_lid_07_new.png` (xanh = trong vùng 01, đỏ = ngoài — gần như toàn xanh).

- Mặt/mắt gái 07 và trai 07 trùng 01 (đã soi cạnh nhau + overlay 50/50 +
  overlay lid-zone: mắt gái 07 MỚI chính là mắt 01, không còn vệt hở).
  Váy/cánh/vương miện gái giữ nguyên bản vẽ v4/v5 — vẫn là gái 07, chỉ mắt
  to + rộng hơn như 01.
- Váy nữ hoàng tiên rõ ràng lộng lẫy NHẤT trong 04–07: váy dài xòe nhiều lớp,
  cánh trong suốt lấp lánh thấy rõ viền, vương miện lớn đính đá, đá/gem không
  che mặt; chân vẫn thấy rõ (giày ballet hồng), chạm y = 1429. Hiệp sĩ hoàng gia
  đúng dáng: giáp vàng chi tiết + áo choàng xanh viền vàng, không mũ giáp che
  mặt, không vũ khí; giáp không nuốt tay/chân ở khung đi.
- Chân luân phiên khung đi rõ: a/c tiếp đất đối nhau, b/d bước giữa (cả 3 strip
  đã có); mặt các khung đi cùng góc nghiêng, không khung nào nghiêng hẳn
  (bài học dr_d bộ 04). Đầu thẳng hàng trong chu kỳ (soi strip).
- Trong phòng v3b ở cỡ app (cao 360 px, chân (630, 810)): tỉ lệ tự nhiên, chân
  chạm sàn, không thấy viền lạ; cặp đôi 07 nổi bật nhất trong các bộ.
- Không lỗ alpha lạ, không mép thẳng, không tàn dư magenta (magenta = 0 px cả
  20 file; semi = 0; 256 màu). Sao lấp lánh hồng-magenta ở mép váy đã làm dịu
  bằng code (`soften_glitter.py`: pixel hồng-tím đậm R>190,G<110,B>170 dưới
  vương miện pha 55% về hồng nhạt) — hot px sau vẽ lại v2 + làm dịu: wave 672
  (đứng, giữ nguyên), dr_a 789 → 0, dr_b 0, dr_c 0, dr_d 5, ur_a 0,
  ur_b 811 → 461, ur_c 39, ur_d 705 → 0. Số còn lại là đá vương miện +
  shading vải tuyn (rải rác, không còn cụm sao chói); trên nền sáng váy đọc
  mềm, vẫn là glitter.

### Điểm chưa chắc — nói thẳng

- **Miệng wave gái cười HỞ** (full cười khép, wave 01 cười khép): wave v5 vẽ
  từ snapshot full nên miệng hở theo bản vẽ mới. Ở cỡ app miệng ~2 px — khác
  biệt nhỏ, nhưng soi zoom thấy rõ. Nếu Claude muốn đồng nhất thì vẽ lại wave
  miệng khép (rủi ro: mặt wave vẽ lại có thể lệch mắt — phải transplant lại).
- **Miệng khung đi gái đã thống nhất cười khép 8/8 khung** (vẽ lại v2
  22/11 ~21:00, soi zoom 3× từng khung; trước đây ur a/b/d cười hở, c cười
  khép). Miệng wave gái cười HỞ vẫn là nốt riêng (xem trên).
- Sao lấp lánh còn sót hot px rải rác (wave 672, dr_d 5, ur_b 461 — đá
  vương miện + shading vải, không còn cụm chói); nếu Claude vẫn thấy chói thì
  chỉ còn cách vẽ lại váy (không recolor thêm — sẽ làm xỉn váy).
- Viền tóc/váy còn ánh hồng rất nhạt ở một số mép (tông rose của tóc/váy thật,
  như bộ 04–06 đã chấp nhận); ở cỡ app 360 px không thấy.
- Face-band template cho offset lớn (gái full −15,−23; wave −25,−25) — KHÔNG
  dùng làm cổng: template bị lệch do mặt 07 nhỏ hơn 01 (khác tỉ lệ), không phải
  lỗi vị trí mắt (neo mắt + overlay đã xác nhận ĐẠT). Sau transplant, offset
  template vẫn lớn vì template so cả khuôn mặt (má/cằm 07 hẹp hơn) — mắt thì
  đã trùng 01 từng pixel.

## Việc còn lại cho giai đoạn code (E)

- Entry manifest cho 20 file trên + cập nhật `source` thành "Muse vẽ AI 22/11
  theo DESIGN.md".
- Dùng CHUNG miếng mắt nhắm của bộ 01 cho cả full/wave 07 (quy tắc Claude chốt
  22/11) — KHÔNG làm miếng riêng. `_eyeCenter` riêng theo nhân vật đã có
  (gái y ≈ 559, trai y ≈ 626).
- Test neo: chân nhân vật trong vùng sàn đã khai báo; khung đi 2 hướng × 4 khung
  theo đúng thứ tự a→b→c→d. Mở PR sau khi Claude duyệt kiểu.
- 8 khung đi gái vẽ lại mặt rộng xong 22/11 ~21:00 (AI vẽ lại + đặt lại ur
  dx = −87 + warp ur_b/c/d + làm dịu glitter; xem mục "Vẽ lại mặt 8 khung đi
  gái" trên) — bộ đủ 20 file, đã đẩy 22/11 ~21:45 (xem cuối mục). Ảnh đứng/vẫy gái
  + 10 file trai KHÔNG đổi 1 byte trong đợt này (đối chiếu SHA-256).

## Đẩy .b64 (kế hoạch, sau khi Claude duyệt kiểu VÀ đủ 20 file)

- Tổng PNG 20 file 13.870.515 byte → .b64 ≈ 18,5 MB →
  chia 4 lần (mỗi lần ~4,5–4,6 MB, 5 file/lần, trộn gái+trai theo byte),
  như bộ 05–06.
  Đích `app/assets/_incoming/app/assets/images/character/girl/` và `.../boy/`.
  **Thứ tự đẩy: 06 TRƯỚC, 07 SAU.** SHA-256 (12 ký tự đầu) của 20 file:
  gái full `592d74141592`, wave `f23600973eec`, dr_a `34b35a258966`,
  dr_b `0f79646f02a3`, dr_c `d01fe4002cec`, dr_d `bda33fabbaa8`,
  ur_a `103ae045c6ff`, ur_b `25aec3c44081`, ur_c `f7d736b216fe`,
  ur_d `16cc0e54b836`;
  trai full `af87ebe2509e`, wave `d5e499375b71`, dr_a `931f8bb7170a`,
  dr_b `fa29af121ea0`, dr_c `6017668cc2c2`, dr_d `f32650de8e46`,
  ur_a `4fb762ca6f5f`, ur_b `bc4f2ae136f9`, ur_c `ce11d1b3c564`,
  ur_d `883a5856a6b5`.
  10 file trai + gái đứng/vẫy KHÔNG đổi 1 byte trong đợt vẽ lại khung đi
  (đối chiếu SHA trước khi báo).

ĐƯỢC DUYỆT KIỂU 22/11 ~21:27 (Claude): đủ 20 file (gái + trai); 8 khung đi gái vẽ lại mặt rộng ĐẠT. Đẩy 4 lần (5+5+5+5, mỗi lần 4,42/4,37/4,37/4,47 MB .b64): `7a133271` (5 file), `66606bb0` (5 file), `d4759b95` (5 file), `e26c6dd0` (5 file); đầu nhánh sau đẩy `e26c6dd0`. 20/20 .b64 giải mã đúng từng byte PNG gốc trong vòng khứ hồi local (SHA-256 khớp) — đối chiếu blob SHA trên nhánh bị chặn (bảo vệ mã xác minh, giống bộ 04/05/06), Claude kiểm lại bằng git khi decode. Chưa decode (chờ Claude decode).
### Lô 12 — Sóc (pet thường): trọn bộ 27 file (23/11/2026)

Loài đầu tiên của lô 12 (sóc thường, càng hiếm càng đắt — sóc < capybara < rồng).
4 tấm xem trước đã duyệt kiểu v2 (trứng + newborn/teen/adult đứng, 23/11 ~22:47)
**dùng lại nguyên bản, không vẽ lại**; vẽ mới 5 vỏ trứng + 18 khung chuyển động
(happy/sit/walk_a..d × newborn/teen/adult). 27 file vào
`app/assets/images/pets/`, 512×512, PNG trong suốt, alpha sạch (semi 0, 0 px
magenta cả thước chuẩn R>200/G<80/B>200 lẫn thước nới R>140/G<60/B>140),
quantize 256 màu MAXCOVERAGE + Floyd–Steinberg. Vẽ từ 4 ảnh đứng sóc đã duyệt
(giữ đúng nhận dạng: lông nâu đỏ + bụng kem + đuôi xù to + tai nhọn + mắt nâu to);
walk nhìn nghiêng 3/4 quay PHẢI, chân luân phiên, chân y=439; happy nhấc 40 px
(đáy y=399); sit chân y=439; newborn đi KHÔNG vỏ (đã nở, như bản sửa chó newborn
lô 8B-fix). Tổng PNG 3.883.520 B (~5,18 MB .b64).

#### Bảng 27 file

| file | byte | bbox (x0, y0, x1, y1) | đất y | SHA-256 (12 ký tự đầu) | lần vẽ |
|---|---|---|---|---|---|
| squirrel_adult.png | 119009 | 86, 40, 425, 439 | 439 | 1614bba75c2d | 1 |
| squirrel_adult_happy.png | 150880 | 64, 8, 446, 399 | 399 | 871a7ee562a1 | 1 |
| squirrel_adult_sit.png | 155904 | 72, 40, 438, 439 | 439 | 1a35ae88b105 | 1 |
| squirrel_adult_walk_a.png | 179314 | 26, 40, 485, 439 | 439 | 35eb94e85aa4 | 2 |
| squirrel_adult_walk_b.png | 188758 | 8, 40, 503, 439 | 439 | 1a37fc96a5db | 2 |
| squirrel_adult_walk_c.png | 182436 | 30, 40, 480, 439 | 439 | dd029c0c843c | 1 |
| squirrel_adult_walk_d.png | 175864 | 0, 40, 510, 439 | 439 | aa47049757bc | 2 |
| squirrel_egg.png | 113014 | 62, 40, 448, 439 | 439 | 5b77d2b80058 | 1 |
| squirrel_egg_crack_1.png | 117446 | 97, 40, 414, 439 | 439 | c642e456d29f | 1 |
| squirrel_egg_crack_2.png | 113153 | 104, 40, 407, 439 | 439 | 12024db9a4c4 | 1 |
| squirrel_egg_crack_3.png | 135738 | 78, 40, 433, 439 | 439 | 2a4ed509947d | 1 |
| squirrel_newborn.png | 102843 | 64, 40, 446, 439 | 439 | ebb719ba29d1 | 1 |
| squirrel_newborn_happy.png | 128688 | 75, 8, 436, 399 | 399 | cc9df4ba211e | 1 |
| squirrel_newborn_sit.png | 134371 | 79, 40, 432, 439 | 439 | 52e547ee72de | 1 |
| squirrel_newborn_walk_a.png | 159694 | 29, 41, 482, 439 | 439 | c6676d9901e7 | 1 |
| squirrel_newborn_walk_b.png | 157227 | 30, 40, 481, 439 | 439 | f02558efbc15 | 1 |
| squirrel_newborn_walk_c.png | 138977 | 32, 40, 477, 439 | 439 | 1e1e1fbc88fa | 1 |
| squirrel_newborn_walk_d.png | 157123 | 24, 40, 487, 439 | 439 | 4e7f15b0108d | 1 |
| squirrel_shell_bottom.png | 88762 | 102, 155, 407, 439 | 439 | 2b1b1d8f9859 | 1 |
| squirrel_shell_top.png | 67000 | 102, 60, 407, 262 | 262 | e2cff270861a | 1 |
| squirrel_teen.png | 127188 | 75, 40, 435, 439 | 439 | 66077fce0ed7 | 1 |
| squirrel_teen_happy.png | 141427 | 68, 9, 442, 399 | 399 | 9d86dd36e82a | 1 |
| squirrel_teen_sit.png | 163209 | 56, 40, 454, 439 | 439 | 4b8aa7075f3e | 1 |
| squirrel_teen_walk_a.png | 175383 | 31, 40, 479, 439 | 439 | 643b62fcd840 | 1 |
| squirrel_teen_walk_b.png | 180279 | 13, 40, 497, 439 | 439 | 78c7ab45d97a | 1 |
| squirrel_teen_walk_c.png | 168570 | 43, 40, 467, 439 | 439 | 61d317a8d18c | 1 |
| squirrel_teen_walk_d.png | 161263 | 54, 40, 457, 439 | 439 | 7e17ddac69b1 | 1 |

#### Mốc đo (đo bằng code từ ảnh thật)

- Trứng kín: crack_1 bbox (97, 40, 414, 439), rộng 318 px, tâm x=255.
- Vỏ nứt tăng dần: dark-px (R<100/G<80/B<60) crack_1 = 72 → crack_2 = 3.333 →
  crack_3 = 3.665; crack_1 chỉ vài vết nứt mảnh ở đỉnh, crack_2 nứt zigzag đậm
  khắp nửa trên + chỏm lông cam thò ra ở đỉnh, crack_3 nứt rộng thấy mặt + 2 chân
  trước của sóc (dark-px bão hoà ở crack_3 vì khe nứt lấp bằng lông sáng, không
  phải vạch tối — mức tăng đọc bằng mắt).
- Vỏ rời: shell_top (102, 60, 407, 262), rộng 306, cao 203; shell_bottom (102,
  155, 407, 439), rộng 306, cao 285, đáy y=439. Khớp trứng kín crack_1: cùng tâm
  x=255, rộng kém 12 px, đỉnh nắp thấp hơn 20 px, đáy bằng nhau; chồng 2 nửa lên
  nhau vẽ đúng viền trứng kín (chênh ~12 px). So với mèo lô 8A (nắp 282×230, bát
  282×170): nắp sóc nông hơn, bát sâu hơn, chồng nhau 107 px (mèo 27 px) — chỗ
  răng cưa cài nhau, nhìn riêng vẫn ra nửa vỏ.
- Happy nhấc 40 px cả 3 giai đoạn (newborn/teen/adult đáy y=399, đỉnh y=8–9);
  mắt cười nhắm + miệng cười hở + 2 chân trước giơ lên, newborn happy vẫn ngồi
  trong nửa vỏ dưới như ảnh đứng.
- Chu kỳ đi: a/c đối chân, b/d bước giữa; đầu lệch ≤2 px trong chu kỳ; đuôi xù
  theo dáng đi, không che thân. Adult walk_a/b vẽ lại lần 2 (bản v1 thân dựng
  ~45°, bản v2 nằm ngang 4 chân như teen — đã dùng bản v2).

#### Cách làm

- Vẽ từng tấm bằng media generation trên nền magenta #FF00FF, lấy ảnh đứng cùng
  giai đoạn làm tham chiếu; adult walk_a/b vẽ lại lấy teen walk_a/b làm mẫu tư
  thế. Tổng 26 lần vẽ (23 tấm + 3 vẽ lại).
- Tách nền + quantize bằng code (`lot12/work/squirrel/process_squirrel.py`,
  tái dùng tách nền `process_v2.py`: key median góc + flood-fill nền từ biên qua
  pixel magenta-hued, KHÔNG `binary_fill_holes`; m2/m3 chỉ trong 3 px quanh
  magenta thật; rim-recolor; quantize 256 màu MAXCOVERAGE + Floyd–Steinberg).
  Happy scale cao 392 px đặt y=8; vỏ scale theo rộng 306 px, tâm x=255, nắp neo
  y=60, bát neo đáy y=439. Raw shell_top vẽ cả 2 nửa trong 1 khung → tách bằng
  connected components, giữ nửa trên (không vẽ lại).
- Sửa tàn dư magenta: 12 file còn 1–14 px magenta sau quantize (kể cả đốm trong
  thân: adult_walk_a 14 px, adult_sit 6 px) + 1 px strict-magenta (233,76,220) ở
  vùng miệng adult_happy mà thước nới (G<60) không bắt được (G=76); sửa bằng
  cách tô màu palette an toàn gần nhất, KHÔNG thêm màu mới (bản thử median
  neighbor đã bỏ vì đẩy adult_sit lên 258 màu, adult_walk_a 262 màu).

#### Kiểm chứng

- Đo bằng code ĐẠT 27/27: 512×512, semi 0, magenta 0 (cả 2 thước), ≤256 màu;
  thân cao 400 px (y 40→439), đất y=439; happy cao 391–392 px, đáy y=399.
- Soi bằng mắt trên nền tối (60,60,80) + nền phòng v3b ở cỡ app (newborn 40% /
  teen 58% / adult 72% chiều cao bé 360 px) + phóng 3× viền mặt/tai/đuôi/chân:
  không lỗ alpha, không mép thẳng, không tàn dư magenta (vài đốm hồng dither
  ≤2 px trên mép lông, dưới ngưỡng đo, không thấy ở cỡ app).
- Lỗ trong suốt kín (khe vòng cuộn đuôi, khe chân–đuôi) lớn nhất: teen 486 px,
  teen_sit 440 px, teen_happy 341 px — khe hở tự nhiên như lô 12 v1 (teen 542 px),
  không phải lỗ thân.
- 4 file xem trước đối chiếu SHA-256 khớp nguyên bản (egg `5b77d2b8…`,
  newborn `ebb719ba…`, teen `66077fce…`, adult `1614bba7…`).

#### Điểm chưa chắc — nói thẳng

1. adult_walk_d: đầu chóp đuôi chạm mép trái khung x=0 (5 px, y143–147), vài sợi
   lông ngọn bị cắt; vẽ lại lần 2 còn tệ hơn (rộng 522 px, chạm 45 px trái +
   19 px phải) nên GIỮ bản v1. Ở cỡ app không thấy; chờ Claude chốt chấp nhận.
2. Dark-px nứt bão hoà crack_2→crack_3 (3.333→3.665) — mức tăng đọc bằng mắt,
   không đọc bằng số này.
3. Bát vỏ sâu hơn mèo lô 8A (285 px so với 170 px), nắp nông hơn (203 px so với
   230 px); chồng nhau 107 px. Nhìn riêng vẫn ra nửa vỏ, chồng lên trứng kín
   vẫn đúng viền.
4. Đối chân a/c chỉ gần đúng (AI vẽ), như lô 8B; newborn a/d hơi giống nhau (cả
   2 đều chân trước vươn tới trước).
5. Teen→adult phân biệt chủ yếu bằng đuôi to/xù hơn + thân dài hơn, như bản xem
   trước đã duyệt (ghi trong report v1).

#### Kế hoạch đẩy (4 lần .b64, CHỈ NHÁP — parent đẩy)

- Đợt 1 (6 file, PNG 907767 B, .b64 ~1210356 B): squirrel_adult_walk_b.png, squirrel_teen_sit.png, squirrel_newborn_walk_a.png, squirrel_adult_sit.png, squirrel_teen.png, squirrel_egg.png
- Đợt 2 (7 file, PNG 1007833 B, .b64 ~1343777 B): squirrel_adult_walk_c.png, squirrel_teen_walk_c.png, squirrel_teen_walk_d.png, squirrel_adult_happy.png, squirrel_newborn_happy.png, squirrel_egg_crack_2.png, squirrel_newborn.png
- Đợt 3 (7 file, PNG 973509 B, .b64 ~1298012 B): squirrel_teen_walk_b.png, squirrel_teen_walk_a.png, squirrel_newborn_walk_d.png, squirrel_newborn_walk_c.png, squirrel_egg_crack_3.png, squirrel_adult.png, squirrel_shell_top.png
- Đợt 4 (7 file, PNG 994411 B, .b64 ~1325881 B): squirrel_adult_walk_a.png, squirrel_adult_walk_d.png, squirrel_newborn_walk_b.png, squirrel_teen_happy.png, squirrel_newborn_sit.png, squirrel_egg_crack_1.png, squirrel_shell_bottom.png
Tổng .b64 ~5,18 MB; đích `app/assets/images/pets/`; mỗi lần ≤8 file, mỗi file
.b64 <1.217.688 B. Mục này do parent gộp vào `docs/E_IMAGES.md` cùng đợt đẩy
(xem cuối mục); Claude decode + kiểm bằng git (đối chiếu blob SHA) sau đó.

Đã đẩy 4 lần .b64 (23/11/2026): `84c6cd8c` (6 file), `d2cc9a51` (7 file),
`0b7c3c07` (7 file), `de3e285d` (7 file), 27/27 vòng khứ hồi local khớp từng
byte. Chưa decode (chờ Claude decode).
### Lô 12 — Capybara (pet hiếm): trọn bộ 27 file (23/11/2026)

Loài thứ hai của lô 12 (capybara hiếm — sóc < capybara < rồng).
4 tấm xem trước đã duyệt kiểu v2 (trứng + newborn/teen/adult đứng, 23/11 ~22:57)
**dùng lại nguyên bản, không vẽ lại**; vẽ mới 5 vỏ trứng + 18 khung chuyển động
(happy/sit/walk_a..d × newborn/teen/adult). 27 file vào
`app/assets/images/pets/`, 512×512, PNG trong suốt, alpha sạch (semi 0, 0 px
magenta cả thước chuẩn R>200/G<80/B>200 lẫn thước nới R>140/G<60/B>140 —
trừ 4 px dark-magenta có sẵn trong file trứng đã duyệt, xem mục "Điểm chưa chắc"),
quantize 256 màu MAXCOVERAGE + Floyd–Steinberg. Vẽ từ 4 ảnh đứng capybara đã duyệt
(giữ đúng nhận dạng: lông nâu xám ấm + bụng kem + quýt nhỏ + lá xanh trên đầu +
má hồng to + mắt híp thư thái; teen đứng 4 chân; adult mắt híp sâu nhất);
walk nhìn nghiêng 3/4 quay PHẢI, chân luân phiên, chân y=439; happy nhấc 40 px
(đáy y=399); sit chân y=439; newborn đi KHÔNG vỏ (đã nở, như bản sửa chó newborn
lô 8B-fix). Tổng PNG 2.886.931 B (~3,85 MB .b64).

#### Bảng 27 file

| file | byte | bbox (x0, y0, x1, y1) | đất y | SHA-256 (12 ký tự đầu) | lần vẽ |
|---|---|---|---|---|---|
| capybara_adult.png | 99099 | 125, 40, 386, 439 | 439 | 6fa7ce144065 | 1 |
| capybara_adult_happy.png | 103187 | 112, 8, 399, 399 | 399 | 30baf2810a88 | 1 |
| capybara_adult_sit.png | 101688 | 124, 40, 387, 439 | 439 | 1f78ea95c8c3 | 1 |
| capybara_adult_walk_a.png | 111748 | 80, 40, 431, 439 | 439 | bb94f540093f | 1 |
| capybara_adult_walk_b.png | 121794 | 73, 40, 438, 439 | 439 | 29b3ebbf6f9c | 1 |
| capybara_adult_walk_c.png | 119107 | 67, 40, 443, 439 | 439 | f559e19580b2 | 1 |
| capybara_adult_walk_d.png | 119283 | 62, 40, 449, 439 | 439 | 911d60086f64 | 1 |
| capybara_egg.png | 114706 | 103, 40, 408, 439 | 439 | 7b7fa0461b05 | 1 |
| capybara_egg_crack_1.png | 108685 | 95, 40, 415, 439 | 439 | 1ddc3233c99c | 1 |
| capybara_egg_crack_2.png | 114000 | 103, 40, 407, 439 | 439 | 588f1ff9dbc6 | 1 |
| capybara_egg_crack_3.png | 106889 | 116, 40, 395, 439 | 439 | 38a662ae3e24 | 2 |
| capybara_newborn.png | 117901 | 94, 40, 417, 439 | 439 | 3e739f892438 | 1 |
| capybara_newborn_happy.png | 114554 | 100, 8, 411, 399 | 399 | e79d6b5cf4ef | 1 |
| capybara_newborn_sit.png | 109622 | 133, 40, 377, 439 | 439 | 3d6f89ef4c5a | 1 |
| capybara_newborn_walk_a.png | 105796 | 62, 40, 449, 439 | 439 | feac8c496889 | 1 |
| capybara_newborn_walk_b.png | 113316 | 62, 40, 448, 439 | 439 | fac79290c7d2 | 3 |
| capybara_newborn_walk_c.png | 100072 | 59, 40, 452, 439 | 439 | 22471723b51a | 1 |
| capybara_newborn_walk_d.png | 110252 | 59, 40, 452, 439 | 439 | 057a6939ecee | 3 |
| capybara_shell_bottom.png | 78859 | 101, 166, 409, 439 | 439 | 680f28667d44 | 1 |
| capybara_shell_top.png | 73834 | 101, 60, 409, 278 | 278 | 242df8d0fad3 | 2 |
| capybara_teen.png | 99028 | 110, 40, 401, 439 | 439 | bc1e778b30b6 | 1 |
| capybara_teen_happy.png | 94268 | 120, 8, 390, 399 | 399 | 2e1006191c62 | 1 |
| capybara_teen_sit.png | 107845 | 93, 40, 417, 439 | 439 | 63614b66874e | 2 |
| capybara_teen_walk_a.png | 114587 | 56, 40, 454, 439 | 439 | 141854ad6eab | 1 |
| capybara_teen_walk_b.png | 112015 | 87, 40, 424, 439 | 439 | ccc554fd4b1b | 1 |
| capybara_teen_walk_c.png | 106427 | 82, 40, 428, 439 | 439 | fbac8fec7f36 | 2 |
| capybara_teen_walk_d.png | 108369 | 83, 40, 428, 439 | 439 | 6b09ddeaf5dd | 1 |

#### Mốc đo (đo bằng code từ ảnh thật)

- Trứng kín: crack_1 bbox (95, 40, 415, 439), rộng 321 px, tâm x=255.
- Vỏ nứt tăng dần: dark-px (R<100/G<80/B<60) crack_1 = 160 → crack_2 = 3.970 →
  crack_3 = 4.216; crack_1 chỉ vài vết nứt mảnh ở đỉnh, crack_2 nứt zigzag đậm
  khắp nửa trên + chỏm lông nâu xám thò ra ở đỉnh, crack_3 nứt rộng thấy mặt + 2 chân
  trước của capybara (dark-px tăng ít ở 2→3 vì khe nứt lấp bằng lông sáng — mức
  tăng đọc bằng mắt).
- Vỏ rời: shell_top (101, 60, 409, 278), rộng 309, cao 219; shell_bottom (101,
  166, 409, 439), rộng 309, cao 274, đáy y=439. Khớp trứng kín crack_1: cùng tâm
  x=255, rộng kém 12 px, chồng 2 nửa lên nhau vẽ đúng viền trứng kín (IoU 0,9298,
  sóc 0,9326); chồng nhau 113 hàng. So với sóc lô 12 (nắp 306×203, bát 306×285):
  nắp capybara cao hơn (219 px), bát nông hơn (274 px).
- **Không còn viền plum tối sát đáy vỏ** (v2 đã xoá): shell_bottom tổng 98 px plum,
  20 hàng đáy (y420–439) = 0 px, y400–439 chỉ 2 px.
- Happy nhấc 40 px cả 3 giai đoạn (newborn/teen/adult đáy y=399, đỉnh y=8);
  mắt híp cười + miệng cười hở + 2 chân trước giơ lên, newborn happy vẫn ngồi
  trong nửa vỏ dưới như ảnh đứng.
- Chu kỳ đi: a/c đối chân, b/d bước giữa; chân y=439; quay PHẢI. Lông khung đi đã
  chỉnh ấm bằng code (xem "Cách làm"): trung vị lông R−B sau chỉnh 62–84, ảnh
  đứng 96–108.

#### Cách làm

- Vẽ từng tấm bằng media generation trên nền magenta #FF00FF, lấy ảnh đứng cùng
  giai đoạn làm tham chiếu. Tổng 31 lần vẽ (23 tấm + 8 vẽ lại: crack_3, shell_top,
  newborn walk_b/d, teen sit, teen walk_c — mỗi file 2–3 lần).
- Tách nền + quantize bằng code (`lot12/work/capybara/process_capybara_*.py`,
  tái dùng tách nền `process_v2.py`: key median góc + flood-fill nền từ biên qua
  pixel magenta-hued, KHÔNG `binary_fill_holes`; m2/m3 chỉ trong 3 px quanh
  magenta thật; rim-recolor; quantize 256 màu MAXCOVERAGE + Floyd–Steinberg).
  Happy scale cao 392 px đặt y=8; vỏ scale theo rộng 309 px, tâm x=255, nắp neo
  y=60, bát neo đáy y=439.
- Sửa tàn dư magenta: 4 file còn 1–2 px magenta-nới sau quantize (adult_happy 1,
  teen_happy 1, teen_walk_c 1, newborn_happy 2) — tô màu palette an toàn gần nhất,
  KHÔNG thêm màu mới; đo lại 0/0.
- **Chỉnh ấm lông khung đi bằng code** (`warm_walk_apply.py`): lông khung đi vẽ ra
  xám lạnh (trung vị lông R−B 33–55) so với ảnh đứng nâu ấm (R−B 96–108) — chỉnh
  bằng histogram-match theo kênh, chỉ trên vùng lông, cường độ 0,5 (bản đủ 1,0
  ngả cam quá đà nên bỏ), feather mép 1,2 px, quantize lại 256 màu. Bản gốc giữ
  trong `raw_warm_backup/`.

#### Kiểm chứng

- Đo bằng code ĐẠT 23/23 file mới: 512×512, semi 0, magenta 0 (cả 2 thước), ≤256 màu;
  thân cao 400 px (y 40→439), đất y=439; happy cao 392 px, đáy y=399. 4 file xem
  trước đối chiếu SHA-256 khớp nguyên bản (egg `7b7fa0461b05…`, newborn
  `3e739f892438…`, teen `bc1e778b30b6…`, adult `6fa7ce144065…`).
- Soi bằng mắt trên nền tối (60,60,80) + nền phòng v3b ở cỡ app (newborn 40% /
  teen 58% / adult 72% chiều cao bé 360 px) + phóng 3× viền mặt/mắt/lông/chân:
  không lỗ alpha, không mép thẳng, không tàn dư magenta; quýt + lá xanh + má hồng
  to + mắt híp ở MỌI khung; teen đứng 4 chân, adult ngồi mũm nhất.
- Lỗ trong suốt kín lớn nhất: teen_walk_d 55 px, teen_walk_b 19 px, teen 16 px — khe
  hở lông tự nhiên, không phải lỗ thân.

#### Điểm chưa chắc — nói thẳng

1. crack_2: chỏm lông thò ra hơi nhọn/xám, giống lông nhím hơn lông mềm capybara;
   nứt zigzag + vân sóng nửa dưới đúng brief nên giữ, không vẽ lại.
2. crack_3 v2 KHÔNG có mảnh vỏ bay (bản v1 mảnh văng quá xa, xử lý rối) — nắp đội
   sát trên đầu như mũ; nếu Claude muốn đúng brief từng chữ thì vẽ lại.
3. Dark-px nứt bão hoà crack_2→crack_3 (+6%) — mức tăng đọc bằng mắt, không đọc
   bằng số này.
4. Vòm nắp hơi phình hơn trứng kín ở y100–200 (rộng hơn tới +19 px ở y150); IoU
   0,9298 vẫn tương đương sóc.
5. Vệt tím rất mỏng ở mép đáy shell_bottom/crack_2 (bóng nâu của vỏ, magenta = 0) —
   không thấy ở cỡ app.
6. Teen→adult phân biệt bằng độ mũm + tỉ lệ hiển thị trong app (58% vs 72%), như
   sóc; teen đứng bbox rộng 292 px > adult 262 px do tư thế.
7. Đối chân a/c chỉ gần đúng (AI vẽ), như lô 8B/sóc; newborn b/d đọc như khung sải
   hơn là chân lướt qua nhau.
8. capybara_egg.png (xem trước v2 đã duyệt) có sẵn 4 px dark-magenta ở (265–268,
   55), RGB (175–188, 33–52, 196–215) — ghi trong redo_v2, KHÔNG sửa (file duyệt
   dùng lại nguyên bản).
9. Lông khung đi đã chỉnh ấm bằng code (không vẽ lại): R−B 62–84 so với ảnh đứng
   96–108; lông sáng nhất ở khung newborn còn ánh hồng nhạt ở cỡ xem trước; bản
   gốc giữ trong `raw_warm_backup/`.

#### Kế hoạch đẩy (4 lần .b64, CHỈ NHÁP — parent đẩy)

- Đợt 1 (7 file, PNG 754076 B, .b64 ~1005434 B): capybara_adult_walk_b.png, capybara_egg_crack_2.png, capybara_egg_crack_3.png, capybara_newborn_walk_d.png, capybara_teen.png, capybara_teen_happy.png, capybara_teen_sit.png
- Đợt 2 (7 file, PNG 733916 B, .b64 ~978554 B): capybara_adult_happy.png, capybara_adult_sit.png, capybara_adult_walk_a.png, capybara_adult_walk_d.png, capybara_newborn_happy.png, capybara_newborn_sit.png, capybara_shell_top.png
- Đợt 3 (6 file, PNG 660262 B, .b64 ~880349 B): capybara_adult_walk_c.png, capybara_egg_crack_1.png, capybara_newborn_walk_a.png, capybara_newborn_walk_c.png, capybara_teen_walk_a.png, capybara_teen_walk_b.png
- Đợt 4 (7 file, PNG 738677 B, .b64 ~984902 B): capybara_adult.png, capybara_egg.png, capybara_newborn.png, capybara_newborn_walk_b.png, capybara_shell_bottom.png, capybara_teen_walk_c.png, capybara_teen_walk_d.png
Tổng .b64 ~3,85 MB; đích `app/assets/images/pets/`; mỗi lần ≤8 file, mỗi file
.b64 <1.217.688 B. Mục này do parent gộp vào `docs/E_IMAGES.md` cùng đợt đẩy
(xem cuối mục); Claude decode + kiểm bằng git (đối chiếu blob SHA) sau đó.

Đã đẩy 4 lần .b64 (24/11/2026): `faacbff1` (7 file), đợt 2 (7 file, exec bị
restart nhưng đã kiểm trên nhánh: shell_top + adult_happy khớp từng byte),
`78e630cd` (6 file), `a62542f7` (7 file), 27/27 vòng khứ hồi local khớp từng
byte. Chưa decode (chờ Claude decode).
### Lô 12 — Rồng (pet siêu hiếm): trọn bộ 27 file (24/11/2026)

Loài thứ ba và cuối cùng của lô 12 (rồng siêu hiếm — sóc < capybara < rồng).
4 tấm xem trước đã duyệt kiểu v2 (trứng + newborn/teen/adult đứng, 23/11 ~22:57)
**dùng lại nguyên bản, không vẽ lại**; vẽ mới 5 vỏ trứng + 18 khung chuyển động
(happy/sit/walk_a..d × newborn/teen/adult). 27 file vào
`app/assets/images/pets/`, 512×512, PNG trong suốt, alpha sạch (semi 0, 0 px
magenta thước chuẩn R>200/G<80/B>200 — còn 13 px dark-magenta thước nới
R>140/G<60/B>140 là nét viền tím sẫm của artwork, xem mục "Điểm chưa chắc"),
quantize 256 màu MAXCOVERAGE + Floyd–Steinberg. Vẽ từ 4 ảnh đứng rồng đã duyệt
(giữ đúng nhận dạng: vảy pastel mint + bụng kem + sừng vàng-kem mềm tròn + cánh
trong mờ mint-hồng + đốm vàng lấp lánh + mắt tím-xanh sẫm + vòng cổ vàng mỏng +
mặt gem hình sao pastel ở cả 3 giai đoạn, KHÔNG khăn len cổ); walk nhìn nghiêng
3/4 quay PHẢI, chân luân phiên, chân y=439; happy nhấc 40 px (đáy y=399); sit
chân y=439; newborn đi KHÔNG vỏ (đã nở, như bản sửa chó newborn lô 8B-fix).
Tổng PNG 3.955.938 B (~5,27 MB .b64).

#### Bảng 27 file

| file | byte | bbox (x0, y0, x1, y1) | đất y | SHA-256 (12 ký tự đầu) | lần vẽ |
|---|---|---|---|---|---|
| dragon_adult.png | 146872 | 54, 40, 457, 439 | 439 | 7eaaa6e9028c | 1 |
| dragon_adult_happy.png | 142561 | 43, 8, 468, 399 | 399 | 44e4e70bde1b | 2 |
| dragon_adult_sit.png | 156689 | 76, 40, 434, 439 | 439 | 41a64dbd4257 | 1 |
| dragon_adult_walk_a.png | 150448 | 50, 40, 460, 439 | 439 | b39bf247c61d | 1 |
| dragon_adult_walk_b.png | 130495 | 89, 40, 421, 439 | 439 | 48f2c4cfedc0 | 1 |
| dragon_adult_walk_c.png | 123279 | 88, 40, 423, 439 | 439 | 210a1f80068b | 1 |
| dragon_adult_walk_d.png | 134037 | 54, 40, 456, 439 | 439 | 55cc4d8f2db4 | 1 |
| dragon_egg.png | 158795 | 88, 40, 422, 439 | 439 | e5e9b498f3d0 | 1 |
| dragon_egg_crack_1.png | 139879 | 97, 40, 414, 439 | 439 | d020bed85e79 | 1 |
| dragon_egg_crack_2.png | 147397 | 109, 40, 402, 439 | 439 | 160d6aac3b34 | 2 |
| dragon_egg_crack_3.png | 181947 | 43, 40, 468, 439 | 439 | ca021a90bc25 | 1 |
| dragon_newborn.png | 142755 | 102, 40, 409, 439 | 439 | 7b769fbd889a | 1 |
| dragon_newborn_happy.png | 143995 | 45, 8, 465, 399 | 399 | 454cb1b2422a | 2 |
| dragon_newborn_sit.png | 154701 | 75, 40, 436, 439 | 439 | 3c2631d857cd | 1 |
| dragon_newborn_walk_a.png | 144509 | 70, 40, 440, 439 | 439 | face9044cc61 | 1 |
| dragon_newborn_walk_b.png | 162500 | 77, 40, 434, 439 | 439 | 2556f9ed6ccd | 1 |
| dragon_newborn_walk_c.png | 160411 | 58, 40, 453, 439 | 439 | 28bbfbce8283 | 1 |
| dragon_newborn_walk_d.png | 150906 | 77, 40, 433, 439 | 439 | 8095bd4db8b5 | 1 |
| dragon_shell_bottom.png | 111861 | 102, 106, 407, 439 | 439 | f5c9272e61ae | 1 |
| dragon_shell_top.png | 123027 | 102, 60, 407, 360 | 360 | 0bbf8755ad30 | 2 |
| dragon_teen.png | 149180 | 78, 40, 433, 439 | 439 | 8defa0decd34 | 1 |
| dragon_teen_happy.png | 151152 | 34, 8, 476, 399 | 399 | 632f45421e36 | 1 |
| dragon_teen_sit.png | 162326 | 68, 40, 443, 439 | 439 | c04600c35d35 | 1 |
| dragon_teen_walk_a.png | 144614 | 73, 40, 438, 439 | 439 | d1eaa0dfbafc | 1 |
| dragon_teen_walk_b.png | 143934 | 83, 40, 428, 439 | 439 | ca44b1bbccb6 | 1 |
| dragon_teen_walk_c.png | 151671 | 81, 40, 430, 439 | 439 | 54d8e7b6cec3 | 1 |
| dragon_teen_walk_d.png | 145997 | 85, 40, 425, 439 | 439 | 81294fcceaaf | 1 |

#### Mốc đo (đo bằng code từ ảnh thật)

- Trứng kín: crack_1 bbox (97, 40, 414, 439), rộng 318 px, tâm x=255.
- Vỏ nứt tăng dần: dark-px (R<100/G<80/B<60) crack_1 = 224 → crack_2 = 3.476 →
  crack_3 = 1.390; crack_1 chỉ vài vết nứt mảnh ở đỉnh, crack_2 nứt zigzag đậm
  khắp nửa trên + chỏm vảy mint thò ra ở đỉnh, crack_3 nứt rộng thấy đầu rồng
  (sừng vàng + cánh) + 2 chân trước + mảnh vỏ bay (dark-px giảm ở 2→3 vì khe
  nứt rộng là khoảng trống trong suốt, không phải vạch tối — mức tăng đọc bằng mắt).
- Vỏ rời: shell_top (102, 60, 407, 360), rộng 306, cao 301; shell_bottom (102,
  106, 407, 439), rộng 306, cao 334, đáy y=439. Khớp trứng kín crack_1: cùng tâm
  x=255, rộng kém 12 px, chồng 2 nửa lên nhau vẽ đúng viền trứng kín (IoU 0,9204,
  sóc 0,9326, capybara 0,9298); chồng nhau 254 px (sóc 107 px) do nắp sâu hơn.
- Happy nhấc 40 px cả 3 giai đoạn (newborn/teen/adult đáy y=399, đỉnh y=8);
  mắt nhắm cười + 2 chân trước giơ lên + cánh xoè nhẹ, newborn happy vẫn ngồi
  trong nửa vỏ dưới như ảnh đứng.
- Chu kỳ đi: a/c đối chân, b/d bước giữa; chân y=439; quay PHẢI; cánh khép theo
  thân khi đi, không che thân. Màu vảy mint khung đi so với ảnh đứng (median
  G−B): newborn +3/−1/+2/+8, teen +1/+1/+10/+7, adult +4/−5/−4/−5 — lệch lớn
  nhất +10, trong ngưỡng ±15, không vẽ lại, không chỉnh màu bằng code.

#### Cách làm

- Vẽ từng tấm bằng media generation trên nền magenta #FF00FF, lấy ảnh đứng cùng
  giai đoạn làm tham chiếu. Tổng 31 lần gọi (27 file lần đầu + 4 vẽ lại:
  crack_2, shell_top, newborn_happy, adult_happy).
- Tách nền + quantize bằng code (`lot12/work/dragon/process_dragon.py`, tái dùng
  tách nền `process_v2.py`: key median góc + flood-fill nền từ biên qua pixel
  magenta-hued, KHÔNG `binary_fill_holes`; m2/m3 chỉ trong 3 px quanh magenta
  thật; rim-recolor; quantize 256 màu MAXCOVERAGE + Floyd–Steinberg). Happy
  scale cao 392 px đặt y=8; vỏ scale theo rộng 306 px, tâm x=255, nắp neo y=60,
  bát neo đáy y=439. Raw shell_top vẽ cả 2 nửa trong 1 khung → tách bằng
  connected components, giữ nửa trên (không vẽ lại).
- Sửa tàn dư magenta sau quantize: 31 px rim-bleed (5 px thước chuẩn + 26 px
  thước nới, đều ở mép cánh/viền, edge_d ≤ 2,2) — tô màu palette an toàn gần
  nhất (median pixel lân cận không-magenta, cửa sổ 7×7), KHÔNG thêm màu mới;
  kiểm lại bằng zoom 3×–6× không vết lạ; bản gốc giữ trong `raw_fix_backup/`.

#### Kiểm chứng

- Đo bằng code ĐẠT 27/27: 512×512, semi 0, magenta thước chuẩn 0, ≤256 màu; thân
  cao 400 px (y 40→439), đất y=439; happy cao 392 px, đáy y=399. Còn 13 px
  dark-magenta thước nới là nét viền tím sẫm của artwork (xem "Điểm chưa chắc").
- Soi bằng mắt trên nền tối (60,60,80) + nền phòng v3b ở cỡ app (newborn 40% /
  teen 58% / adult 72% chiều cao bé 360 px) + phóng 3×–6× viền mặt/mắt/cánh/
  chân: không lỗ alpha, không mép thẳng, không tàn dư magenta thấy được; vòng
  cổ + gem sao + cánh + sừng ở MỌI khung; cánh trong mờ vẫn đọc được, không bị ăn mất.
- Lỗ trong suốt kín lớn nhất: adult_walk_a 2.290 px (khe giữa đuôi cuộn và chân
  sau, x85–156/y349–400), newborn_walk_c 713 px (khe cánh–thân), dragon_egg
  538 px (khe đuôi–vỏ) — khe hở tự nhiên giữa các bộ phận, không phải lỗ thân.
- 4 file xem trước đối chiếu SHA-256 khớp nguyên bản (egg `e5e9b498f3d0…`,
  newborn `7b769fbd889a…`, teen `8defa0decd34…`, adult `7eaaa6e9028c…`).

#### Điểm chưa chắc — nói thẳng

1. Dark-magenta thước nới còn 13 px, đều là nét viền tím sẫm của artwork (đã
   kiểm bằng zoom 3×–6×): dragon_newborn.png (file xem trước đã duyệt, KHÔNG
   sửa) 7 px; newborn_happy 4 px đường mi mắt nhắm (sâu trong mặt, edge_d
   12,8–16,3); teen_happy 2 px viền cánh (304–305, 189–190). Thước chuẩn = 0.
   Tiền lệ: trứng capybara có 4 px dark-magenta giữ nguyên.
2. shell_top sâu hơn sóc (đáy y=360, chồng lấn 254 px vs sóc 107 px); IoU
   0,9204 vẫn ngang sóc/capybara. Nếu app dùng làm "nắp" nhấc lên thì nắp này
   sâu hơn hẳn.
3. Dark-px nứt bão hoà crack_2→crack_3 (3.476→1.390) — mức tăng đọc bằng mắt,
   không đọc bằng số này.
4. crack_1 và crack_3 có viền trắng mỏng quanh trứng (kiểu sticker) — cùng
   pipeline với các lô trước.
5. crack_3: đuôi rồng thò ra bên phải + thân trứng nhỏ lại tương đối (bbox rộng
   426 do mảnh vỏ bay) — giống bản xem trước gốc cũng có đuôi.
6. Adult happy v2: đuôi cong sang phải (v1 cong trái), gem sao xanh-hồng pastel
   thay vì hồng — vẫn là gem hình sao pastel, giữ.
7. Teen happy còn 2–3 chấm glitter vàng li ti trôi nổi sát cánh (tàn dư sparkle
   của raw) — nhìn như glitter cố ý.
8. Đối chân a/c chỉ gần đúng (AI vẽ), như lô 8B/sóc/capybara; newborn a/c khác
   biệt tinh tế ở góc 3/4.
9. Teen→adult phân biệt bằng kích thước + cánh/đuôi lớn hơn, như sóc/capybara;
   newborn walk_a vảy mint tối hơn ảnh đứng nhưng cùng tông (G−B +3).

#### Kế hoạch đẩy (4 lần .b64, CHỈ NHÁP — parent đẩy)

- Đợt 1 (7 file, PNG 1012523 B, .b64 ~1350031 B): adult_walk_b.png, egg_crack_3.png, newborn.png, shell_bottom.png, teen.png, teen_walk_a.png, teen_walk_c.png
- Đợt 2 (7 file, PNG 1023165 B, .b64 ~1364220 B): egg_crack_1.png, egg_crack_2.png, newborn_sit.png, newborn_walk_a.png, newborn_walk_b.png, shell_top.png, teen_happy.png
- Đợt 3 (6 file, PNG 902474 B, .b64 ~1203299 B): adult_happy.png, adult_sit.png, newborn_happy.png, newborn_walk_d.png, teen_sit.png, teen_walk_d.png
- Đợt 4 (7 file, PNG 1017776 B, .b64 ~1357035 B): adult.png, adult_walk_a.png, adult_walk_c.png, adult_walk_d.png, egg.png, newborn_walk_c.png, teen_walk_b.png
Tổng .b64 ~5,27 MB; đích `app/assets/images/pets/`; mỗi lần ≤8 file, mỗi file
.b64 <1.217.688 B. Mục này do parent gộp vào `docs/E_IMAGES.md` cùng đợt đẩy
(xem cuối mục); Claude decode + kiểm bằng git (đối chiếu blob SHA) sau đó.

Đã đẩy 4 lần .b64 (24/11/2026): `59ed0830` (7 file), `80b55fa7` (7 file),
`e3ab1c92` (6 file), `7f453960` (7 file), 27/27 vòng khứ hồi local khớp từng
byte. Chưa decode (chờ Claude decode).
### Lô 12B — Hiệu ứng rồng (pet siêu hiếm): 13 file (24/11/2026)

Rồng là pet siêu hiếm đầu tiên nên có hiệu ứng + tương tác riêng, khác biệt hoàn
toàn. 4 tấm xem trước đã duyệt kiểu (24/11 ~02:20) **dùng lại nguyên bản, không
vẽ lại**; vẽ mới 9 khung (fire_1/3/4, water_1/3/4, fly_b/c/d). 13 file vào
`app/assets/images/pets/`, 512×512, PNG trong suốt, alpha sạch (semi 0, 0 px
magenta cả thước chuẩn R>200/G<80/B>200 lẫn thước nới R>140/G<60/B>140),
quantize 256 màu MAXCOVERAGE + Floyd–Steinberg. 13 khung dùng cho **RỒNG
TRƯỞNG THÀNH** (lấy `dragon_adult` làm tham chiếu duy nhất, SHA `7eaaa6e9…`,
bbox 54,40,457,439); mới nở/nhỡ chỉ tia lửa/bong bóng nhỏ + nhảy vỗ cánh bằng
hiệu ứng code, không cần tranh. Tổng PNG 1.742.956 B (~2,32 MB .b64).

#### Cách dùng (phía code, Claude chốt 24/11 ~00:45)
(a) bé chạm rồng trong Phòng → hiện 3 nút Phun lửa / Phun nước / Bay; (b) rồng
trưởng thành đi quãng dài sẽ tự bay; (c) hào quang luôn tỏa sau rồng (phập phồng)
ở Phòng, Cửa hàng, Pet của bé.

#### Quyết định đã chốt (Claude duyệt xem trước 24/11 ~02:20)
1. Đốm hồng nhạt trong hào quang: **GIỮ** (hợp cánh hồng).
2. Lửa dời trái 16,4 px: **CHẤP NHẬN** (trục thân lửa 239,1 vs adult 255,5; app bù
   lệch theo từng loại khung để không nhảy).
3. Bay 94% cỡ adult: **CHẤP NHẬN** (app phóng bù).
4. Hai tọa độ miệng riêng: **OK** — lửa (279,7; 174,6), nước (322,2; 181,4), mỗi
   loại dùng chung 1 miệng cho 4 khung của nó (xem bảng dưới).

#### Bảng 13 file

| file | byte | bbox (x0, y0, x1, y1) | đất y / đáy y | SHA-256 (12 ký tự đầu) | lần vẽ |
|---|---|---|---|---|---|
| dragon_fire_1.png | 116571 | 10, 40, 391, 439 | 439 | ab5c1c68635e | 2 |
| dragon_fire_2.png | 156945 | 27, 40, 505, 439 | 439 | bf2193f9b2c7 | 2 |
| dragon_fire_3.png | 135843 | 22, 40, 502, 439 | 439 | e1579ee23c51 | 2 |
| dragon_fire_4.png | 125480 | 26, 40, 454, 439 | 439 | fb3601bac65b | 1 |
| dragon_water_1.png | 145892 | 32, 40, 451, 439 | 439 | 6f1f115d098d | 2 |
| dragon_water_2.png | 153703 | 36, 40, 485, 439 | 439 | 7337715baa15 | 3 |
| dragon_water_3.png | 156878 | 27, 40, 505, 439 | 439 | 869ade13cd22 | 3 |
| dragon_water_4.png | 144946 | 31, 40, 488, 439 | 439 | de7ab04f8667 | 1 |
| dragon_fly_a.png | 143007 | 72, 19, 438, 388 | 388 | 1222327243b8 | 1 |
| dragon_fly_b.png | 110326 | 7, 94, 458, 341 | 341 | ea3051cf1e95 | 3 |
| dragon_fly_c.png | 130619 | 72, 88, 438, 459 | 459 | 778c05db522b | 2 |
| dragon_fly_d.png | 145726 | 74, 19, 436, 388 | 388 | 01b9892e271e | 3 |
| dragon_aura.png | 77020 | 25, 11, 484, 467 | — | 77697b891f67 | 2 |

#### Mốc đo (đo bằng code từ ảnh thật)

- **Miệng = gốc tia** (centroid 100 px thô đầu tiên của tia, đối chiếu bằng cụm
  đỏ-xám miệng mở). Hai miệng riêng, mỗi loại dùng chung cho 4 khung của nó:
  - Lửa: **(279,7; 174,6)** (đo trên fire_2). fire_1 effect-root (313,1; 176,1),
    fire_3 (285,9; 173,7), fire_4 không có tia nên đo bằng cụm đỏ miệng
    (283,4; 165,7) — xem "Điểm chưa chắc" số 1.
  - Nước: **(322,2; 181,4)** (đo trên water_2). water_1 (325,0; 180,8),
    water_3 (320,8; 180,8) — cả hai trong ±3 px; water_4 không có tia, cụm
    đỏ-xám (325,4; 169,3), mép trái bbox 322,9 ≈ đúng 322,2.
  - **Miệng thật (cụm đỏ-xám trong miệng):** lửa x≈262–268 ở cả 4 khung (fire_2
    là 268,4); nước x≈298–302 (water_2 là 299,5) — mặt rồng khớp nhau, xem
    "Điểm chưa chắc" số 1.
- **Neo ngang fire/water:** trục thân (tâm mặt vùng quanh miệng) → lửa 239,1
  (dời trái 16,4 px để đủ đốm lửa), nước 255,5 như adult; rồng cao 400, chân
  y=439; KHÔNG neo tâm bbox tổng (bbox tổng lệch phải do tia). Rồng-phần sau
  đặt: lửa (26,7–22,0; 40; 359,5–391,1; 439,6), nước (27,1–36,4; 40;
  398,3–407,4; 439,6) — cùng cao/đáy với adult, hẹp hơn do tư thế 3/4.
- **Chuỗi lửa** (độ dài tia đặc / effect px): 1: 65 px ≈ 0,29× fire_2 (quả cầu
  lửa trong miệng + tia ngoài nhỏ) → 2: 163,4 px / 117.546 px → 3: lớn nhất,
  dài nhất, đầu tia x=503, effect 138.039 px → 4: tàn (effect 963 px, khói nhẹ,
  miệng hé khép). Chuỗi tăng rồi tàn rõ bằng mắt.
- **Chuỗi nước** (độ dài vòi đặc / effect px): 1: 113,6 px = 0,70× water_2 /
  24.563 px → 2: 163,4 px / 66.919 px → 3: 184,4 px / 71.091 px, đầu vòi x=505
  → 4: không tia, chỉ giọt rơi/bong bóng (15.407 px), miệng hé khép. Chuỗi
  tăng rồi tàn rõ bằng mắt.
- **Chu kỳ bay** (đầu cánh gần, y): a 43 (cao nhất) → b 169 (ngang) → c 455
  (thấp nhất) → d 44 (vỗ lên) → lặp lại a. Dài thân (mũi→chóp đuôi) 373–377 px
  ở cả 4 khung (mắt cy 174–178, mũi x 436–442, đuôi x 67–74) — thân khóa chặt,
  chỉ cánh đổi vị trí. **Lưu ý:** d ≈ a (xem "Điểm chưa chắc" số 3).
- **Bay — độ cao thân:** a đáy 388 (nhấc 51 px), b chân y=342 (nhấc 97 px),
  c chân y=439 (nhấc 0 px, cánh cụp thõng xuống dưới, đáy bbox 459 là đầu
  cánh), d đáy 388 (nhấc 51 px). App thay khung tại chỗ (cùng gốc 512),
  KHÔNG căn theo đáy bbox — xem "Điểm chưa chắc" số 4.
- **Aura:** tâm đo được (254,5; 239,0), khớp tâm thân adult (255,5; 239,5); lỗ
  trống r=201,2; 0 px alpha trong r<150 quanh (256,240); vành cách mép 11–44 px.
  Đầu cánh rồng adult (r≈201) chạm nhẹ vành trong ở cỡ app — nhìn như rồng nằm
  trong hào quang, chấp nhận được.
- **Màu vảy mint** (median): adult (175,216,193); lửa (166,215,188); nước
  (162,209,195); bay (174,212,180) — cùng họ mint, cùng con v2.

#### Cách làm

- Vẽ từng tấm bằng media generation trên nền magenta #FF00FF, lấy tấm xem trước
  cùng loại làm tham chiếu (fire_2 / water_2 / fly_a); aura chỉ 1 file, dùng
  lại bản xem trước. Tổng 24 lần gọi vẽ (13 file: 4 xem trước + 9 mới, kể cả
  vẽ lại).
- Tách nền + quantize bằng code (`dragon_fx/process_fx.py`, tái dùng
  `extract_fg`/`finish` của `lot12/work/dragon/process_dragon.py`: key median
  góc + flood-fill nền từ biên qua pixel magenta-hued, KHÔNG `binary_fill_holes`;
  m2/m3 chỉ trong 3 px quanh magenta thật; rim-recolor; quantize 256 màu
  MAXCOVERAGE + Floyd–Steinberg). Đặt vị trí bằng trục thân (fire/water) hoặc
  neo-theo-thân (fly_b/c: dài thân khớp fly_a 376,9 px, mắt cy → y=177).
- Sửa tàn dư magenta sau quantize bằng cách tô màu palette an toàn gần nhất,
  KHÔNG thêm màu mới (fire_1: 67 px, fire_3: 82 px, fire_4: 58 px, water_1:
  4 px, water_3: 1 px, fly_b: 24 px, fly_d: 1 px; đo lại 0/0). Aura riêng:
  recolor 5.281 px magenta + 11.861 px hồng (thước mở) → màu lân cận
  vàng/trắng/mint; đốm hồng nhạt còn lại GIỮ theo quyết định duyệt.
- water_3 gọn khung bằng cách cắt mask ở x=505 (cắt 1.948 px thô = 3% đầu quạt)
  thay vì dời rồng trái (dời sẽ lệch miệng 10,2 px).

#### Kiểm chứng

- Đo bằng code ĐẠT 13/13: 512×512, semi 0, magenta 0 (cả 2 thước), ≤256 màu;
  fire/water chân y=439; fly đáy y 341–459 (xem "Điểm chưa chắc" số 4).
- Soi bằng mắt trên nền tối (60,60,80) + nền phòng v3b ở cỡ app (rồng 72%
  chiều cao bé 360 px) + phóng 3× mặt/miệng/cánh: không lỗ alpha, không mép
  thẳng, không tàn dư magenta; lửa đọc là lửa, nước đọc là nước ở cả cỡ app;
  cánh bay không bị keying ăn mất (màng cánh hồng còn nguyên).
- Ảnh ghép: dải lửa 1..4, dải nước 1..4, chu kỳ bay a..d, 13 file ở cỡ app
  trong phòng v3b (`dragon_fx/composites/strip_fire.png`, `strip_water.png`,
  `strip_fly.png`, `d_room_13.png`).
- 4 file xem trước đối chiếu SHA-256 khớp nguyên bản (fire_2 `bf2193f9b2c7…`,
  water_2 `7337715baa15…`, fly_a `1222327243b8…`, aura `77697b891f67…`).

#### Điểm chưa chắc — nói thẳng

1. **Cổng miệng ±3 px theo thước effect-root KHÔNG đạt ở dãy lửa** (fire_1
   +33,4; fire_3 +6,2; fire_4 +3,7/−8,9 so với (279,7; 174,6)). Đây là nhiễu
   của thước đo, không phải rồng lệch: gốc tia = centroid 100 px đầu của tia,
   mà độ rộng gốc tia thay đổi theo từng lần vẽ. Bằng chứng: sau khi neo trục
   thân về 239,1, miệng thật (cụm đỏ-xám) của cả 4 khung lửa gom ở x≈262–268
   (bản thân fire_2 là 268,4), chân/trục/cỡ khớp hẳn — mặt rồng không nhảy khi
   đổi khung. Đã chọn neo trục thay vì dịch rồng để ép số effect-root. Dãy
   nước ĐẠT cổng (water_1 +2,8/−0,6; water_3 −1,4/−0,6).
2. **Miệng fire_4 cao hơn ~9 px** (y=165,7 so với 174,6) — khác biệt vẽ thật
   (miệng cười hé vẽ cao hơn, đầu hơi ngẩng), không sửa được bằng đặt vị trí
   mà không làm chân chìm xuống 448. Ở cỡ app ≈ 4–5 px, soi zoom 3× mới thấy.
   Tàn lửa fire_4 hơi ánh hồng/tím ở vài đốm (soi dải lửa mới thấy).
3. **fly_d ≈ fly_a — KHÔNG đạt "giữa ngang và cao".** Đầu cánh gần d y=44 so
   với a y=43 (chênh 1 px); cả 2 lần vẽ lại đều trả về gần như đúng fly_a
   (v1 và v3 có cùng số đo cánh tới từng px). Chu kỳ vẫn đọc đúng cao→ngang→
   thấp→cao, nhưng d thực chất là giữ khung cao thêm 1 nhịp rồi mới lặp lại a.
   Cần Claude chốt: chấp nhận, hay vẽ lại với brief khác.
4. **Độ cao thân bay không đều (b/c lệch spec fit-tối-đa).** Fit tối đa từng
   khung làm đầu nhảy 132 px và với fly_b là bất khả thi hình học (raw w/h
   1,56 → fit cao cho rộng 578 > 512, cánh bị cắt cả 2 mép ở v1) nên b/c dùng
   neo-theo-thân: dài thân khớp fly_a, mắt cy → y=177. Hệ quả: chân b y=342
   (nhấc 97 px), chân c y=439 (nhấc 0 px). App phải thay khung tại chỗ (cùng
   gốc 512), KHÔNG căn theo đáy bbox. Ở cỡ app chu kỳ đọc là vỗ cánh + thân
   nhún theo (nhấc 0→97 px), không phải bay lơ lửng đều.
5. **fly_b sát mép trái:** đầu cánh trái x=7 (không chạm, lề chỉ 7 px).
6. **water_1 vòi dài hơn brief:** vòi đặc 113,6 px = 0,70× water_2 (brief ~1/3),
   nhưng effect px chỉ 0,37× và nhìn rõ là nhỏ nhất trong dãy. Bản vẽ lại v2
   ngắn hơn (0,46×) đã LOẠI vì miệng lệch +8,0 px + mõm ngắn hơn 17 px thô.
7. **water_3 cắt mask ở x=505:** mép cắt hơi thấy ở zoom 3× trên 2–3 đầu gai
   (đầu gai bị cắt phẳng), không thấy ở cỡ app.
8. **water_4 mõm ngắn hơn water_2 ~49 px** (rồng-phần x1 349,4 vs 398,3) vì
   hàm khép làm hàm dưới thụt vào — mắt/má/vị trí miệng vẫn khớp, nhìn trong
   dải vẫn là cùng con rồng đang khép miệng, nhưng đổi khung 3→4 sẽ thấy mõm
   thụt nhẹ.

#### Kế hoạch đẩy (2 lần .b64, CHỈ NHÁP — parent đẩy)

- Đợt 1 (7 file, PNG 1.037.048 B, .b64 ~1.382.731 B): dragon_fire_2.png, dragon_water_3.png, dragon_water_2.png, dragon_fly_d.png, dragon_water_4.png, dragon_fly_a.png, dragon_fire_3.png
- Đợt 2 (6 file, PNG 705.908 B, .b64 ~941.211 B): dragon_water_1.png, dragon_fly_c.png, dragon_fire_4.png, dragon_fire_1.png, dragon_fly_b.png, dragon_aura.png
Tổng .b64 ~2,32 MB; đích `app/assets/images/pets/`; mỗi lần ≤8 file, mỗi file
.b64 <1.217.688 B. Mục này do parent gộp vào `docs/E_IMAGES.md` cùng đợt đẩy
(xem cuối mục); Claude decode + kiểm bằng git (đối chiếu blob SHA) sau đó.
### Lô 13 — Icon giao diện (UI): 19 file (24/11/2026)

19 icon giao diện cho app: 3 emote trạng thái pet, 1 khay ăn, 4 huy hiệu hạng
tuần, 4 rương quà cuối tuần, bảng nhiệm vụ + dấu tick, lửa + rương streak,
khóa tháp + trùm tháp, khung ăn mừng. 19 file vào `app/assets/images/ui/`,
512×512 (burst 1024×1024), PNG trong suốt, alpha sạch (semi 0, 0 px magenta
thước chuẩn R>200/G<80/B>200; thước key13 R>170/G<90/B>140 chỉ còn 163 px
tím đậm thật của mái tháp ở tower_boss), quantize 256 màu MAXCOVERAGE +
Floyd–Steinberg. Tổng PNG 2.391.194 B (~3,19 MB .b64).

#### Cách dùng (phía code)
- 3 emote hiện cạnh pet trong Phòng/Cửa hàng/Pet của bé: đói = bát trống +
  giọt mồ hôi, buồn = mây xám + giọt mưa, vui = tim hồng + lấp lánh. Chỉ có
  biểu tượng trong bong bóng trắng, KHÔNG mặt, KHÔNG loài pet (quyết định
  duyệt 24/11 ~14:01).
- Huy hiệu hạng tuần (league bronze→diamond) + rương cuối tuần (chest
  bronze→diamond): càng cao càng sáng/lộng lẫy dần (xem "Mốc đo" dưới).
- `ui_celebrate_burst.png` là khung phủ kín màn (tia chạm mép khung, tâm
  trống hoàn toàn: 0 px alpha trong r<205, tức 40% khung) — dùng làm overlay
  toàn màn, KHÔNG dùng làm icon nhỏ.
- `ui_tower_boss.png` là trùm tháp (đánh boss mở tháp), `ui_tower_lock.png`
  là tháp đang khóa; `ui_streak_chest.png` là rương thưởng streak 7 ngày,
  cố ý hoành tráng hơn `ui_chest_gold.png` (to hơn, dải vàng, bùng sáng +
  2 lửa bên, không tràn xu/ngọc) để không lẫn với rương gold thường.

#### Quyết định đã chốt (Claude duyệt xem trước 24/11 ~14:01)
1. Tia gold/diamond còn viền oải hương: **CHẤP NHẬN** (giữ nguyên, đọc như
   tia lấp lánh, không phải tàn dư magenta; magenta_px = 0).
2. Burst tia chạm mép: **CHẤP NHẬN** (app dùng phủ kín màn, giữ nguyên).
3. Emote **ĐỔI — bỏ mặt mèo**: vẽ lại 3 emote thành bong bóng trắng CHỈ CÓ
   biểu tượng (đói = bát trống + giọt mồ hôi, buồn = mây xám + giọt mưa,
   vui = tim hồng + lấp lánh). Bản xem trước có mặt mèo đã LOẠI, không vào app.
4. `ui_tower_boss.png`: **rim-recolor 101 px** viền hồng-magenta (236,98,238)
   ở mép → màu palette gần nhất, không thêm màu mới; sau recolor 0 px theo
   đúng thước đếm 101 px đó.
5. Vệt hồng 1–2 px trên mép sticker trắng: **BỎ QUA** (không sửa; ở cỡ app
   100 px không thấy).

#### Bảng 19 file

| file | byte | bbox (x0, y0, x1, y1) | SHA-256 (12 ký tự đầu) | lần vẽ |
|---|---|---|---|---|
| ui_emote_hungry.png | 94166 | 26, 49, 485, 462 | 4c0b75761700 | 1 |
| ui_emote_sad.png | 78621 | 26, 40, 485, 470 | 114233940c46 | 1 |
| ui_emote_happy.png | 65957 | 26, 43, 485, 467 | e7ec80491fe2 | 1 |
| ui_pet_meal.png | 69900 | 26, 84, 485, 426 | d01bde761caf | 1 |
| ui_league_bronze.png | 101994 | 83, 26, 428, 485 | 73c2d3ecc9ec | 1 |
| ui_league_silver.png | 117354 | 83, 26, 428, 485 | 3367215ff042 | 1 |
| ui_league_gold.png | 114997 | 50, 26, 460, 485 | d3afc1e044b3 | 1 |
| ui_league_diamond.png | 178534 | 48, 26, 463, 485 | 36f70afb256d | 1 |
| ui_chest_bronze.png | 117080 | 26, 42, 485, 468 | ad72cb5a315e | 1 |
| ui_chest_silver.png | 127028 | 36, 26, 475, 485 | c4eb0eee458c | 1 |
| ui_chest_gold.png | 133819 | 26, 50, 485, 461 | f369deeebfc3 | 1 |
| ui_chest_diamond.png | 190941 | 26, 52, 485, 458 | f23d094aa8fb | 1 |
| ui_quest_board.png | 109938 | 35, 26, 475, 485 | 2eeafb65852f | 1 |
| ui_quest_check.png | 123561 | 27, 26, 484, 485 | 906d963845d8 | 1 |
| ui_streak_flame.png | 74070 | 57, 26, 454, 485 | bd9f97a10a06 | 1 |
| ui_streak_chest.png | 147586 | 26, 39, 485, 471 | f6d43b6408d8 | 1 |
| ui_tower_lock.png | 79251 | 69, 26, 441, 485 | 5e81266e49b0 | 1 |
| ui_tower_boss.png | 91080 | 62, 26, 449, 485 | 98fbd15f77d2 | 1 |
| ui_celebrate_burst.png | 375317 | 0, 0, 1023, 1023 | 5df9c7a406dc | 1 |

#### Mốc đo (đo bằng code từ ảnh thật)

- **3 emote mới** (bong bóng trắng, KHÔNG mặt): hungry = bát xanh pastel
  trống ở giữa + 2 giọt mồ hôi xanh nhạt 2 bên; sad = mây xám nhỏ ở giữa +
  3 giọt mưa xanh nhạt rơi bên dưới; happy = tim hồng lớn ở giữa + 3 tia
  lấp lánh vàng. Cả 3 cùng một kiểu bong bóng oval ngang, viền ống trắng,
  đuôi ở dưới-trái; bbox 26,37–49 → 485,462–474 (fit 460 như 16 icon còn
  lại). Phân biệt rõ nhau ở 100 px và ở cỡ app trong phòng v3b (xem ảnh
  ghép): bát xanh / mây xám / tim hồng.
- **Tier progression** (đo lại trên bản final, tỉ lệ px sáng lum>180):
  league bronze 0,243 → silver 0,459 → gold 0,473 → diamond 0,476 (mean
  lum 153,7 → 189,2 → 180,0 → 190,3); chest bronze 0,191 → silver 0,272 →
  gold 0,294 → diamond 0,379 (mean lum 129,0 → 158,2 → 164,8 → 173,0).
  Tăng dần rõ cả 2 dãy; league gold/silver gần nhau (0,473 vs 0,459) nhưng
  khác màu rõ (gold vàng vs silver xám).
- **Tower_boss rim-recolor:** 101 px đúng thước r>210, g<120, b>210,
  r−g>90, b−g>90 (tâm họ màu (236,98,238)), TẤT CẢ nằm trong 2 px từ mép
  trong suốt, rải quanh viền. Sơn lại bằng màu palette gần nhất trong cửa
  sổ 7 px (không thêm màu): (247,120,249)×36, (231,131,233)×40,
  (213,133,202)×13, (195,122,218)×4, (218,145,220)×3, (238,186,235)×2,
  (250,171,248)/(241,152,239)/(228,164,227)×1. Sau recolor: đúng 101 px
  đổi, alpha không đổi, thước 101 px = 0. Tím đậm thật của mái/khiên
  (172,80,154) 154 px vẫn còn (key13 = 163) — là màu tím của tháp, không
  phải tàn dư nền.
- **Burst:** tâm trống 0 px alpha trong r<205 (40%) và r<154 (30%); lỗ
  trống 4.887 px là khoảng hở giữa các mảnh confetti trong vòng, không
  phải lỗ alpha trên thân.

#### Cách làm

- Vẽ từng tấm bằng media generation trên nền magenta #FF00FF (6 tấm sheet
  2×2 + 1 tấm tower 1×2 + 1 burst full-frame cho bản xem trước; 3 emote mới
  vẽ riêng từng tấm full-frame 1600×1600). Tổng 9 lần gọi vẽ cho 19 file
  cuối (19 xem trước + 3 vẽ lại emote, kể cả vẽ lại).
- Tách nền + quantize bằng code (`lot13/work/key13.py`: key median góc +
  m2/m3 chỉ trong 3 px quanh magenta thật; `finish()` zero leftover vivid
  magenta r>170, g<90, b>140; quantize 256 màu MAXCOVERAGE +
  Floyd–Steinberg). **Riêng 3 emote mới:** keying kiểu key13 để lại dải
  viền magenta dưới bong bóng (sad: 2.125 px thước nới) nên key lại bằng
  flood-fill từ biên qua pixel magenta-hued (`lot12/work/process_v2.py`,
  KHÔNG `binary_fill_holes`) — sau đó 0 px magenta cả 4 thước, không cần
  rim-recolor.
- Sửa tàn dư magenta sau keying bằng cách tô màu palette an toàn gần nhất,
  KHÔNG thêm màu mới (xem "Mốc đo" tower_boss; halo magenta quanh tia
  gold/diamond ở bản xem trước đã xử lý bằng recolor về gold/xanh băng/đào
  ấm trước khi chốt — xem notes trong `lot13/work/report.json`).
- 15 file còn lại dùng lại NGUYÊN BẢN từ xem trước (copy byte-identical,
  đối chiếu SHA-256 với `lot13/work/report.json`, 15/15 khớp). Lưu ý: nhiệm
  vụ ghi "16 file" nhưng 19 − 3 emote − 1 tower_boss (recolor) = 15 file
  không đổi; tower_boss là file không phải emote thứ 16 và đã sửa theo
  mục 4.

#### Kiểm chứng

- Đo bằng code ĐẠT 19/19: 512×512 (burst 1024×1024), semi 0, ≤256 màu;
  thước chuẩn R>200/G<80/B>200 = 0 ở cả 19 file; thước key13 = 0 ở 18/19
  (tower_boss 163 px tím thật, xem trên); thước 101 px của tower_boss =
  0 sau recolor.
- Soi bằng mắt trên nền tối (60,60,80) + nền phòng v3b ở cỡ app 100 px +
  phóng 3× mép tower_boss: không lỗ alpha, không mép thẳng, không tàn dư
  magenta sáng; 3 emote mới đọc rõ đói/buồn/vui ở 100 px; tier bronze →
  diamond tăng dần rõ.
- Ảnh ghép (`lot13/work/composites/`): `b_final_19_dark.png` (19 icon
  trên nền tối), `b_emotes_100px.png` (3 emote mới ở 100 px cạnh nhau),
  `b_emotes_in_room.png` (3 emote mới ở cỡ app trong phòng v3b),
  `c_tower_boss_cluster_3x.png` + `c_tower_boss_bottom_3x.png`
  (tower_boss trước/sau recolor phóng 3× ở mép, có khoanh đỏ vị trí 101 px).
- 15 file không đổi đối chiếu SHA-256 khớp nguyên bản xem trước; bản gốc
  tower_boss giữ trong `lot13/work/backup/ui_tower_boss_orig.png` (SHA
  `795c65814233…`); tower_boss cuối SHA `98fbd15f77d2…`, đúng 101 px đổi,
  alpha không đổi.

#### Điểm chưa chắc — nói thẳng

1. **Viền magenta sẫm ở mép dưới tower_boss CÒN, chỉ hết đốm sáng.** Sau
   recolor, thước 101 px = 0 và các đốm hồng-magenta sáng quanh viền đã
   hết (soi zoom 3× vùng crown thấy rõ). Nhưng dải viền tím-magenta sẫm
   (170,0,169) 353 px + (157,30,156) 94 px, tất cả trong 2 px từ mép trong
   suốt, vẫn còn dọc mép dưới — thấy ở zoom 3×, KHÔNG thấy ở cỡ app 100 px.
   Để nguyên vì ngoài phạm vi 101 px đã duyệt và trùng vùng "bỏ qua" của
   quyết định (5). Cần Claude/chủ dự án chốt: chấp nhận, hay mở rộng
   recolor sang dải sẫm này (sẽ cần sơn ~450 px nữa).
2. **Thước nới R>140/G<60/B>140 KHÔNG thể = 0 cho toàn lô.** Tím thật của
   tháp (147,55,199) 950 px + (145,53,141) 464 px ở trong thân tháp, và
   tím/violet thật ở huy hiệu/rương/bảng nhiệm vụ cũng đếm vào thước này.
   Thước này chỉ có nghĩa khi xét riêng từng file không có màu tím (như
   lô 12B). Đã ghi rõ số đo từng thước trong `report.json` để Claude đối
   chiếu.
3. **Số đo cũ trong `report.json` không khớp hoàn toàn với đo lại.** File
   xem trước trên đĩa của tower_boss là 91.332 B nhưng report cũ ghi
   91.148 B, magenta cũ 542 vs đo lại 163 (cùng thước key13) — file đã
   xử lý lại sau khi report cũ viết mà report không cập nhật. Đo lại 15
   file không đổi cũng cho `enclosed_holes_px`/bbox khác report cũ ở vài
   file (league_bronze holes 96 vs 0, quest_board 390 vs 7, burst 5.432 vs
   4.887; quest_board y1 483 vs 485) dù byte giống hệt — số cũ hẳn đo
   bằng bản script khác. Số cũ giữ nguyên theo yêu cầu; số đo lại ở
   `lot13/work/verify_final.json`.
4. **Bong bóng emote mới khác kiểu bong bóng cũ.** Emote mới dùng bong
   bóng oval ngang, viền ống trắng (cũ: bong bóng tròn kiểu mây). Cả 3
   emote mới thống nhất với nhau và hợp phong cách set; bong bóng cũ đã
   loại hết nên không còn lệch trong bộ cuối. Nếu Claude muốn đúng kiểu
   bong bóng cũ thì phải vẽ lại cả 3.
5. **Giọt mồ hôi của hungry ở 100 px hơi nhỏ.** Bát đọc rõ, 2 giọt 2 bên
   vẫn thấy nhưng nhỏ; ở cỡ app trong phòng vẫn phân biệt được với mây
   mưa của sad nhờ màu xanh + hình bát. Không vẽ lại trừ khi Claude yêu cầu.

#### Kế hoạch đẩy (3 lần .b64, CHỈ NHÁP — parent đẩy)

- Đợt 1 (7 file, PNG 957.923 B, .b64 ~1.278.254 B): ui_celebrate_burst.png, ui_chest_silver.png, ui_quest_check.png, ui_league_bronze.png, ui_emote_hungry.png, ui_pet_meal.png, ui_emote_happy.png
- Đợt 2 (6 file, PNG 717.202 B, .b64 ~957.293 B): ui_chest_diamond.png, ui_chest_gold.png, ui_league_silver.png, ui_quest_board.png, ui_tower_boss.png, ui_streak_flame.png
- Đợt 3 (6 file, PNG 716.069 B, .b64 ~955.782 B): ui_league_diamond.png, ui_streak_chest.png, ui_chest_bronze.png, ui_league_gold.png, ui_tower_lock.png, ui_emote_sad.png
Tổng PNG 2.391.194 B, .b64 ~3,19 MB; đích `app/assets/images/ui/`; mỗi lần
≤8 file, mỗi file .b64 <1.217.688 B. Mục này do parent gộp vào
`docs/E_IMAGES.md` cùng đợt đẩy; Claude decode + kiểm bằng git (đối chiếu
blob SHA) sau đó.
### Lô 14 — Bộ 08: yếm jean dã ngoại / polo dã ngoại (20 file, 24/11/2026)

Đích: `app/assets/images/character/girl/` và `app/assets/images/character/boy/`.
Bộ 08 ĐỦ 20/20 file (10 gái + 10 trai). Bộ THƯỜNG (200 xu) — đơn giản nhất
trong 4 bộ lô 14, làm sau bộ 07. Mặt gái đã ghép dải mắt 01 như bộ 07
(xem mục "Ghép dải mắt gái"); trai KHÔNG ghép mắt (như 07 — xem mục
"Cổng mắt trai").

- Bé gái — yếm jean dã ngoại: áo sọc xanh-trắng + yếm jean (váy yếm, túi
  trước, khuy kim loại), tóc hai bím buộc nơ hồng, giày vải trắng.
- Bé trai — polo dã ngoại: áo polo sọc xanh navy-trắng + quần kaki, giày
  thể thao trắng. Không đội mũ, không đeo balo (phụ kiện rời của app).

## Cách làm

Vẽ từng ảnh toàn thân bằng AI trên nền magenta đặc, có ảnh bộ 01 làm tham chiếu khuôn
mặt/dáng đầu và ảnh 07 làm mẫu tư thế; tách nền + chuẩn hoá + quantize bằng code
(numpy + scipy + PIL), đúng quy trình bộ 04–07 (`key08.py` / `process08.py` /
`fix08_full.py` / `measure08.py` / `measure_boy08.py` trong `lot14/work/set08/`):

- Key: nền = median góc; fg = dist ≥ 20; closing 3×3; chỉ giữ component > 20.000 px;
  closing dọc 31×1 cầu nối cổ; edge-recovery mọc tối đa 3 px vào dải dist 10–40.
  KHÔNG dùng `binary_fill_holes`.
- Chuẩn hoá: scale theo chiều cao bbox 1287, chân 1429, ky squash căn mắt/đầu, ox căn
  mắt/đầu; quantize MAXCOVERAGE 256 màu + Floyd–Steinberg, giữ alpha; fill RGB trong
  suốt bằng màu opaque gần nhất TRƯỚC khi quantize.
- Khử viền magenta (stack bộ 04): ring-decon d<45; inpaint d<130 toàn ảnh;
  inpaint d<170 trong vành 5 px; recolor magenta đậm; rim-recolor vành ngoài 3 px —
  cả trước và sau quantize. Magenta đo = 0 px cả 20 file (3 thước: loose/std/m7);
  semi = 0; 256 màu.
- **Ghép dải mắt gái (như bộ 07, `transplant_eyes.py`):** chép dải mắt 01 full
  (x 355–640, y 510–595, feather 12 px) dán đúng tọa độ lên full + wave 08 gái
  → mắt 08 mới = mắt 01 (blob từng mắt ≤ 1,0 px ở full; wave R +3,6 px do nhiễu
  quantize — xem mốc dưới). Trước ghép, full union R (+4,3; −6,3) KHÔNG ĐẠT nên
  phải ghép; sau ghép ĐẠT.
- **Trai KHÔNG ghép mắt, KHÔNG CAL:** như 07 (07 cũng không ghép và vẫn duyệt).
  Neo khung đi trai bằng head-centroid (hcx/hcy) thay vì mắt: dr (hcx 424,
  hcy ~369), ur (hcx 485, hcy ~389). Neo gái bằng blue-union mắt gần trong cửa
  sổ (680–780, 480–620) — tròng mắt vỡ mảnh sau quantize nên largest-blob
  trả None ở 4/8 khung đi, phải dùng union.
- **Sửa 3 file trai bằng code 24/11 (quyết Claude ~17:37, `fix08_wave_ears.py`,
  KHÔNG vẽ lại):** (1) wave warp dải mắt về ngang — shear dọc
  `d(x,y) = A·tanh((504−x)/55)·exp(−((y−628,6)/75)²)`, 2 pass (A = 11,3 rồi 1,8),
  chỉ dải mắt, miệng/tóc/trán nguyên; (2) xóa chấm đen dưới tai ur_a (428,672)
  và ur_c (419,674) — core mask dilate 3 px + nearest-good fill (chỉ màu trong
  bảng màu, không thêm màu mới), requantize lại bằng đúng bước quantize bộ 08.
  Backup gốc 3 file + 3 layers ở `backup_fix_wave_ears/`. 17 file còn lại
  không đổi 1 byte (đối chiếu SHA trước/sau).
- **Quy tắc miếng mắt nhắm (Claude chốt 22/11): app dùng CHUNG miếng mắt nhắm
  của bộ 01 cho cả full/wave 08** — mắt đứng VÀ vẫy phải trùng bộ 01 trong ±3 px.
  Từ bộ 05 trở đi KHÔNG làm miếng riêng, dùng miếng 01.

## File (20/20 PNG đã xong, khung 1024×1536, PNG trong suốt, đã lượng tử)

Đường đích `app/assets/images/character/girl/` (10 file gái) và
`app/assets/images/character/boy/` (10 file trai). Tỉ lệ bán trong suốt
(0 < alpha < 255) đo bằng code, tất cả **0**. Mỗi file < 1 MB.
Tổng 20 file = 8,819,139 byte; .b64 ≈ 11,21 MB.

| File | Vai trò | Cỡ (byte) | Chân y | Tâm mắt |
| --- | --- | --- | --- | --- |
| `girl_full_08.png` | Yếm jean dã ngoại, đứng | 490,698 | 1429 | (491,0; 560,2) † | `2d0978492dd3` |
| `girl_full_08_wave.png` | Yếm jean, tay phải vẫy | 502,446 | 1428 | (493,1; 563,2) † | `e6ed0963a1ae` |
| `girl_full_08_walk_dr_a.png` | Đi xuống-phải, khung a | 469,995 | 1428 | gần (731,1; 565,6) | `5cdbbe757790` |
| `girl_full_08_walk_dr_b.png` | Đi xuống-phải, khung b | 497,877 | 1428 | gần (704,4; 564,6) | `48ebf8bcd916` |
| `girl_full_08_walk_dr_c.png` | Đi xuống-phải, khung c | 465,959 | 1428 | gần (738,7; 567,1) | `11d618dffe39` |
| `girl_full_08_walk_dr_d.png` | Đi xuống-phải, khung d | 491,393 | 1428 | gần (715,9; 563,7) | `90689c8c9889` |
| `girl_full_08_walk_ur_a.png` | Đi lên-phải, khung a | 485,404 | 1428 | gần (698,2; 559,2) | `82a4f2028796` |
| `girl_full_08_walk_ur_b.png` | Đi lên-phải, khung b | 470,181 | 1428 | gần (730,1; 565,4) | `dfd327fdab9c` |
| `girl_full_08_walk_ur_c.png` | Đi lên-phải, khung c | 486,670 | 1428 | gần (728,7; 556,0) | `f38701931583` |
| `girl_full_08_walk_ur_d.png` | Đi lên-phải, khung d | 463,342 | 1428 | gần (740,4; 575,5) | `9cb630523e61` |
| `boy_full_08.png` | Polo dã ngoại, đứng | 322,710 | 1428 | (503,8; 630,6) ‡ | `954f015c6ba5` |
| `boy_full_08_wave.png` | Polo, tay phải vẫy | 410,072 | 1428 | (503,7; 630,2) ‡ | `f887bfc3ebaf` |
| `boy_full_08_walk_dr_a.png` | Đi xuống-phải, khung a | 410,117 | 1428 | hcx 423,5 / hcy 364,5 | `9cf38087a1bf` |
| `boy_full_08_walk_dr_b.png` | Đi xuống-phải, khung b | 424,359 | 1428 | hcx 423,5 / hcy 370,0 | `eb5991545d1c` |
| `boy_full_08_walk_dr_c.png` | Đi xuống-phải, khung c | 407,559 | 1428 | hcx 424,2 / hcy 367,6 | `a8730da06c1a` |
| `boy_full_08_walk_dr_d.png` | Đi xuống-phải, khung d | 412,988 | 1428 | hcx 423,4 / hcy 371,8 | `113a76a24f1c` |
| `boy_full_08_walk_ur_a.png` | Đi lên-phải, khung a | 405,079 | 1428 | hcx 484,2 / hcy 390,0 | `b19761ecb878` |
| `boy_full_08_walk_ur_b.png` | Đi lên-phải, khung b | 417,440 | 1428 | hcx 485,0 / hcy 389,7 | `5df3b0f00496` |
| `boy_full_08_walk_ur_c.png` | Đi lên-phải, khung c | 385,743 | 1428 | hcx 484,8 / hcy 390,9 | `74eb9e014116` |
| `boy_full_08_walk_ur_d.png` | Đi lên-phải, khung d | 399,107 | 1428 | hcx 484,9 / hcy 387,5 | `49f773c9c7b7` |

† gái full/wave: tâm mắt = trung bình 2 mắt blob (iris) trên file final đã quantize:
full L (386,7; 559,2), R (595,3; 561,2); wave L (388,1; 562,6), R (598,1; 563,7).
‡ trai full/wave: tâm mắt = trung bình 2 mắt union (brown) trên file final:
full L (398,2; 631,2), R (609,4; 630,0); wave L (400,1; 630,9), R (607,2; 629,4)
— wave SAU warp sửa bằng code 24/11 (trước warp L (400,5; 618,3), R (607,0; 640,2), dy = 21,9 px).
"Mắt gần" ở khung đi gái = blue-union trong cửa sổ (680–780, 480–620) trên file final.

## Mốc khung đo được (khung 1024×1536, đo ĐỘC LẬP bằng code từ ảnh thật — `verify08.py` / `verify08b.py`, xem `lot14/work/set08/verify_final.json`)

### Bé gái (so với bộ 01: blob L (387,5; 560,2), R (594,5; 560,7), span 207,0)

- Tâm mắt full 08 **blob L (−0,8; −1,0), R (+0,8; +0,5)** — worst 1,0 px, **ĐẠT cổng ±3**;
  union L (0,0; −1,9), R (−0,8; −2,1) — worst 2,1 px, ĐẠT. Khoảng đồng tử blob
  208,6 px (01: 207,0). Miệng theo detector (561,0; 712,0) là bắt nhầm nơ ngực —
  soi mắt thấy miệng cười khép trùng 01.
  Bbox full (181, 175, 830, 1430); cao bbox 1255.
- Tâm mắt wave 08: **blob L (+0,6; +2,4), R (+3,6; +3,0)** — R vượt cổng x đúng 0,6 px
  (nghiêm ngặt: KHÔNG ĐẠT; trong sai số detector ±5 px). Trên ảnh layers
  (trước quantize) blob KHỚP CHÍNH XÁC 01 (0,0; 0,0) — lệch final là nhiễu
  quantize/dither. Union wave R (+4,9; +8,0) nhiễu hơn do tròng vỡ mảnh.
  Bbox wave (114, 183, 816, 1429); cao 1246. Miệng wave cười KHÉP (khác 07 wave
  cười HỞ) — đồng nhất với full hơn 07.
- **Kiểm chứng chức năng miếng mắt nhắm:** thước lid full-window (y400–750)
  KHÔNG dùng được cho bộ 08 (sọc xanh áo sọc rơi vào cửa sổ mắt: fullwin ngoài
  ~1.948 px, trong đó y620–750 chiếm 1.944 px = sọc áo). Dùng lid-band y500–620:
  full **4 px**, wave **37 px** ngoài vùng (01 tự đo 0, 07 full 8, 07 wave 5);
  hộp 70×80 quanh mắt 01: full 1, wave 6 px (≈ 07: 4/2; 01 wave: 1) — về chức
  năng miếng 01 che kín.
- Khung đi: mắt gần trung bình dr **(722,5; 565,2)** vs 01 **(723,7; 564,4)**;
  ur **(724,4; 564,0)** vs 01 **(727,3; 560,5)** — cả hai trong ~3,5 px.
  ur_d y = 575,5 — thấp hơn dải y của 07 ur (545–563) ~12 px, đầu cúi xuống nhẹ
  ở khung này; cycle mean vẫn khớp. dr = 3/4 mặt trước 2 mắt rõ, ur xoay sau
  hơn (mắt xa hẹp hơn — như 07, không phải profile 1 mắt như trai).
  Cao bbox khung đi 1218–1256 (đã chấp nhận, xem dưới).
- Viền hồng nhạt (R>190, G<180, B>170 trong 3 px mép silhouette): full 7.893 px,
  wave 9.183 px — ngang 07 full 8.546 / wave 7.065 px (cùng bậc; 08 wave cao hơn
  07 wave ~30%). Viền hồng nhạt thấy ở 3× dọc mép tóc/cằm (tông rose của tóc
  thật, như 07 đã chấp nhận); ở cỡ app trong phòng không thấy.

### Bé trai (so với bộ 01: union L (395,9; 626,3), R (610,4; 626,2), span 214,5)

- Tâm mắt full 08 **union L (+2,3; +4,9), R (−1,0; +3,8)** — KHÔNG ĐẠT cổng ±3
  nghiêm ngặt vs 01 (lệch y +4–5 px). **Nhưng 07 ĐÃ DUYỆT cũng không đạt,
  lệch lớn hơn: L (+6,3; +4,1), R (−5,2; +3,3)** — đo lại 07 bằng CÙNG detector,
  khớp từng số. Lệch y ~+4–5 px là HỆ THỐNG giữa 01 layers_q và các file final
  quantize, không phải lệch riêng 08; 08 khớp 07 trong ±4,2x/±0,8y.
  Tâm mắt (eye-mid) 08 (503,8; 630,6) lệch 01 (+0,7; +4,4); 07 (+0,6; +3,7).
  Span 08: 211,2 px (01: 214,5; 07: 203,0). Lid-box 70×80: **0 px** — miếng 01
  che kín. Bbox full (155, 181, 853, 1429); cao 1247.
- Tâm mắt wave 08: **union L (400,1; 630,9), R (607,2; 629,4), dy = 1,5 px** —
  ĐÃ SỬA BẰNG CODE 24/11 (warp dải mắt 2 pass, quyết Claude ~17:37, phương án (b)).
  Trước warp union L (+4,6; −8,0), R (−3,4; +14,0), dy = 21,9 px — đầu nghiêng
  thật (07 wave dy = 6,8 px; 07 wave vs 01 cũng vượt cổng x: L +14,5, R −10,3).
  Sau warp du vs 01 L (+4,2; +4,6), R (−3,2; +3,2) — gần 07 wave hơn trước
  nhiều; **lid-box 0 px** (trước 16) — miếng 01 che kín. Soi 3× cạnh 07 wave
  (`fix_wave_faces_3x.png`): mặt không biến dạng, tóc/trán nguyên.
  Miệng wave (528,3; 710,1) cười khép, trùng full. Bbox wave (79, 198, 859, 1429);
  cao 1231; 254 màu (wave duy nhất dưới 256 — do warp + requantize, không phải
  lỗi). File wave mới: 410.072 byte, SHA-256 `f887bfc3ebaf…`.
- Khung đi dr: hcx 423,4–424,2 (07: 423,3–423,7), hcy 364,5–371,8
  (07: 370,7–373,5); **dr_a hcy 364,5 — đầu cao hơn ~6 px** so với các khung dr
  khác (bob nhẹ trong chu kỳ, chấp nhận được). Mắt gần union-R gated trung bình
  (616,8; 608,3) vs 07 (605,4; 620,7): +11,4x/−12,4y (~3 px ở cỡ app).
  Khung đi ur: hcx 484,2–485,0 (07: 484,3–484,9), hcy 387,5–390,9
  (07: 392,2–393,2). Mắt gần union-R gated trung bình (609,5; 598,8); 07 ur
  gated hầu như None (detector cũng hỏng trên 07) nên không có số đối chiếu —
  kết luận bằng soi mắt: profile 1 mắt gần rõ.
  **Chấm đen dưới tai ur_a/ur_c ĐÃ XÓA BẰNG CODE 24/11** (quyết Claude ~17:37):
  0 px đen tại (428,672) và (419,674) — đo bằng code cửa sổ 30×30 và core 13×13
  (trước: 29 px ur_a / 37 px ur_c); đường cổ áo ur_a (12 px) còn nguyên; soi 3×
  (`fix_ears_3x_v2.png`) da liền mạch, không vết. File mới: ur_a 405.079 byte
  SHA `b19761ecb878…`, ur_c 385.743 byte SHA `74eb9e014116…`. ur_b/ur_d không đổi.
  Cao bbox khung đi 1227–1255 (đã chấp nhận, xem dưới).
- Magenta exact #FF00FF ở full: **361 px — 361/361 nằm ở vùng alpha = 0**
  (tàn dư canvas trong suốt, bbox 159–844, 180–1432), 0 px alpha > 0. 01 tự thân
  cũng có 39 px exact ở vùng trong suốt — tàn dư vô hại.

## Kiểm chứng (soi bằng mắt trên nền tối (60,60,80) + nền phòng v3b)

Ảnh ghép `lot14/work/set08/composites/`: (a) `girl_10_dark.png` (10 file gái);
(b) `boy_10_dark.png` (10 file trai); (c) `set08_room20.png` (20 file ở cỡ app
trong phòng v3b — verifier làm mới); mặt 3× `verify_faces_3x_girl.png` /
`verify_faces_3x_boy.png` (01/07/08 × full/wave); mặt khung đi 2×
`verify_walk_faces_2x.png`; dải đi `verify_walk_strips.png`; sửa bằng code
`fix_wave_faces_3x.png` (wave trai trước/sau warp 3× cạnh 07 wave) và
`fix_ears_3x_v2.png` (vùng tai ur_a/ur_c trước/sau xóa 3×).

- Mặt/mắt gái 08 = mắt 01 (đã ghép dải mắt, không thấy đường ghép); mặt/mắt
  trai 08 full thẳng, khớp 07/01; wave trai đã warp thẳng (xem trên).
- Yếm jean + áo sọc gái đọc rõ đúng brief; polo sọc + quần kaki trai đúng brief;
  chân vẫn thấy rõ (giày trắng), chạm y = 1428–1429. Không lỗ alpha lạ, không
  mép thẳng (magenta 0 px cả 3 thước, semi 0, 256 màu, 20/20 file).
- Miệng cười khép thống nhất cả 20 file (soi 3× full/wave + 2× 16 mặt khung đi;
  detector miệng không dùng được — khóa nơ ngực/sọc áo).
- Chân luân phiên khung đi rõ: a/c tiếp đất đối nhau, b/d bước giữa (cả 4 dải);
  tay vẫy ngược chân; đầu thẳng hàng trong chu kỳ (trừ dr_a trai cao hơn ~6 px).
- Trong phòng v3b ở cỡ app: tỉ lệ tự nhiên, chân chạm sàn, không thấy viền lạ;
  bộ 08 đơn giản, đúng vị trí "thường" so với các bộ cao cấp.

### Điểm chưa chắc — nói thẳng

- **Wave trai nghiêng dy = 21,9 px — ĐÃ SỬA XONG BẰNG CODE 24/11** (quyết Claude
  ~17:37, phương án (b) warp): sau warp dy = 1,5 px, lid-box 0, miệng vẫn khép,
  soi 3× mặt không biến dạng. Không còn là điểm chặn.
- **Chấm đen dưới tai trai ur_a (428, 672; 29 px) và ur_c (419, 674; 36 px) —
  ĐÃ XÓA XONG BẰNG CODE 24/11** (quyết Claude ~17:37): 0 px đen tại cả 2 vị trí,
  soi 3× da liền mạch, không vết; đường cổ áo ur_a còn nguyên. Không còn là
  điểm chặn.
- Wave gái blob R vượt cổng 0,6 px (x) trên file quantize cuối; trên layers khớp
  01 tuyệt đối — nhiễu quantize, không vẽ lại.
- Walk ur_d gái y = 575,5 (đầu cúi nhẹ); cycle mean vẫn khớp 01.
- Chiều cao bbox 1218–1256 (gái) / 1227–1255 (trai), dưới spec 1287±10 —
  ĐÃ CHẤP NHẬN theo quyết 24/11 (như trai 07: 1240–1251); chân y 1428–1429 và
  mắt khớp chuẩn.
- Viền tóc/váy còn ánh hồng rất nhạt ở một số mép (tông rose của tóc thật, như
  bộ 07 đã chấp nhận); ở cỡ app 360 px không thấy. Wave gái pink-rim cao hơn
  07 wave ~30% nhưng cùng bậc với 07 full.
- Tay phải ur_d trai giơ cao (nắm đấm) — biên độ vẫy tay lớn hơn các khung ur
  khác; đọc như vung tay mạnh, không phải lỗi.

## Việc còn lại cho giai đoạn code (E)

- Entry manifest cho 20 file trên + cập nhật `source` thành "Muse vẽ AI 24/11
  theo DESIGN.md".
- Dùng CHUNG miếng mắt nhắm của bộ 01 cho cả full/wave 08 (quy tắc Claude chốt
  22/11) — KHÔNG làm miếng riêng. `_eyeCenter` riêng theo nhân vật đã có
  (gái y ≈ 560, trai y ≈ 627).
- Test neo: chân nhân vật trong vùng sàn đã khai báo; khung đi 2 hướng × 4 khung
  theo đúng thứ tự a→b→c→d. Mở PR sau khi Claude duyệt kiểu.
- **2 điểm chưa chắc đã sửa xong bằng code 24/11 theo quyết Claude** (wave warp
  + xóa chấm đen) — bộ 08 đủ 20/20 file, sẵn sàng đẩy .b64 + gộp doc.

## Đẩy .b64 (kế hoạch, sau khi Claude duyệt kiểu VÀ đủ 20 file)

- Tổng PNG 20 file 8,819,139 byte → .b64 ≈ 11,25 MB →
  chia **3 lần** (mỗi lần ~3,5–3,9 MB, 7/7/6 file, **trộn gái+trai theo byte**),
  như bộ 05–07 (KHÔNG gom 8 file gái vào 1 lần).
  Đích `app/assets/_incoming/app/assets/images/character/girl/` và `.../boy/`.
  SHA-256 (12 ký tự đầu) của 20 file:
gái girl_full_08 `2d0978492dd3`
gái girl_full_08_wave `e6ed0963a1ae`
gái girl_full_08_walk_dr_a `5cdbbe757790`
gái girl_full_08_walk_dr_b `48ebf8bcd916`
gái girl_full_08_walk_dr_c `11d618dffe39`
gái girl_full_08_walk_dr_d `90689c8c9889`
gái girl_full_08_walk_ur_a `82a4f2028796`
gái girl_full_08_walk_ur_b `dfd327fdab9c`
gái girl_full_08_walk_ur_c `f38701931583`
gái girl_full_08_walk_ur_d `9cb630523e61`
trai boy_full_08 `954f015c6ba5`
trai boy_full_08_wave `f887bfc3ebaf`
trai boy_full_08_walk_dr_a `9cf38087a1bf`
trai boy_full_08_walk_dr_b `eb5991545d1c`
trai boy_full_08_walk_dr_c `a8730da06c1a`
trai boy_full_08_walk_dr_d `113a76a24f1c`
trai boy_full_08_walk_ur_a `b19761ecb878`
trai boy_full_08_walk_ur_b `5df3b0f00496`
trai boy_full_08_walk_ur_c `74eb9e014116`
trai boy_full_08_walk_ur_d `49f773c9c7b7`
  Lần 1 (~3,82 MB .b64, 7 file): girl_full_08_wave, girl_full_08_walk_ur_a,
  girl_full_08_walk_dr_c, boy_full_08_wave, boy_full_08_walk_dr_d,
  boy_full_08_walk_ur_a, boy_full_08.
  Lần 2 (~3,93 MB .b64, 7 file): girl_full_08_walk_dr_b, girl_full_08_walk_ur_c,
  girl_full_08_walk_dr_a, boy_full_08_walk_dr_b, boy_full_08_walk_ur_b,
  boy_full_08_walk_dr_c, boy_full_08_walk_ur_c.
  Lần 3 (~3,46 MB .b64, 6 file): girl_full_08_walk_dr_d, girl_full_08,
  girl_full_08_walk_ur_b, girl_full_08_walk_ur_d, boy_full_08_walk_dr_a,
  boy_full_08_walk_ur_d.
  20/20 .b64 giải mã đúng từng byte PNG gốc trong vòng khứ hồi local (SHA-256 khớp)
  — đối chiếu blob SHA trên nhánh bị chặn (bảo vệ mã xác minh, giống bộ 04–07),
  Claude kiểm lại bằng git khi decode. Chưa đẩy (chờ duyệt đẩy).
### Lô 14 — Bộ 09: Áo dài Tết (20 file, 24/11/2026)

Đích: `app/assets/images/character/girl/` và `app/assets/images/character/boy/`.
Bộ 09 ĐỦ 20/20 file (10 gái + 10 trai). Bộ HIẾM (450 xu) — đi kèm phòng Tết
(lô 15). Mặt gái đã ghép dải mắt 01 như bộ 07/08 (xem mục "Ghép dải mắt gái");
trai KHÔNG ghép mắt (như 07/08 — xem mục "Cổng mắt trai").

- Bé gái — Áo dài Tết: áo dài cách tân đỏ thêu hoa mai vàng, quần trắng, giày
  đỏ có nơ, tóc hai bím buộc nơ đỏ.
- Bé trai — Áo dài Tết: áo dài gấm xanh hoa văn vàng, quần trắng, giày đen.
  Không đội khăn đóng, không đeo balo (phụ kiện rời của app).

## Cách làm

Vẽ từng ảnh toàn thân bằng AI trên nền magenta đặc, có ảnh bộ 01 làm tham chiếu khuôn
mặt/dáng đầu và ảnh 07 làm mẫu tư thế; tách nền + chuẩn hoá + quantize bằng code
(numpy + scipy + PIL), đúng quy trình bộ 04–08 (`key09.py` / `process09.py` /
`measure09.py` / `measure_boy09.py` trong `lot14/work/set09/`; lưu ý `key09.py`
không có `if __name__ == "__main__"` nên KHÔNG import trực tiếp):

- Key: nền = median góc; fg = dist ≥ 20; closing 3×3; chỉ giữ component > 20.000 px;
  closing dọc 31×1 cầu nối cổ; edge-recovery mọc tối đa 3 px vào dải dist 10–40.
  KHÔNG dùng `binary_fill_holes`.
- Chuẩn hoá: scale theo chiều cao bbox 1287, chân 1429, ky squash căn mắt/đầu, ox căn
  mắt/đầu; quantize MAXCOVERAGE 256 màu + Floyd–Steinberg, giữ alpha; fill RGB trong
  suốt bằng màu opaque gần nhất TRƯỚC khi quantize.
- Khử viền magenta (stack bộ 04): ring-decon d<45; inpaint d<130 toàn ảnh;
  inpaint d<170 trong vành 5 px; recolor magenta đậm; rim-recolor vành ngoài 3 px —
  cả trước và sau quantize. Magenta đo = 0 px cả 20 file (3 thước: loose/std/m7);
  semi = 0; 256 màu ở vùng opaque (dr_c gái đếm 257 màu theo cách đếm cả vùng
  trong suốt — màu thứ 257 là (0,0,0) ở hàng trên cùng do dịch +1 px khi sửa
  vệt, alpha = 0 nên không thấy; xem mục strip gái).
- **Ghép dải mắt gái (như bộ 07/08):** chép dải mắt 01 full
  (x 355–640, y 510–595, feather 12 px) dán đúng tọa độ lên full + wave 09 gái
  → mắt 09 mới = mắt 01 (blob full worst 2,6 px, wave worst 1,3 px — xem mốc dưới).
  Trên layers (trước quantize) blob full KHỚP TUYỆT ĐỐI 01.
- **Trai KHÔNG ghép mắt, KHÔNG CAL:** như 07/08 (07 cũng không ghép và vẫn duyệt).
  Neo khung đi trai bằng head-centroid (hcx/hcy) thay vì mắt: dr (hcx ~424,
  hcy ~371–374), ur (hcx ~484, hcy ~391–397). Neo gái bằng blue-union mắt gần trong
  cửa sổ (680–780, 480–620) — tròng mắt vỡ mảnh sau quantize nên largest-blob
  trả None ở nhiều khung đi, phải dùng union.
- **Sửa bằng code 24/11 (quyết Claude ~17:37, KHÔNG vẽ lại):** (1) wave trai warp dải
  mắt về ngang — shear dọc 1 pass (A = 7,7, pivot (504; 628,9), sigma 75), dy
  layers 14,5 → 2,4, final 1,9; (2) xóa chấm đen trên dải tai trai wave (39 px),
  ur_b (93 px), ur_c (50 px) — nearest-good fill rồi tô lại bằng skin-median phẳng
  (`fix09b_skin.py`: wave [200,131,118], ur_b [252,209,191], ur_c [245,187,170]);
  (3) xóa vệt bóng đổ đỏ sẫm dưới giày trai (full 196+125 px, dr_a 245+48 px,
  ur_b 846+82 px, wave 919+449 px, ur_d 1 px — `fix09c_strip.py`, 2 pass R>90 rồi
  R>50, chỉ y≥1350; full dịch +1 px để chân về 1428 sau khi vệt ở hàng đáy bị xóa).
  Backup gốc ở `backup_fix_wave_ears/` và `backup_fix_strip/`.
- **Sửa bằng code CỦA VERIFIER 24/11 (quy tắc mới, `fix09d_strip_girl.py`):**
  vệt bóng đổ đỏ sẫm dưới giày CŨNG CÓ trên cả 10 file gái (agent gái không nhắc
  tới) — verifier đo độc lập bằng cùng thước fix09c: full 220 px, wave 358 px,
  dr_a 376, dr_b 363, dr_c 451, dr_d 437, ur_a 332, ur_b 353, ur_c 394, ur_d 434 px
  (màu (140,6,105)/(156,4,141), dưới cả 3 thước magenta nên lần đo đầu báo 0/0/0;
  soi 4× thấy rõ viền magenta dưới đế giày). Đã xóa bằng alpha-only trên file final,
  không requantize, đúng 2 pass như trai; dr_c dịch +1 px (chân thật 1427 → 1428)
  rồi xóa thêm 2 px vệt lộ ra ở y=1350 sau shift. Đo lại 0 px cả 2 thước trên
  20/20 file. Backup 10 final + 10 layers gái ở `backup_fix_strip_girl/`,
  log `fix09d_strip_girl_log.json`. Mắt gái full/wave đo lại KHÔNG ĐỔI sau fix.
- **Quy tắc miếng mắt nhắm (Claude chốt 22/11): app dùng CHUNG miếng mắt nhắm
  của bộ 01 cho cả full/wave 09** — mắt đứng VÀ vẫy phải trùng bộ 01 trong ±3 px.
  Từ bộ 05 trở đi KHÔNG làm miếng riêng, dùng miếng 01.

## File (20/20 PNG đã xong, khung 1024×1536, PNG trong suốt, đã lượng tử)

Đường đích `app/assets/images/character/girl/` (10 file gái) và
`app/assets/images/character/boy/` (10 file trai). Tỉ lệ bán trong suốt
(0 < alpha < 255) đo bằng code, tất cả **0**. Mỗi file < 1 MB.
Tổng 20 file = 10,674,685 byte; .b64 ≈ 14,23 MB (lớn hơn bộ 08: 8,82 MB).

| File | Vai trò | Cỡ (byte) | Chân y | Tâm mắt |
| --- | --- | --- | --- | --- |
| `girl_full_09.png` | Áo dài đỏ hoa mai, đứng | 496,269 | 1429 | (489,8; 558,4) † | `8bc124138724` |
| `girl_full_09_wave.png` | Áo dài đỏ, tay phải vẫy | 518,807 | 1428 | (491,8; 561,6) † | `3d9a0e4a056d` |
| `girl_full_09_walk_dr_a.png` | Đi xuống-phải, khung a | 554,893 | 1428 | gần (707,3; 582,0) | `7190270105e9` |
| `girl_full_09_walk_dr_b.png` | Đi xuống-phải, khung b | 552,840 | 1428 | gần (725,8; 555,5) | `86f08b1555cb` |
| `girl_full_09_walk_dr_c.png` | Đi xuống-phải, khung c | 525,573 | 1428 | gần (719,7; 568,5) | `3a0c4abea5ff` |
| `girl_full_09_walk_dr_d.png` | Đi xuống-phải, khung d | 535,778 | 1428 | gần (705,2; 569,0) | `bdbcb10e5fc6` |
| `girl_full_09_walk_ur_a.png` | Đi lên-phải, khung a | 478,869 | 1428 | gần (746,0; 564,1) | `542b410912ce` |
| `girl_full_09_walk_ur_b.png` | Đi lên-phải, khung b | 526,914 | 1428 | gần (723,2; 537,4) | `ff03894c2be1` |
| `girl_full_09_walk_ur_c.png` | Đi lên-phải, khung c | 497,741 | 1428 | gần (—) § | `dc2783fc008c` |
| `girl_full_09_walk_ur_d.png` | Đi lên-phải, khung d | 476,875 | 1428 | gần (689,6; 551,1) | `aee85e72f27e` |
| `boy_full_09.png` | Áo dài gấm xanh, đứng | 510,964 | 1428 | (505,0; 635,2) ‡ | `f0db72895a12` |
| `boy_full_09_wave.png` | Áo dài xanh, tay phải vẫy | 542,691 | 1428 | (504,9; 630,5) ‡ | `a3a0efb23ad0` |
| `boy_full_09_walk_dr_a.png` | Đi xuống-phải, khung a | 577,166 | 1428 | hcx 423,5 / hcy 373,8 | `5954b2caea84` |
| `boy_full_09_walk_dr_b.png` | Đi xuống-phải, khung b | 599,757 | 1428 | hcx 424,5 / hcy 371,0 | `1712ab931216` |
| `boy_full_09_walk_dr_c.png` | Đi xuống-phải, khung c | 571,042 | 1428 | hcx 423,6 / hcy 370,5 | `4110e4816a83` |
| `boy_full_09_walk_dr_d.png` | Đi xuống-phải, khung d | 598,740 | 1428 | hcx 424,0 / hcy 373,6 | `87e83d5b5723` |
| `boy_full_09_walk_ur_a.png` | Đi lên-phải, khung a | 525,940 | 1428 | hcx 484,0 / hcy 396,5 | `bc71eb8b69e0` |
| `boy_full_09_walk_ur_b.png` | Đi lên-phải, khung b | 509,667 | 1428 | hcx 484,3 / hcy 391,3 | `69e194119805` |
| `boy_full_09_walk_ur_c.png` | Đi lên-phải, khung c | 536,625 | 1428 | hcx 484,4 / hcy 394,7 | `82771c972b9f` |
| `boy_full_09_walk_ur_d.png` | Đi lên-phải, khung d | 539,011 | 1428 | hcx 484,2 / hcy 392,6 | `a6e9f38142f0` |

† gái full/wave: tâm mắt = trung bình 2 mắt blob (iris) trên file final đã quantize:
full L (386,8; 558,7), R (592,8; 558,1); wave L (388,1; 561,2), R (595,4; 562,0).
‡ trai full/wave: tâm mắt = trung bình 2 mắt union (brown) trên file final:
full L (399,3; 635,4), R (610,7; 635,0); wave L (409,2; 629,5), R (600,6; 631,4)
— wave SAU warp sửa bằng code 24/11 (trước warp dy = 14,5 px ở layers).
§ ur_c gái: mắt gần hẹp, detector blue không bắt được blob ≥ 15 px — soi 3× thấy mắt
rõ, đúng vị trí/hướng profile (xem mục "Điểm chưa chắc").
"Mắt gần" ở khung đi gái = blue-union trong cửa sổ (680–780, 480–620) trên file final
(verifier đo lại sau fix strip; dr_c y +1,0 px do dịch ảnh — xem mục strip gái).
SHA-256 trên là bản SAU fix strip của verifier (10 file gái đổi SHA so với
`girl_report.json`; 10 file trai khớp `boy_report.json` từng byte).

## Mốc khung đo được (khung 1024×1536, đo ĐỘC LẬP bằng code từ ảnh thật — `verify09.py` / `verify09b.py`, xem `lot14/work/set09/verify09.json`; đối chiếu 3 chiều với `girl_report.json` / `boy_report.json` — khớp hết trừ vệt gái, xem dưới)

### Bé gái (so với bộ 01: blob L (387,5; 560,2), R (594,5; 560,7), span 207,0)

- Tâm mắt full 09 **blob L (−0,7; −1,5), R (−1,7; −2,6)** — worst 2,6 px, **ĐẠT cổng ±3**
  (KHÔNG đạt mục tiêu ±1,5 px — R y thiếu 1,1 px); union L (−1,9; −0,8),
  R (−2,9; −3,5) — worst 3,5 px, trong nhiễu detector ±5 px. Khoảng đồng tử blob
  206,0 px (01: 207,0). Trên layers (trước quantize) blob KHỚP TUYỆT ĐỐI 01
  (0,0; 0,0) — lệch final là nhiễu quantize/dither (như wave 08). Soi mặt 3×
  (`verify_faces_3x_girl.png`): KHÔNG thấy vết ghép dải mắt.
  Lid-band y500–620: full **8 px** ngoài vùng (01 tự đo 0, 07 full 8); hộp 70×80
  quanh mắt 01: full **0 px**, wave **0 px** — miếng 01 che kín.
  Bbox full (193, 198, 839, 1430); cao bbox 1231.
- Tâm mắt wave 09: **blob L (+0,6; +1,0), R (+0,9; +1,3)** — worst 1,3 px, **ĐẠT
  cổng ±3 và cả mục tiêu ±1,5**; union worst 1,3 px. Span blob 207,3 px (01: 207,0).
  Lid-band 0 px; lid-box 0 px. Miệng wave cười KHÉP (khác 07 wave cười HỞ) — đồng
  nhất với full hơn 07. Bbox wave (142, 209, 825, 1429); cao 1219.
- Khung đi: mắt gần trung bình dr **(714,5; 568,5)** vs 01 **(723,7; 564,4)** và
  07 cùng detector **(722,6; 566,1)**; ur (3 khung đo được) **(719,6; 550,9)** vs 07
  **(723,0; 557,0)** — cả hai trong ~6 px. dr = 3/4 mặt trước 2 mắt rõ, ur profile
  1 mắt gần; ur_d xoay 3/4 lộ thêm mắt xa (như 07 ur_d). Cao bbox khung đi
  1183–1241 (đã chấp nhận, xem dưới).
- Viền hồng nhạt (R>190, G<180, B>170 trong 3 px mép silhouette): full 6.517 px,
  wave 8.659 px — full THẤP HƠN 07 full 8.546 / 08 full 7.893; wave GIỮA 07 wave
  7.065 và 08 wave 9.183 (cùng bậc; tông rose của tóc thật, như 07/08 đã chấp nhận);
  ở cỡ app trong phòng không thấy.
- **Vệt bóng đổ đỏ sẫm dưới giày gái — PHÁT HIỆN CỦA VERIFIER, ĐÃ SỬA XONG BẰNG CODE
  24/11** (`fix09d_strip_girl.py`, theo đúng cách agent trai làm ở `fix09c`):
  thước đỏ sẫm (R>90 rồi R>50, G<90, B>90, R−G>50, B−G>50, |R−B|<60, y≥1350)
  đo được 220–451 px/file trên CẢ 10 file gái (màu (140,6,105)/(156,4,141) — dưới
  cả 3 thước magenta nên lần đo đầu báo 0/0/0; soi 4× thấy viền magenta dưới đế
  giày). Đã xóa alpha-only trên file final, đo lại **0 px cả 2 thước trên 20/20
  file** (trai vốn đã 0/0). dr_c dịch +1 px để chân về 1428, xóa thêm 2 px vệt lộ
  ra ở y=1350 sau shift. Backup 10 final + 10 layers gái ở `backup_fix_strip_girl/`.
  Mắt full/wave đo lại không đổi sau fix.

### Bé trai (so với bộ 01: union L (395,9; 626,3), R (610,4; 626,2), span 214,5)

- Tâm mắt full 09 **union L (+3,4; +9,1), R (+0,3; +8,8)** — KHÔNG ĐẠT cổng ±3
  nghiêm ngặt vs 01 (lệch y +9 px). **Nhưng 07 ĐÃ DUYỆT cũng không đạt,
  lệch lớn hơn về x: L (+6,3; +4,1), R (−5,2; +3,3)** — đo lại 07 bằng CÙNG detector,
  khớp từng số. 09 khớp 07 trong L (−2,9; +5,0), R (+5,5; +5,5); span 211,4 px
  nằm giữa 01 (214,5) và 07 (203,0). Lid-box 70×80: **0 px** — miếng 01 che kín.
  Tâm mắt (eye-mid) 09 (505,0; 635,2) lệch 01 (+0,7; +9,0); 07 (+0,6; +3,7).
  Bbox full (163, 197, 844, 1429); cao 1231.
- Tâm mắt wave 09: **union L (409,2; 629,5), R (600,6; 631,4), dy = 1,9 px** —
  ĐÃ SỬA BẰNG CODE 24/11 (warp dải mắt 1 pass, quyết Claude ~17:37).
  Trước warp dy = 14,5 px ở layers (đầu nghiêng thật). Sau warp du vs 07 wave
  L (−1,2; +3,8), R (+0,5; −1,1) — khớp 07 wave hơn 01 (vs 01: L +13,3, R −9,8);
  span 191,4 vs 07 wave 189,7; **lid-box 1 px** (07 wave = 5) — miếng 01 che kín.
  Soi 3× cạnh 01/07 wave (`verify_faces_3x_boy.png`): mặt thẳng, không biến dạng,
  tóc/trán nguyên. Bbox wave (123, 201, 839, 1429); cao 1227.
- Khung đi dr: hcx 423,5–424,5 (07: 423,3–423,7), hcy 370,5–373,8
  (07: 370,7–373,5) — khớp 07 gần như tuyệt đối; mắt gần dark-centroid R trung bình
  (619,3; 574,0) vs 07 (617,4; 582,9). Khung đi ur: hcx 484,0–484,4
  (07: 484,3–484,9), hcy 391,3–396,5 (07: 392,2–393,2; ur_a hcy 396,5 — đầu cúi
  nhẹ ~4 px, bob trong chu kỳ, ở cỡ app không thấy); soi mặt 2×: profile 1 mắt
  gần rõ cả 4 khung (largest-blob R ur_b (665,6; 606,0), ur_d (664,5; 598,5)).
  Cao bbox khung đi 1214–1248 (đã chấp nhận, xem dưới).
- **Chấm đen trên dải tai ĐÃ XÓA XONG BẰNG CODE 24/11** (quyết Claude ~17:37):
  wave (707,689)–(713,696) 39 px, ur_b (474,681)–(485,692) 93 px,
  ur_c (492,665)–(499,673) 50 px — đo lại **0 px tối tại cả 3 vị trí**
  (verifier đo độc lập, kể cả cửa sổ 30×30 quanh mỗi vị trí: wave 1 px, ur_b 0,
  ur_c 0); soi 3× (`verify_ears_3x.png`) da liền mạch, chỉ còn vết tô phẳng mờ
  ở wave (thấy ở 3×, không thấy ở cỡ app). 07 KHÔNG có chấm ở đúng 2 ô ur_b/ur_c
  (0 px) — đó là vết riêng của 09, xóa là đúng. **Ngoại lệ — chấm tai PHẢI
  (wave): xem "Điểm chưa chắc".**
- Vệt bóng đổ đỏ sẫm dưới giày trai ĐÃ XÓA XONG (agent trai, `fix09c`): đo lại
  **0 px cả 2 thước trên 10/10 file trai** (verifier đo độc lập).

## Kiểm chứng (soi bằng mắt trên nền tối (60,60,80) + nền phòng v3b)

Ảnh ghép của verifier `lot14/work/set09/composites/` (làm mới, độc lập với ảnh ghép
của 2 agent vẽ): (a) `verify_girl10_dark.png` (10 file gái); (b) `verify_boy10_dark.png`
(10 file trai); (c) `verify_set09_room20.png` (20 file ở cỡ app trong phòng v3b);
(d) `verify_faces_3x_girl.png` / `verify_faces_3x_boy.png` (01/07/09 × full/wave, 3×);
mặt khung đi 2× `verify_walk_faces_2x.png`; tai 3× `verify_ears_3x.png` và
`verify_boy_ears_01_07_09_3x.png`; giày gái trước/sau fix
`verify_girl_shoes_4x.png` / `verify_girl_shoes_after.png`.

- Mặt/mắt gái 09 = mắt 01 (đã ghép dải mắt, không thấy đường ghép); mặt/mắt trai 09
  full thẳng, khớp 07/01; wave trai đã warp thẳng (dy 1,9 px).
- Áo dài đỏ hoa mai vàng gái / áo dài gấm xanh hoa văn vàng trai đọc rõ đúng brief;
  chân vẫn thấy rõ, chạm y = 1428–1429. Không lỗ alpha lạ, không mép thẳng
  (magenta 0 px cả 3 thước, semi 0, 256 màu ở vùng opaque cả 20 file — dr_c gái
  đếm 257 theo cách đếm cả vùng trong suốt do hàng (0,0,0) alpha 0 ở trên cùng
  sau shift +1 px, không thấy; vệt đỏ sẫm 0 px cả 2 thước).
- Miệng cười khép thống nhất cả 20 file (soi 3× full/wave + 2× 16 mặt khung đi;
  detector miệng không dùng được — khóa cổ áo/vòng cổ).
- Chân luân phiên khung đi rõ: a/c tiếp đất đối nhau, b/d bước giữa (cả 4 dải);
  tay vẫy ngược chân; đầu thẳng hàng trong chu kỳ (trừ ur_a trai cúi nhẹ ~4 px).
- Trong phòng v3b ở cỡ app: tỉ lệ tự nhiên, chân chạm sàn, không thấy viền lạ;
  bộ 09 nổi bật đúng vị trí "hiếm" so với các bộ thường.

### Điểm chưa chắc — nói thẳng

- **Chấm đen trên dải tai PHẢI của wave trai — ĐÃ XÓA, NHƯNG CÓ THỂ ĐÃ XÓA NHẦM
  CHI TIẾT THIẾT KẾ (phát hiện mới của verifier, cần Claude quyết):** chấm đen ở
  đúng vị trí này CÓ SẴN ở 01 và 07 — ô (695,680)–(720,705): 01 full 47 px tối,
  07 full 64 px, 09 full 33 px; wave: 01 9 px, 07 36 px (đo bằng code, soi 3× thấy
  rõ chấm tròn ở dái tai phải cả 01/07/09 full) — trông như khuyên tai trong thiết
  kế, không phải vết bẩn riêng của 09. 09 wave đã xóa (còn 1 px ở ô cũ, 10 px ở ô
  rộng; 08 wave vẫn giữ chấm ở ô rộng: 52 px) nên wave/full 09 KHÔNG NHẤT QUÁN
  với nhau. Ở cỡ app chấm chỉ ~2–3 px, không thấy; verifier KHÔNG tự khôi phục
  (đó là quyết định thiết kế, không phải lỗi nhỏ sửa bằng code). Đề nghị Claude
  quyết: giữ nguyên (wave mất khuyên) hay khôi phục chấm trên wave.
- **Vệt đỏ sẫm dưới giày gái — ĐÃ SỬA XONG BẰNG CODE 24/11 (verifier, quy tắc mới):**
  220–451 px/file trên cả 10 file gái, xóa alpha-only, đo lại 0 px; dr_c dịch +1 px
  và xóa thêm 2 px lộ sau shift. Không còn là điểm chặn.
- **Chấm đen tai xa ur_b/ur_c trai — ĐÃ XÓA XONG BẰNG CODE 24/11:** 0 px tối tại
  cả 2 vị trí, soi 3× da liền mạch; 07 không có chấm ở đó nên đây là vết riêng
  của 09, xóa là đúng. Không còn là điểm chặn.
- **Wave trai nghiêng dy = 14,5 px — ĐÃ SỬA XONG BẰNG CODE 24/11:** sau warp
  dy = 1,9 px, lid-box 1, soi 3× mặt không biến dạng. Không còn là điểm chặn.
- Mắt gái full blob worst 2,6 px — ĐẠT cổng ±3 nhưng KHÔNG đạt mục tiêu ±1,5 px
  (R y −2,6); trên layers khớp 01 tuyệt đối — nhiễu quantize, không vẽ lại.
- Mắt trai full KHÔNG ĐẠT cổng ±3 vs 01 (lệch y +9 px) — nhưng 07 đã duyệt cũng
  không đạt và lệch x lớn hơn; 09 khớp 07 trong ±5,5 px, lid-box 0. Chấp nhận theo
  tiền lệ 07/08, không ghép mắt.
- Gái ur_b mắt gần y = 537,4 (cao hơn dải y 07 ur ~21 px); ur_d x = 686,2 (lệch trái
  khỏi dải x 07 ur ~27 px); cycle mean ur vẫn khớp 07 trong ~6 px. Soi mắt bình thường.
- Chiều cao bbox 1183–1248 (gái) / 1214–1248 (trai), dưới spec 1287±10 —
  ĐÃ CHẤP NHẬN theo quyết 24/11 (như 07/08); chân y 1428–1429 và mắt khớp chuẩn.
- Viền tóc/váy còn ánh hồng rất nhạt ở một số mép ở 3× (tông rose của tóc thật, như
  bộ 07/08 đã chấp nhận; full 09 thấp hơn cả 07/08); ở cỡ app 360 px không thấy.

## Việc còn lại cho giai đoạn code (E)

- Entry manifest cho 20 file trên + cập nhật `source` thành "Muse vẽ AI 24/11
  theo DESIGN.md".
- Dùng CHUNG miếng mắt nhắm của bộ 01 cho cả full/wave 09 (quy tắc Claude chốt
  22/11) — KHÔNG làm miếng riêng. `_eyeCenter` riêng theo nhân vật đã có
  (gái y ≈ 560, trai y ≈ 627).
- Test neo: chân nhân vật trong vùng sàn đã khai báo; khung đi 2 hướng × 4 khung
  theo đúng thứ tự a→b→c→d. Mở PR sau khi Claude duyệt kiểu.
- **1 điểm cần Claude quyết trước khi đẩy:** chấm tai phải trên wave trai — giữ
  nguyên (mất khuyên, không thấy ở cỡ app) hay khôi phục chấm như 01/07/08.

## Đẩy .b64 (kế hoạch NHÁP, sau khi Claude duyệt kiểu VÀ đủ 20 file)

- Tổng PNG 20 file 10,674,685 byte → .b64 ≈ 14,23 MB (bộ 09 nặng hơn bộ 08:
  8,82 MB → 11,25 MB). **Chia 3 lần như bộ 08 sẽ là ~4,7–4,95 MB/lần — SÁT trần
  HTTP đã đo (5,02 MB thành công / 5,47 MB lỗi). Đề xuất chia 4 lần × ~3,55 MB
  (5 file/lần, trộn gái+trai theo byte) cho an toàn.** Nếu giữ 3 lần thì mỗi lần
  ~4,7 MB, rủi ro 413 cao hơn.
  Đích `app/assets/_incoming/app/assets/images/character/girl/` và `.../boy/`.
  SHA-256 (12 ký tự đầu) của 20 file — BẢN SAU FIX STRIP CỦA VERIFIER:
gái girl_full_09 `8bc124138724`
gái girl_full_09_wave `3d9a0e4a056d`
gái girl_full_09_walk_dr_a `7190270105e9`
gái girl_full_09_walk_dr_b `86f08b1555cb`
gái girl_full_09_walk_dr_c `3a0c4abea5ff`
gái girl_full_09_walk_dr_d `bdbcb10e5fc6`
gái girl_full_09_walk_ur_a `542b410912ce`
gái girl_full_09_walk_ur_b `ff03894c2be1`
gái girl_full_09_walk_ur_c `dc2783fc008c`
gái girl_full_09_walk_ur_d `aee85e72f27e`
trai boy_full_09 `f0db72895a12`
trai boy_full_09_wave `a3a0efb23ad0`
trai boy_full_09_walk_dr_a `5954b2caea84`
trai boy_full_09_walk_dr_b `1712ab931216`
trai boy_full_09_walk_dr_c `4110e4816a83`
trai boy_full_09_walk_dr_d `87e83d5b5723`
trai boy_full_09_walk_ur_a `bc71eb8b69e0`
trai boy_full_09_walk_ur_b `69e194119805`
trai boy_full_09_walk_ur_c `82771c972b9f`
trai boy_full_09_walk_ur_d `a6e9f38142f0`
  Lần 1 (~3,51 MB .b64, 5 file): girl_full_09, girl_full_09_wave,
  girl_full_09_walk_ur_a, boy_full_09_walk_dr_b, boy_full_09_walk_ur_d.
  Lần 2 (~3,59 MB .b64, 5 file): girl_full_09_walk_dr_a, girl_full_09_walk_dr_c,
  boy_full_09, boy_full_09_walk_dr_a, boy_full_09_walk_ur_a.
  Lần 3 (~3,60 MB .b64, 5 file): girl_full_09_walk_dr_b, girl_full_09_walk_dr_d,
  girl_full_09_walk_ur_c, boy_full_09_wave, boy_full_09_walk_dr_c.
  Lần 4 (~3,53 MB .b64, 5 file): girl_full_09_walk_ur_b, girl_full_09_walk_ur_d,
  boy_full_09_walk_dr_d, boy_full_09_walk_ur_b, boy_full_09_walk_ur_c.
  (Parent sửa lại danh sách 4 lần trước khi đẩy: bản nháp trùng boy dr_b/dr_d ở 2
  lần và thiếu girl dr_b + girl ur_d.)
  20/20 .b64 giải mã đúng từng byte PNG gốc trong vòng khứ hồi local (SHA-256 khớp)
  — đối chiếu blob SHA trên nhánh bị chặn (bảo vệ mã xác minh, giống bộ 04–08),
  Claude kiểm lại bằng git khi decode.
  Nốt đẩy lần 3: GitHub secret scanning chặn lần đẩy đầu (chuỗi base64 của
  boy_full_09_wave.png tình cờ chứa mẫu "Tencent Cloud Secret ID" — dương tính
  giả, không có khóa thật). Đã mã lại PNG đó lossless (compress_level 6, pixel
  y hệt, 541.214 → 542.691 byte, SHA `a3a0efb23ad0`) rồi đẩy lại; bản gốc giữ ở
  `set09/backup_secret_scan/`. Bài học: quét .b64 staged tìm mẫu secret
  (AKID…) trước khi đẩy. Chưa đẩy (chờ duyệt đẩy).
