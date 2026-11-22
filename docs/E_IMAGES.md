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

