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

**Ghi chú (đã làm trong code):** bảng đề xuất 33/43/58/69% ở trên KHÔNG
được dùng nguyên. Code (`app/lib/features/room/pet_growth.dart`,
`petHeightRatio`) chốt **trứng 30%, mới nở 40%, nhỡ 58%, trưởng thành 72%**
của nhân vật cao 360 px; nhỡ 58% giữ đúng như chủ dự án đã duyệt. Pet lớn
theo số ngày bé xong trọn đề ngày (mới nở 0–2, nhỡ 3–7, lớn từ 8). Bảng
hiện hành nằm ở `docs/ASSETS.md` mục "Thang cỡ pet"; test thứ tự cỡ + nhỡ
= 208,8 px ở `app/test/features/room/room_walk_test.dart`.

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

**Ghi chú (đã làm trong code, PR #34):** entry manifest đã thêm (loại
`character_full`, `character_patch`). Không sửa `CharacterView` mà viết
widget mới `KidSprite` (`app/lib/features/character/kid_sprite.dart`) dùng
ảnh toàn thân + patch mắt nhắm theo rect từng ảnh (`kid_assets.dart`,
`kidEyePatch`); không còn `_eyeCenter`. `CharacterView` chỉ còn là legacy.
Thang cỡ pet: xem ghi chú ở trên.

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

**Ghi chú (đã làm trong code):** như lô 1 — `KidSprite` + `kidEyePatch`
(bé trai: patch chung cho 3 ảnh nghỉ, patch riêng cho mỗi ảnh vẫy); không
chỉnh `_eyeCenter`.
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

**Ghi chú (đã làm trong code, quyết định khác dự kiến):** phụ kiện vẽ bằng
`KidSprite` (không phải `CharacterView`). Mũ/nơ-kẹp (`kidHeadAccessories`),
kính (`kidGlassesAsset`) và giày trắng (`kidWhiteShoesAsset`) là lớp phủ
cùng khung. **Balo KHÔNG vẽ chồng**: dùng biến thể ảnh toàn thân
`..._backpack` (xem mục "fix3 giai đoạn 2 — balo") qua `kidFullAsset(...,
backpack: true)`. Lựa chọn lưu bằng `KidLookService` (`kid_head_accessory`,
`kid_glasses`, `kid_white_shoes`, `kid_backpack`) và đổi trong Tủ đồ ở
màn Phòng (`room_screen.dart`). Hiện trạng đầy đủ: `docs/ASSETS.md` mục
"Nhân vật toàn thân (hiện hành)".

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

**Ghi chú (đã làm trong code, PR #34):** quyết định ở mục phụ kiện — khung
đi bộ thật CHỈ dùng khi bé không đeo kính/giày trắng/balo/phụ kiện đầu
(`_hasWalkFrames` trong `kid_sprite.dart`); đang đeo món nào thì khi đi dùng
ảnh đứng + nhún bước. Khi hiện khung đi bộ thì không chớp mắt và không vẽ
lớp phủ, nên không cần neo lại theo mắt-x từng khung. Đi lại trong Phòng đã
làm ở `app/lib/features/room/room_walk.dart` (`kidWalkFrames` chọn `dr`/`ur`).

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
