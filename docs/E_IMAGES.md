# Nhân vật bé gái v3b — (E) lô 1

Lô 1 chỉ làm **bé gái** (thân, 3 bộ đồ, mắt, miệng, tay rời, tóc, giày).
Bé trai (lô 2), phụ kiện (lô 3), khung đi bộ (lô 4) làm riêng.
Nguồn: Muse vẽ AI 21/11 theo `docs/DESIGN.md`, từ bản gốc nữ v3 đã
được chủ dự án duyệt (xem trước 1 + 2). Trong app mỗi lần chỉ có **một**
nhân vật, nam hoặc nữ theo lựa chọn ở màn mở đầu, cộng thêm pet của bé.

## Cách làm

Vẽ 5 biến thể toàn thân trên nền magenta đặc (bản gốc bộ 1, bộ 2 váy
tím, bộ 3 váy hồng + tạp dề trắng, mắt nhắm, tay giơ vẫy), rồi tách
lớp bằng code (numpy + scipy): chroma-key theo hue + saturation + kênh
G, tách bằng không gian + connected component (tóc và da/váy chồng hue
nhau nên màu chỉ phụ). Váy lấy bằng diff giữa các biến thể. Không nướng
bóng đổ — app vẽ bóng ellipse mềm như phòng/thị trấn.

## File (13 lớp, khung 1024×1536, PNG trong suốt)

Đường đích `app/assets/images/character/girl/`. Tỉ lệ bán trong suốt
(0 < alpha < 255) đo bằng code, tất cả **0,0000**. Mỗi file < 1 MB.

| File | Lớp | Vai trò | Cỡ (byte) |
| --- | --- | --- | --- |
| `girl_body_01.png` | `body` | Thân gốc: đầu + thân + chân, da | 210.273 |
| `girl_top_01.png` | `top` | Váy hồng nơ to (bộ 1) | 184.235 |
| `girl_top_02.png` | `top` | Váy tím nơ (bộ 2) | 200.420 |
| `girl_top_03.png` | `top` | Váy hồng + tạp dề trắng bèo (bộ 3) | 224.985 |
| `girl_eyes_open.png` | `eyes` | Mắt mở (mắt xanh to có ánh) | 36.671 |
| `girl_eyes_closed.png` | `eyes` | Mắt nhắm (đường mi cong) | 12.892 |
| `girl_mouth_smile.png` | `mouth` | Miệng cười | 17.341 |
| `girl_arm_left.png` | `arm` | Tay trái nghỉ (thả xuôi) | 22.272 |
| `girl_arm_right.png` | `arm` | Tay phải nghỉ (thả xuôi) | 23.459 |
| `girl_arm_wave.png` | `arm` | Tay phải giơ lên vẫy | 46.952 |
| `girl_hair_back_01.png` | `hair_back` | Tóc sau (xám, nhuộm được) | 285.223 |
| `girl_hair_front_01.png` | `hair_front` | Tóc trước (xám, nhuộm được) | 90.014 |
| `girl_shoes_01.png` | `shoes` | Giày Mary Jane hồng | 23.069 |

Váy là áo liền thân nên xếp lớp `top`, `bottom` để trống (theo hợp
đồng). Giày mặc định cả 3 bộ đều đi đôi này; giày thay thế ở lô 3.
Mũ không có ở lô này (lô 3); mái giữ như bản gốc.

## Mốc khung đo được (khung 1024×1536)

Đo bằng code từ lớp thật, **không** copy mốc của bộ xám tạm:

- Tâm mống mắt: trái **(388, 557)**, phải **(596, 561)** — tức
  x = 512 ± ~104, **y ≈ 559** (thấp hơn ~80 px so với mốc khung
  phác y = 480).
- Tâm miệng: **(507, 837)**, bbox miệng x[447, 567] y[807, 877].
- Đỉnh đầu y = **142**; đáy bàn chân (chân) y = **1429**.
- Alpha bbox toàn thân: **(134, 142, 885, 1430)**.

**Lưu ý cho giai đoạn code (E):** pivot chớp mắt của `CharacterView`
đang hardcode ở y = 480 (`_eyeCenter` Alignment(0.0, −0.375)). Mốc đo
được là y ≈ 559 — giai đoạn code phải chỉnh `_eyeCenter` theo mốc
này (hoặc vẽ lại master với mắt cao hơn), nếu không chớp mắt sẽ co
sai tâm.

## Quyết định lớp tay — mã lớp `arm` mới, z = 6

Tay là lớp riêng, **không** nằm trong `body`:

- Mã lớp mới **`arm`, z = 6** (thêm vào `tools/assets/check_assets.py`,
  `tools/assets/check_assets_test.py`, danh sách `layers` trong
  `assets/manifest.json`, bảng lớp trong `docs/ASSETS.md`). Tay nằm
  **trên váy** (thấy ở hai bên thân), **dưới tóc trước** (tóc che khớp
  vai), cùng z 6 với mắt/miệng — khác vị trí nên không che nhau (cùng
  tiền lệ như cặp mắt/miệng và cặp phụ kiện).
- Ba file: `girl_arm_left` (tay trái nghỉ), `girl_arm_right` (tay phải
  nghỉ), `girl_arm_wave` (tay phải giơ vẫy). Tư thế nghỉ xếp chồng ra
  đúng bé gái v3 đã duyệt; tư thế vẫy chỉ đổi tay phải, các lớp khác
  giữ nguyên.
