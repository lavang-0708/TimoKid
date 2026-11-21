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
- Miệng cười: tâm **(517, 835)**.
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