- Tay vẫy lấy từ tay giơ của biến thể V_wave bằng cách **lật ngang**
  toàn khung: generator vẽ tay giơ ở phía phải ảnh = tay **trái** của
  nhân vật (nhân vật quay mặt ra người xem); lật ngang thành tay phải.
  Tay giơ chỉ có da tới y ≈ 729 (cẳng tay); bắp tay trên bị tóc che —
  chấp nhận được, tay vẫy vẫn đọc rõ.
- Thiết kế này dùng được cho khung đi bộ ở lô 4: tay là đơn vị thay
  đổi theo từng khung bước (tay đánh theo bước), các lớp khác giữ
  nguyên.

## Tóc xám + nhuộm thử

Tóc vẽ bằng **màu xám**: R = G = B = kênh V (độ lệch 0), để app nhuộm
bằng color matrix như hợp đồng T2-01. Kiểm chứng bằng code:

- Tint tối ưu từ tóc sáng (V > 230): **(255, 183, 169)** — tóc nhuộm
  ra hồng mềm, khớp phong cách v3 đã duyệt (soi bằng mắt trên
  composite). Tint trung bình (255, 164, 155) bị kéo cam bởi sợi bóng
  tối nên không dùng.
- Một tint duy nhất không tái tạo hết biến thiên màu tóc (composite so
  với bản gốc: meanAbsDiff ~13 chỉ ở vùng tóc). Phần không phải tóc
  tái tạo bản gốc **chính xác** (meanAbsDiff 0,00, 0 pixel lệch > 12,
  0 pixel lệch alpha) — chứng tỏ các lớp xếp đúng.

## Thân (body) — ghi chú

Thân code-lấp da ở vùng váy che (gradient dọc, màu da lấy mẫu từ mặt)
để lớp thân đầy đủ dưới mọi váy. Trong thực tế thân luôn bị 1 trong 3
váy che, không bao giờ hiện trần. Thân **không** được tạo dạng ảnh
trẻ em khỏa thân (lần thử nền đồ lót trước đây bị công cụ ảnh từ chối
và không được thử lại).

## Kiểm chứng composite

Xếp chồng theo z (hair_back → body → shoes → top → tay → mắt →
miệng → hair_front), tóc nhuộm tint (255, 183, 169):

- Bộ 1 so với bản gốc (không tính tóc): meanAbsDiff 0,00, 0 pixel
  lệch > 12, 0 pixel lệch alpha. Bộ 2 so với biến thể V2: 25,43;
  bộ 3 so với V3: 26,65 (sau khi sửa tạp dề — xem dưới); mắt nhắm so
  với V_closed: 20,05. Các biến thể V2/V3/V_closed/V_wave là vẽ lại
  toàn bộ nên lệch vài px so với bản gốc (bbox và tâm mắt xác nhận
  căn trong ~10–13 px); chênh lệch là nhiễu re-render, không phải
  lệch hình.
- Mắt nhắm: kiểm pixel vùng mắt — không có mống mắt xanh (chỉ
  ~1,4% pixel hơi xanh, RGB trung bình (217, 172, 155) là màu da);
  mắt nhắm đọc đúng là nhắm. Tâm đường mi nhắm phải (631, 556) lệch
  +35 px so với tâm mắt mở phải (596, 561) do mi ngoài kéo tâm —
  bbox phải khớp, không phải lỗi.
- Tay vẫy: tóc sau lưng đầy đủ sau tay (không loại trừ tay) nên đổi
  tay nghỉ → tay vẫy không lộ nền; composite tay vẫy không còn mảng
  đen ở vai.
- Tạp dề bộ 3: lúc đầu chỉ hiện viền trắng vì code build lấy RGB của
  bản gốc (hồng) cho pixel vừa thuộc tạp dề vừa thuộc váy. Đã sửa:
  **tạp dề thắng váy nơi chồng nhau** (lấy RGB của V3 cho toàn bộ
  pixel tạp dề) — tạp dề trắng hiện đầy đủ, có túi và ren.

## Kiểm ghép lên phòng v3b

Đặt nhân vật đã xếp chồng lên nền phòng (bản xem trước local, cùng
layout với `room_v3.png`), **cao 360 px, chân (630, 810)** theo
`docs/D_IMAGES.md`: tỉ lệ đọc tự nhiên so với giường/ghế/bàn, chân
chạm sàn trên thảm, mặt khớp nữ v3. Đạt.

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

- Entry manifest cho 13 lớp trên (kể cả 3 file `arm` lớp `arm`) +
  cập nhật `source` thành "Muse vẽ AI 21/11 theo DESIGN.md".
- Chỉnh `CharacterView._eyeCenter` theo tâm mắt đo được (y ≈ 559).
- Bảng thang cỡ pet vào `docs/ASSETS.md` + test (thứ tự trứng <
  mới nở < nhỡ < trưởng thành, nhỡ = 209 px / 58%).
- Test neo: chân nhân vật, pet, đồ nằm trong vùng sàn/mặt phẳng đã
  khai báo. Tràn 608×248 + 640×320. Full suite xanh. Mở PR.

## Lưu ý nhỏ

- Lỗ key ở tâm miệng: pixel (507, 837) trong bản gốc trùng màu nền
  magenta nên bị key xóa — lỗ chỉ vài px, miệng trong composite vẫn
  nhìn đầy đủ, không sửa riêng.
- Vùng bóng đỏ tối sau mặt/vai là sợi bóng tóc có trong bản gốc, không
  phải lỗi; tint multiply không tái tạo hết biến thiên màu tóc.
