# Hình trong app (hợp đồng nạp hình)

Tài liệu này là **hợp đồng** cho mọi hình đưa vào app từ bản 0.2: tên lớp,
thứ tự chồng, khung, cách đặt tên, cách đổi màu.

> **Cập nhật 21/11 (sau PR #34):** nhân vật trong app hiện là **ảnh toàn
> thân** (mục "Nhân vật toàn thân (hiện hành)" ngay dưới). Hệ nhân vật
> chồng lớp cũ (`CharacterView`, các lớp `hair_back`/`body`/`top`…, bộ
> `girlSet1`) chỉ còn là **legacy**: mục "Thứ tự lớp" và "Bộ nhân vật nữ 1"
> bên dưới được giữ làm lịch sử + hợp đồng cho `kind: character_layer`
> (file vẫn còn trên repo và vẫn được test cũ dùng), app không còn vẽ
> nhân vật bằng cách đó. Người cắt/vẽ hình làm
theo đúng tài liệu này; script `tools/assets/check_assets.py` kiểm tra
tự động theo cùng các quy tắc (và chạy trong CI).

Nguồn hình chính là các tấm trong `assets/concept/` (chủ dự án chốt
18/11, PLAN điểm (k)): tách nền, cắt từng món, sửa lỗi theo bảng trong
`assets/concept/README.md`. Món thiếu hoặc hỏng thì vẽ bổ sung cùng
phong cách pastel mềm, viền trắng kiểu sticker. Chi tiết quy cách vẽ
xem `docs/DESIGN.md` mục "Hướng dẫn vẽ cho họa sĩ".

## File hợp đồng

| File | Vai trò |
| --- | --- |
| `assets/manifest.json` | Liệt kê mọi hình: mã, loại, dáng, lớp, có đổi màu không, giá, trạng thái. Đây là danh sách duy nhất app và script cùng đọc. |
| `tools/assets/check_assets.py` | Script kiểm tra (Python + Pillow để đọc WebP): khung, WebP trong suốt, tên file, manifest khớp file thật. |
| `tools/assets/check_assets_test.py` | Test cho script (JPEG báo lỗi, WebP nền đặc báo lỗi (trừ nền), file đúng qua được). |
| `tools/assets/decode_incoming.py` | Giải mã ảnh Muse đẩy dạng base64 rồi đổi sang WebP lossless (xem "Đường đưa ảnh lên repo"). |
| `tools/assets/png_to_webp.py` | Đổi PNG sang WebP lossless (kiểm giống hệt từng pixel) — đã chạy một lần cho cả `app/assets/images/` để giảm dung lượng APK. |
| `app/test/assets_manifest_test.dart` | Test Dart gọi script kiểm tra trong lúc chạy `flutter test` (để CI kiểm tra mà không cần sửa workflow). |

## Nhân vật toàn thân (hiện hành, E — 21/11)

Mã nguồn: `app/lib/features/character/kid_assets.dart` (đường dẫn, bảng
mã, miếng vá mắt), `kid_sprite.dart` (widget `KidSprite`),
`kid_look_service.dart` (lưu lựa chọn trang phục). Hình do Muse vẽ, nhật ký
từng lô ở `docs/E_IMAGES.md`.

- **Một nhân vật duy nhất**: bé chọn gái (`girl`) hoặc trai (`boy`) ở màn
  mở đầu. Giá trị lạ coi như `girl` (`kidGender`).
- **Ảnh toàn thân**: mỗi dáng 3 bộ đồ (`kidOutfitIds`: `girl_top_01–03`,
  `boy_outfit_01–03`; số bộ 1–3 lấy từ đuôi mã trong
  `CharacterProfile.dress`, `kidOutfitNumber`, null/mã lạ về bộ 1) × 2
  dáng (nghỉ, vẫy tay). PNG trong suốt khung **1024 x 1536**
  (`kidFrameWidth`/`kidFrameHeight`); chân ở y = 1429 (`kidFeetY`), người
  cao 1287 px (`kidBodyHeight`) ở mọi ảnh. Tên file:
  `<dáng>_full_0<bộ>[_wave][_backpack].webp`
  (`kidFullAsset`), thư mục `app/assets/images/character/<dáng>/`;
  `kind: character_full` trong manifest.
- **Balo = biến thể ảnh toàn thân** `..._backpack` (Muse vẽ cả người đeo
  balo vì balo lớp rời không khớp người), KHÔNG phải lớp phủ. Có cả bản
  vẫy (`_wave_backpack`). Lớp balo rời `*_backpack_01` của lô 3 đã bị thay hẳn
  (không còn file trong `app/assets/images/character/` và không có trong
  code), dù `NAME_PATTERNS` của script còn nhận tên đó.
- **Mắt nhắm (chớp mắt)**: một miếng vá PNG đặt đè lên ảnh khi chớp
  (~0,25 giây mỗi ~3,6 giây), rect tính theo khung 1024x1536
  (`kidEyePatch`). Bé gái: một patch dùng chung cả 6 ảnh
  (`girl_eyes_closed_patch.webp`, rect 300,490,410x140). Bé trai: patch
  chung cho 3 ảnh nghỉ (`boy_eyes_closed_patch.webp`, rect 291,506,432x205);
  mỗi ảnh vẫy một patch riêng (`boy_eyes_closed_patch_0<bộ>_wave.webp`,
  rect riêng: 297,493,427x245 / 280,502,441x243 / 295,495,432x250) vì đầu
  vẽ lại lệch vài px. `kind: character_patch`.
- **Phụ kiện đầu** (lớp phủ cùng khung, `kidHeadAccessories`): mã `hat`
  (gái `girl_hat_01` mũ beret, trai `boy_hat_01` mũ lưỡi trai) và `bow`
  (gái `girl_bow_01` nơ cài tóc, trai `boy_clip_01` kẹp tóc ngôi sao).
  Chỉ đeo một phụ kiện đầu; lưu ở `settings` khóa `kid_head_accessory`.
- **Lớp phủ khác** (cùng khung, khớp cả ảnh nghỉ và vẫy): kính tròn
  `<dáng>_glasses_01` (khóa `kid_glasses`) và giày trắng `<dáng>_shoes_02`
  thay giày màu của bộ đồ (khóa `kid_white_shoes`). Balo lưu ở khóa
  `kid_backpack`. Tất cả do `KidLookService` đọc/ghi theo từng bé; bộ đồ
  đổi qua `setOutfit` (ghi lại `CharacterProfile.dress`).
- **Khung đi bộ**: mỗi bộ đồ 2 hướng × 4 khung (`kidWalkFrames`):
  `<dáng>_full_0<bộ>_walk_(dr|ur)_(a|b|c|d).webp`; `dr` = đi xuống/ngang,
  `ur` = đi lên (xa dần), vẽ hướng phải, app lật ngang khi đi sang trái
  (`facingLeft`). Cả gái và trai đều có (`kidGendersWithWalkFrames`). Mỗi
  khung là một ảnh toàn thân hoàn chỉnh; đổi khung theo chu kỳ 600 ms.
  **Chỉ dùng khung đi bộ khi bé KHÔNG đeo gì thêm** (không kính, không giày
  trắng, không balo, không phụ kiện đầu): lớp phủ vẽ theo dáng đứng nên đặt
  lên khung đi bộ sẽ lệch (mắt-x lệch, xem `docs/E_IMAGES.md` lô 4). Đang
  đeo bất cứ món nào thì khi đi app dùng ảnh đứng + nhún bước (nảy + nghiêng
  nhẹ). Khi dùng khung đi bộ thì không chớp mắt và không vẽ lớp phủ.
- **`KidSprite`**: thở nhẹ quanh chân (chân không rời đất), chớp mắt, vẫy
  tay (`waving`), đi bộ, lật hướng; hiệu ứng lặp tắt bằng `AnimationGate`
  khi chạy test. Dùng ở Phòng, Thị trấn, màn mở đầu và Tủ đồ.
- **Kích thước trong Phòng**: người cao 360 px khung nền (hộp cao
  `1536 × 360 / 1287` ≈ 430 px, nhân tỉ lệ chiều sâu); xem mục "Đi lại
  trong Phòng" bên dưới.
- Quy tắc kiểm của script: `kind: character_full` (khung 1024x1536, tên
  theo `NAME_PATTERNS["character_full"]`) và `character_patch` (không kiểm
  khung); xem `tools/assets/check_assets.py`.

### Legacy: hệ nhân vật chồng lớp (T2-02, bộ nữ 1)

Các mục "Thứ tự lớp", "Đổi màu (lớp xám) và file `_line`", "Bộ tóc…" và
"Bộ nhân vật nữ 1" dưới đây mô tả hệ cũ: widget `CharacterView`
(`app/lib/features/character/character_view.dart`) chồng lớp theo z trong
manifest, nhân màu lớp xám; mô hình `CharacterOutfit` / `girlSet1` ở
`character_model.dart`; lớp tạm xám cho bé trai ở `placeholder_layers.dart`.
Hệ này đã bị thay vì cắt lớp làm vỡ hình. File code + ảnh lớp vẫn còn trên
repo và các test cũ (`app/test/features/character/character_view_test.dart`,
golden, fixtures) vẫn dùng — KHÔNG xóa khi chưa dọn cả test. Màn mở đầu chỉ
còn import kiểu `CharacterLayerLoader` từ đó (tham số `previewLoader` của
test); không còn chọn màu da/tóc/mắt/miệng.

## Thứ tự lớp, từ dưới lên (legacy — hệ chồng lớp cũ)

Khớp `docs/DESIGN.md` và các file khung `assets/templates/
khung_nhan_vat_nu.svg`, `khung_nhan_vat_nam.svg` (mỗi khung có sẵn
8 nhóm lớp đúng thứ tự này).

| z | Mã lớp (`layer`) | Tên | Ghi chú |
| --- | --- | --- | --- |
| 1 | `hair_back` | Tóc sau | |
| 2 | `body` | Thân (da) | Một thân duy nhất cho mỗi dáng. |
| 3 | `shoes` | Giày | |
| 4 | `bottom` | Quần hoặc váy | |
| 5 | `top` | Áo | Áo liền thân (váy đầm) xếp vào lớp `top`, lớp `bottom` để trống. |
| 6 | `eyes` | Mắt | Mắt và miệng cùng z 6, khác vị trí nên không che nhau. |
| 6 | `mouth` | Miệng | |
| 7 | `hair_front` | Tóc trước | |
| 8 | `accessory_head` | Phụ kiện đầu | Phụ kiện đầu và tay cùng z 8. |
| 8 | `accessory_hand` | Phụ kiện tay | |

Mốc trong khung nhân vật (từ file khung phác): tâm mắt ở
(x = 512 ± 105, y = 480), tâm miệng ở (512, 575), đỉnh đầu y = 200,
vai y = 716, mặt đất y = 1400, mép an toàn là hình chữ nhật
(40, 40)–(984, 1496) — không vẽ ra ngoài.

## Khung và định dạng

| Loại (`kind`) | Khung | Định dạng | Ghi chú |
| --- | --- | --- | --- |
| `character_layer` | 1024 x 1536 | PNG trong suốt | Mỗi lớp một file, đúng kích thước khung, chỉ chứa phần của lớp đó ở đúng vị trí. |
| `pet` | 512 x 512 | PNG trong suốt | Pet và trứng; mặt đất y = 440, mép an toàn (32, 32)–(480, 480) theo `assets/templates/khung_pet_do_vat.svg`. |
| `item` | 512 x 512 | PNG trong suốt | Đồ vật: thức ăn pet, đồ chơi, nơ, kẹp tóc, túi… |
| `furniture` | 512 x 512 | PNG trong suốt | Nội thất đặt trong phòng. |
| `background` | Không cố định | JPEG hoặc PNG | Nền phòng/thị trấn; JPEG/PNG không có nền trong suốt nên không chồng lớp được. Tỉ lệ ngang 16:9, khuyến nghị 1600x900 trở lên. Nền PNG được phép từ A1 vì đường đưa ảnh base64 chỉ nhận PNG. |
| `icon` | Không cố định | SVG | Biểu tượng giao diện (vector). 5 icon khu Thị trấn (T1-12) nằm ngay ở `app/assets/images/area_*.svg`; icon mới cho vào `app/assets/images/icons/`. |

## Quy tắc đặt tên

Mã (`id`) của mỗi mục **trùng với tên file** (không tính đuôi):

- Lớp nhân vật: `<dáng>_<lớp>_<tên món>.webp`, ví dụ
  `girl_hair_front_bob.webp`, `girl_top_tshirt.webp`. Thư mục:
  `app/assets/images/character/<dáng>/` (`girl` hoặc `boy`).
- Pet: `<loài>_<giai đoạn>.webp` với loài `dog`/`cat`/`rabbit`, giai đoạn
  `egg`/`newborn`/`teen`/`adult`, ví dụ `dog_egg.webp`. Thư mục:
  `app/assets/images/pets/`.
- Đồ vật: `app/assets/images/items/<tên món>.webp`.
- Nội thất: `app/assets/images/furniture/<tên món>.webp`.
- Nền: `app/assets/images/backgrounds/<tên>.jpg` hoặc `.webp`.
- Icon: `app/assets/images/icons/<tên>.svg` (icon cũ ở gốc
  `app/assets/images/` vẫn hợp lệ).

## Đổi màu (lớp xám) và file `_line` (legacy — chỉ cho `character_layer`)

- Phần cần đổi màu (da, tóc, mắt, miệng, vải quần áo) tô **một màu xám
  sáng duy nhất**, bóng đổ dùng xám đậm hơn. App nhân màu lên lớp xám
  này để đổi màu da/tóc/mắt/quần áo. Script kiểm tra: mọi pixel còn
  thấy được của lớp đổi màu (`recolorable: true`) phải gần như xám
  (R, G, B lệch nhau tối đa 8).
- Nét viền và chi tiết không đổi màu (khuy áo, họa tiết cố định, mi
  mắt, viền miệng) xuất thành file riêng, tên thêm đuôi `_line`, ví dụ
  `girl_top_tshirt_line.webp`. File `_line` cùng lớp và cùng z với file
  gốc, app vẽ ngay sau file gốc. Trong manifest, file `_line` là một
  mục riêng (`line: true`, `recolorable: false`); file gốc không bắt
  buộc phải có `_line` đi kèm — chỉ liệt kê khi món đó thật sự có nét
  không đổi màu.

## Bộ tóc và các trường trong manifest

- Tóc sau và tóc trước của cùng một kiểu tóc đi thành **bộ** (trường
  `set`, ví dụ `girl_hair_01`): mỗi bộ phải có đúng 1 tóc sau + 1 tóc
  trước cùng dáng. Khi bé chọn "kiểu tóc 1", app lấy cả hai file
  trong bộ.
- Mỗi mục trong manifest có các trường: `id`, `file` (đường dẫn tính
  từ gốc repo), `kind`, `form` (`girl`/`boy`/`any`), `layer` (chỉ lớp
  nhân vật mới có, các loại khác để `null`), `recolorable`, `line`,
  `set` (chỉ bộ tóc mới có, còn lại `null`), `price_xu`, `price_gem`,
  `status`, `name_vi`, `source` (tấm concept đã cắt từ đó, hoặc
  "vẽ mới").
- `status: ready` = file đã có trên repo và đúng hợp đồng;
  `status: planned` = chưa có file, sẽ cắt/vẽ sau (script báo lỗi nếu
  file đã có mà còn ghi `planned`, và báo lỗi nếu ghi `ready` mà
  thiếu file).
- Giá: `price_xu: 0` = có sẵn miễn phí (thân, mắt, miệng, tóc mặc
  định; trứng chọn lúc tạo nhân vật); `price_xu: null` = chưa định
  giá, chốt ở T2-06 (cửa hàng); `price_gem` tương tự cho đồ hiếm
  (mua bằng kim cương). Không có trường giá nào được để lửng kiểu
  chuỗi "TBD".

## Lô hình đầu tiên (đã liệt kê trong manifest)

> Danh sách dưới là lô khai báo ban đầu (19/11), giữ làm lịch sử. Hiện
> trạng manifest (21/11, 192 mục): cả **12 pet** (3 trứng + 3 mới nở + 3
> nhỡ + 3 lớn) đã `ready`; nhân vật dùng `character_full` (80 mục `ready`)
> + `character_patch` (5) thay cho các mục `character_layer` dáng nam/nữ
> còn `planned` (48 mục, không còn kế hoạch vẽ).

- **Dáng nữ** (29 mục, `planned`): thân ×1 (+ viền), mắt ×3 (+ viền),
  miệng ×3 (+ viền), tóc ×3 kiểu (sau + trước), áo ×3, quần/váy ×2,
  giày ×1, phụ kiện đầu ×2 (nơ/kẹp tóc, mũ phù thủy), phụ kiện tay ×1
  (ô dù). Tên món mắt/miệng lấy từ tấm `eyes_mouths_gray.webp` đã xem:
  mắt mi dài (×2 kiểu) và mắt tròn; miệng cười, miệng cười hở,
  miệng chữ O. Tên món trang phục để dạng `top_01`… vì chưa xem tấm
  `girl_outfits_gray.webp` — người cắt giữ nguyên mã, chỉ điền tên
  hiển thị (`name_vi`) cho đúng món đã cắt.
- **Pet** (12 mục, `planned`): 3 trứng (Chó Tinh Anh, Mèo Mũm Mĩm,
  Thỏ Bánh Bao) + 3 pet mới nở + 3 giai đoạn nhỡ + 3 giai đoạn lớn.
  Lô đầu chỉ cần 3 trứng + 3 pet mới nở; giai đoạn nhỡ/lớn vẽ sau.
- **Dáng nam** (24 mục, `planned`): thân, mắt, miệng, tóc ×2 kiểu,
  trang phục — vẽ dần sau dáng nữ.
- **Nền** (2 mục, `planned`): `room_01.jpg`, `town_01.jpg`.
- **Nền phòng v2 + nội thất (A1, 20/11, `ready`)**: `room_v2.webp` +
  8 món đồ rời (xem mục "Phòng v2" cuối tài liệu).
- **Icon khu Thị trấn** (5 mục, `ready`): `area_logic`,
  `area_arith`, `area_number`, `area_geo`, `area_comb` (SVG, T1-12).

## Thêm một món đồ mới

1. Cắt/vẽ file đúng khung, đúng tên, đúng thư mục (xem bảng trên).
2. Thêm **một dòng** vào `assets/manifest.json` (đủ 13 trường, xem
   mục trên; `status: "ready"`).
3. Chạy `python3 tools/assets/check_assets.py` ở gốc repo — phải
   báo `OK`. Nếu báo lỗi, sửa file hoặc dòng manifest theo đúng
   thông báo (sai khung, thiếu alpha, tên sai, thiếu file…).

## Định dạng ảnh trong repo

Mọi ảnh trong `app/assets/images/` là **WebP lossless** (đuôi `.webp`),
không còn PNG: giống hệt từng pixel (pixel trong suốt hoàn toàn có thể
mất RGB, vô hình) nhưng nhỏ hơn nhiều. Muse vẫn vẽ và giao PNG; PNG
chỉ là định dạng trung gian, `decode_incoming.py` đổi sang WebP. Chạy
thủ công: `python3 tools/assets/png_to_webp.py` (cần Pillow).

## Đường đưa ảnh lên repo

Muse không đẩy được file nhị phân qua GitHub MCP. Ảnh PNG đưa lên
bằng đường vòng base64 (chủ dự án chốt 19/11):

1. Muse đẩy mỗi ảnh thành file text `app/assets/_incoming/
   <đường dẫn đích>.b64` (nội dung chỉ một chuỗi base64 của PNG),
   vài file mỗi lần push nếu file lớn.
2. Claude chạy `python3 tools/assets/decode_incoming.py` trên nhánh
   PR: script giải mã PNG, đổi sang WebP lossless (đuôi `.webp`) đúng
   đường dẫn, xóa file `.b64` và
   commit lên cùng nhánh.
3. Ảnh xem trước gửi qua chat cho Claude và chủ dự án duyệt mắt
   trước khi đẩy cả bộ.

Thư mục `app/assets/_incoming/` không nằm trong diện kiểm tra của
script (ảnh ở đó chưa phải file đích).

## Chạy kiểm tra

```sh
# Kiểm tra toàn bộ manifest + file hình (gốc repo):
python3 tools/assets/check_assets.py

# Test của script (không cần Flutter):
python3 tools/assets/check_assets_test.py

# Test Dart (chạy cùng `flutter test` trong app/):
flutter test test/assets_manifest_test.dart
```

## Nối CI

`.github/workflows/ci.yml` chạy `python3 tools/assets/check_assets.py` và `python3 tools/assets/check_assets_test.py` ngay sau bước "Câu hỏi mẫu (check.py)" (Claude thêm ngày 19/11). Test Dart `app/test/assets_manifest_test.dart` giữ làm kiểm tra dự phòng khi chạy `flutter test` ở local.

## Bộ nhân vật nữ 1 (Claude ghép, 19/11) — legacy

Chủ dự án đã duyệt bản xem trước ngày 19/11. Bộ này cắt nguyên cô bé chính trên `girl_character_sheet` thay cho cách vẽ lại từng lớp (các bản vẽ lại v1–v5 và v3b đều chưa đạt phong cách).

- Khung 1024 x 1536. Cô bé đặt theo tỉ lệ 1300/678: đỉnh nơ y = 100, gót y ≈ 1400, tâm ngang x = 512. Mốc mắt/miệng cũ không áp dụng cho bộ này.
- `girl_body_01`: cả cô bé, màu thật, `recolorable: false`. Đã có sẵn mắt, miệng, tất, giày và bộ đồ gốc (váy hầu gái hồng). Khi dùng thân này thì **không** vẽ thêm lớp `eyes`/`mouth`/`shoes`.
- `girl_hair_front_01`: tóc xám đặt đúng chỗ tóc trên thân, app nhân màu để đổi màu tóc. Lớp tóc trước nằm trên váy (z 7), nên đuôi tóc phủ lên mép váy rộng, nhìn tự nhiên. Màu gốc gần với nhân (255, 180, 150).
- `girl_hair_back_01`: để trống (trong suốt), chỉ để đủ bộ `girl_hair_01`.
- `girl_top_01` (váy hồng), `girl_top_02` (váy tím): cắt từ tấm concept, kéo giãn riêng phần chân váy để phủ kín bộ đồ gốc. Tay áo trắng dài của bộ gốc vẫn lộ ra như áo sơ mi mặc trong váy, đây là chủ ý.
- Không chọn váy nào thì cô bé mặc bộ đồ gốc.

## Phòng v2 (A1, 20/11)

Chủ dự án đã duyệt phong cách v2 ngày 20/11: 3D mềm (mặt sáng/tối rõ,
ánh sáng từ trên-trái, bóng đổ mềm, gradient nhẹ), phòng phối cảnh
1 điểm tụ. Nền + 8 đồ rời vẽ mới bằng AI theo `docs/DESIGN.md`,
`source` trong manifest ghi "Muse vẽ AI 20/11 theo DESIGN.md".

- **Nền** `app/assets/images/backgrounds/room_v2.webp`: PNG 1600x900
  (không phải JPEG — đường đưa ảnh base64 chỉ nhận PNG nên nền đẩy
  dạng PNG; script kiểm tra đã cho phép nền PNG từ A1, xem
  `tools/assets/check_assets.py`). Phòng trống, phối cảnh 1 điểm tụ:
  cửa sổ lớn ở tường sau (x ~480–1120, y ~190–610 trong ảnh 1600x900),
  sàn gỗ bắt đầu y ~620, hai tường bên hồng. App vẽ nền bằng
  `Image.asset` với `BoxFit.cover`.
- **Đồ rời** `app/assets/images/furniture/<tên>.webp`: PNG trong suốt
  512x512, `kind: furniture`, `status: ready`. Mép đáy của món
  (ground line) là mốc đặt đồ xuống sàn — app neo món đồ theo mép
  đáy rồi vẽ bóng ngay dưới mốc đó. Vị trí đáy trong ảnh 512x512
  (hàng pixel mờ đục cuối cùng, đo từ PNG thật, ghi trong
  `app/lib/features/room/room_assets.dart` trường `bottomRow`):
  gối 426, cốc sao 392, bình hoa 426, chậu cây 421, khung ảnh 423,
  gấu bông 433, đèn sao 433, dây cờ 359 (dây cờ treo, không đặt sàn).

### Quy tắc bóng đổ (A1)

- PNG đồ rời **không nướng bóng trong ảnh** (alpha quanh món đồ
  sạch). App tự vẽ bóng đổ mềm dưới mỗi món **đặt sàn** khi đặt vào
  phòng: ellipse mờ, đen 20% (`Colors.black.withValues(alpha: 0.20)`),
  rộng 85% bề ngang món, cao 10% bề ngang, đặt ngay dưới mép đáy
  (`bottomRow`). Món treo (dây cờ, đèn sao) không có bóng.
- Áp dụng tương tự cho nhân vật (PR 3) và pet (PR 4): cắt với alpha
  sạch, app vẽ bóng dưới chân.

### Quy tắc cắt alpha sạch (bài học A1, áp dụng cho PR 3, 4)

- Vệt bóng và phần shading dưới của món đồ cùng tông màu, nối nhau
  bằng gradient mượt — **không có ngưỡng màu hay step nào tách được
  sạch mà không ăn vào món đồ** (đã thử 5 biến thể flood-fill/trim).
  Cách làm được là cắt theo **đường viền đáy thủ công** (ground line)
  đọc bằng mắt trên lưới tọa độ + dải đáy phóng to, rồi làm mềm viền
  1–1,2 px. Cách làm chi tiết xem `docs/A1_IMAGES.md` (mục vòng 3).
- Đường viền đáy phải theo **bóng dáng thật** của món (mép dưới, một
  đường cong theo món đồ, trải suốt bề rộng bóng dáng), CHỈ xóa pixel
  nằm DƯỚI đường đó, KHÔNG bao giờ xóa theo cột — tay, tai, đuôi,
  quai đều nằm ngoài bề ngang đáy (vòng 2 đã cắt cụt hông bình, mép
  chậu, quai cốc, mép gối vì xóa theo cột).
- Kiểm từng tấm trên nền tối + nền caro + bản đồ alpha: viền ngoài
  liền mạch, không cạnh thẳng đứng, không vệt bóng, không mẩu thừa.

## Thị trấn v2 (A2, 20/11)

Phong cách v2 đã duyệt (xem mục Phòng v2): thị trấn isometric, 3D
mềm, nhà xa mờ dần, đủ chi tiết (cây, hoa, đèn, xe, người nhỏ).
Nền + 10 lớp động vẽ mới bằng AI theo `docs/DESIGN.md`, `source`
trong manifest ghi "Muse vẽ AI 20/11 theo DESIGN.md".

- **Nền** `app/assets/images/backgrounds/town_v2.webp`: PNG 1600x900
  (đủ màu là 1.984.654 byte > 1 MB nên lượng tử hóa 256 màu +
  dithering Floyd-Steinberg, còn 581.584 byte; xem bằng mắt không
  thấy nhiễu ở cỡ hiển thị). Nền cũ `town_01.jpg` giữ `planned`
  trong manifest (chưa dùng). App vẽ nền bằng `Image.asset` với
  `BoxFit.fill` trong khung 16/9 — KHÔNG dùng `cover` như màn
  Phòng, vì `cover` cắt nền sẽ làm lệch vùng bấm.
- **Lớp động** `app/assets/images/town/<tên>.webp`: PNG trong suốt
  512x512, `kind: town_layer` (loại mới thêm ở A2 — xem
  `tools/assets/check_assets.py`: `KINDS`, `FRAMES`, `NAME_PATTERNS`,
  `KIND_DIRS`), `status: ready`. 10 lớp: mây trắng ×3 (`cloud_01`,
  `cloud_02`, `cloud_03`), xe hơi ×2 (`car_01` hồng, `car_02` xanh
  nhạt), đài phun nước đá (`fountain`), cây ×2 (`tree_01` xanh tán
  tròn, `tree_02` hoa anh đào), người ×2 (`person_01` bé gái mũ
  hồng váy xanh, `person_02` bé trai mũ xanh áo xanh lá). Vẽ rời
  trên nền magenta rồi tách bằng chroma-key; xem bằng mắt trên nền
  caro trước khi đẩy. Danh sách đường dẫn dùng chung để test golden
  nạp trước ảnh: `townLayerAssets` trong
  `app/lib/features/town/town_assets.dart` (phải khớp spec trong
  `app/lib/features/town/town_map.dart`).

### Vị trí 6 công trình (khung nền 1600x900)

Đo bằng mắt trên lưới 100 px, ghi trong `docs/A2_IMAGES.md`
(x, y, rộng, cao):

- Trường học xanh có chuông: 585, 95, 360, 280.
- Tiệm bánh vàng biển bánh sừng bò: 315, 320, 355, 245.
- Tiệm quần áo tím mái sọc: 660, 490, 330, 240.
- Cửa hàng thú cưng xanh lá biển dấu chân: 1260, 450, 290, 230.
- Nhà hồng = Phòng (góc trái dưới): 95, 545, 300, 225.
- Công viên xích đu/cầu trượt: bóng dáng đo được tới x = 1440,
  nhưng vùng bấm cắt ở x = 1260 (mép trái cửa hàng thú cưng) để
  không chồng vùng bấm thú cưng — tâm vùng thú cưng (1405, 565)
  nằm trong rect cũ nên tap chặng 2 rơi nhầm sang chặng 3 (bắt bằng
  test thị trấn, A2 giai đoạn 2). Vùng bấm công viên:
  860, 300, 400, 280.

### Map khu vực ↔ công trình

5 khu toán hiện tại đặt lên 5 công trình (xem
`app/lib/features/town/town_assets.dart` — 2 điểm CHƯA CHẮC, cần
Claude quyết ở review PR A2):

- Lâu đài Lôgic → trường học (tòa nhà lớn nhất, tháp chuông dáng
  như lâu đài).
- Tiệm bánh Số học → tiệm bánh (trùng tên).
- Vườn Hình học → công viên (khu vườn).
- Tháp Con số → cửa hàng thú cưng (CHƯA CHẮC — chỉ là loại trừ).
- Hội chợ Tổ hợp → tiệm quần áo (CHƯA CHẮC — chỉ là loại trừ:
  kết hợp áo/quần/giày thành bộ đồ).

Nhà hồng không phải khu toán: bấm vào thì về Phòng
(`town-room-house-button`). Icon SVG khu (`area_*.svg`) không còn
hiện trên màn Thị trấn (nhãn dán trên công trình thay thế) nhưng
file + dòng manifest giữ nguyên.

### Quy tắc lớp động + chuyển động

- Vẽ theo thứ tự dưới lên trên: cây + đài phun ở mặt đất, xe +
  người trên đường, mây trên trời. Mây bay trên cả công trình
  (trong suốt, không che nhãn).
- Chuyển động bằng Flutter animation (`app/lib/features/town/town_map.dart`):
  mây trôi ngang chậm (mỗi mây tốc độ/hướng khác nhau, lặp);
  xe chạy dọc đường, lặp; người đi bộ dọc vỉa hè, lặp, có nhún
  nhẹ theo nhịp bước; đài phun nước nhấp nhô (scale/opacity);
  cây đung đưa nhẹ (±2° quanh gốc, neo `bottomCenter`).
- Tất cả tắt được qua cổng [AnimationGate] trong test (mẫu PR #22):
  cổng tắt thì vị trí tĩnh t = 0, không tạo controller nào; cổng
  bật thì vẽ lại mỗi khung qua `AnimatedBuilder` (vị trí tính
  trong builder từ giá trị controller hiện tại).
- Vùng bấm là `Positioned` theo rect công trình (tỉ lệ 0..1 so
  với khung nền, scale theo kích thước hiển thị), bọc `PressBounce`
  + `GestureDetector`, khóa `town-stage-$i-button` / `town-room-house-button`.
  Nhãn dán ở đáy vùng bấm: tên khu (tối đa 2 dòng) + pill trạng
  thái (Xong ✓ / Đang làm / Chưa làm), nền trắng 88%, viền màu khu.
- Test golden phải nạp trước nền + 10 lớp động bằng `runAsync` +
  `precacheImage` (mẫu `room_golden_test.dart` / A1) — không có
  bước này thì ảnh chụp thiếu nền/lớp động (test đầu chạy khi ảnh
  chưa kịp về, test sau mới có vì đã cache).

## Thị trấn v3b (C, 21/11)

Phong cách v3b đã duyệt (chủ dự án, 21/11 ~01:31): thị trấn
isometric như v2 nhưng đủ đúng 6 công trình đặc trưng theo mảng
(đỏ theo brief A1), đường nối rõ có vạch kẻ + vỉa hè, khoảng trống
trên đường để xe/người đi. Nền + 17 lớp động vẽ mới bằng AI theo
`docs/DESIGN.md`, `source` trong manifest ghi "Muse vẽ AI 21/11
theo DESIGN.md".

- **Nền** `app/assets/images/backgrounds/town_v3.webp`: PNG 1600x900
  (678.089 byte — lượng tử hóa 256 màu + dithering Floyd-Steinberg
  vì đủ màu vượt 1 MB). Đường + vỉa hè TRỐNG (không vẽ sẵn xe hay
  người — app vẽ lớp động chạy theo đường); giữ đúng bố cục 6 công
  trình như ảnh xem trước v3b đã duyệt. Nền v2 `town_v2.webp` giữ
  `ready` trong manifest (file vẫn còn, không dùng nữa — như tiền
  lệ `town_01.jpg`). App vẽ nền bằng `Image.asset` với
  `BoxFit.fill` trong khung 16/9 — KHÔNG dùng `cover` như màn
  Phòng, vì `cover` cắt nền sẽ làm lệch vùng bấm.
- **Lớp động** `app/assets/images/town/<tên>.webp`: PNG trong suốt
  512x512, `kind: town_layer`, `status: ready`. 17 lớp: mây trắng
  ×3 (`cloud_01`, `cloud_02`, `cloud_03`), xe hơi ×4 (`car_01_dr`,
  `car_01_ur`, `car_02_dr`, `car_02_ur`), người ×8 (`person_01`,
  `person_02` × `dr`/`ur` × khung bước chân `a`/`b`), cây ×2
  (`tree_01` xanh tán tròn, `tree_02` hoa anh đào). KHÔNG còn đài
  phun nước (thị trấn v3b có ao, không có đài phun) — file
  `fountain.webp` + dòng manifest giữ nguyên (file vẫn còn).
  4 file nhìn ngang cũ (`car_01`, `car_02`, `person_01`,
  `person_02`) không dùng nữa: đã XÓA KHỎI MANIFEST, file vẫn còn
  trên nhánh — Claude `git rm` (xem HANDOVER); tới lúc đó
  `check_assets.py` báo đúng 4 lỗi "file hình không có dòng
  manifest" (là lỗi đã biết, không phải lỗi code).
  Tỉ lệ điểm ảnh bán trong suốt (0 < alpha < 255) đo bằng code
  < 5% mọi lớp (Claude đo lại 0,2–0,7%, tree_02 1,8%). Danh sách
  đường dẫn dùng chung để test golden nạp trước ảnh:
  `townLayerAssets` trong `app/lib/features/town/town_assets.dart`
  (phải khớp spec trong `app/lib/features/town/town_map.dart`).

### Vị trí 6 công trình (khung nền 1600x900)

Đo từ nền thật, ghi trong `docs/C_IMAGES.md` (x, y, rộng, cao).
Vùng bấm KHÔNG lấy nguyên rect đo được mà cắt bớt để nhãn các
công trình không bị vùng bấm khác che (nhãn dán ở dải cuối vùng,
cao ~140 px theo khung nền, tính cả nhãn phình ở màn nhỏ). Kiểm
bằng test (`town_roads_test.dart`): tâm 6 vùng mỗi vùng chỉ nằm
trong đúng vùng đó; không vùng bấm nào che nhãn vùng khác.

- Lâu đài Lôgic (xanh đá, có cờ): 165, 0, 450, 290 (giữ nguyên —
  không chồng nhãn).
- Tiệm bánh Số học (vàng, biển bánh sừng bò): 290, 305, 350, 255
  (giữ nguyên).
- Tháp Con số (vàng, đồng hồ mặt số): 620, 5, 460, 385 — cắt trái
  520→620 (khỏi che nhãn Lâu đài) và kéo lên y = 5 để bao cả thân
  tháp + đồng hồ + chóp (rect chỉ lấy phần sân trước thì đồng hồ
  bấm không được).
- Vườn Hình học (bồn cây + đồ chơi khối): 480, 565, 445, 180 —
  cắt trên 520→565 (khỏi che nhãn Tiệm bánh; đồ chơi khối ở
  y~570–690 vẫn trong vùng).
- Hội chợ Tổ hợp (lều sọc + vòng quay): 1080, 5, 480, 375 — cắt
  trái 1020→1080 (khỏi che nhãn Tháp Con số; lều 1100–1290 +
  vòng quay 1400–1560 vẫn trong vùng).
- Nhà của bé (nhà hồng, hàng rào trắng): 35, 565, 445, 290 — cắt
  trên 525→565 (khỏi che nhãn Tiệm bánh) và cắt phải 490→480
  (khỏi che nhãn Vườn Hình học; thân nhà vẫn trong vùng).

Chồng lấp còn lại (đã kiểm, không ảnh hưởng nhãn): Tiệm bánh ×
Tháp Con số 20×85 px (mép mái tiệm bánh chạm sân tháp — Tháp vẽ
sau nên thắng tap ở vùng chồng, đúng vì tháp ở trước).

### Map khu vực ↔ công trình

5 khu toán đặt lên 5 công trình v3b (xem
`app/lib/features/town/town_assets.dart`):

- Lôgic → Lâu đài Lôgic; Số học → Tiệm bánh Số học;
  Hình học → Vườn Hình học.
- Con số → Tháp Con số; Tổ hợp → Hội chợ Tổ hợp. Hai chỗ này ở
  v2 là CHƯA CHẮC (trong ảnh v2 không có tháp hay hội chợ nên tạm
  map Con số → cửa hàng thú cưng, Tổ hợp → tiệm quần áo); bản v3b
  đã vẽ đúng 2 công trình này nên map trên là map trực tiếp theo
  tên công trình — không còn là loại trừ nữa.

Nhà hồng không phải khu toán: bấm vào thì về Phòng
(`town-room-house-button`).

### Đường đi C1/C2 (khung nền 1600x900)

Khai báo trong `app/lib/features/town/town_roads.dart` (`townRoads`).
Nền `town_v3.webp` chỉ có **hai đường chéo cắt nhau ở ngã tư lớn
(~(1090, 650))**, nên app dùng đúng hai đoạn đường thẳng, đo từ mặt
nhựa thật của nền (nửa rộng mặt nhựa ~32 px + vỉa hè ~28 px). Bộ 6
đoạn D1–D6 từng khai báo ở PR #31 (và còn trong nhật ký
`docs/C_IMAGES.md`) **đã bị thay** vì D1/D3/D5 lệch 40–100 px so với
đường thật.

- **C1** ↘ (chéo xuống-phải): (700, 459) → (1600, 904) — từ giữa Tiệm
  bánh/Tháp qua ngã tư lớn ra mép phải dưới.
- **C2** ↗ (chéo lên-phải): (770, 810) → (1560, 416) — từ ngã ba dưới
  qua ngã tư lớn lên mép phải giữa.
- Nửa rộng vùng đường `townRoadHalfWidth` = 60 px (mặt đường +
  vỉa hè; hàm `isOnRoad`). Người đi bộ lệch khỏi tâm đường
  `townSidewalkOffset` = 46 px sang phía nam (pháp tuyến có y > 0,
  tức phía dưới màn hình, `sidewalkPoint`).

Tuyến xe/người (tới-lui ping-pong; tọa độ tâm chân/bánh):

| Ai | Tuyến (`town_roads.dart`) | Bám đường | Lệch |
| --- | --- | --- | --- |
| Xe 1 (hồng) `car1Route` | (774, 511) ↔ (1524, 882) | C1 | làn phía nam, cách tâm C1 ~14 px |
| Xe 2 (xanh nhạt) `car2Route` | (856, 783) ↔ (1536, 443) | C2 | làn phía nam, cách tâm C2 ~14 px |
| Người 1 (bé gái) `walker1Route` | (820, 785) ↔ (1250, 570) | tâm C2 | vẽ lệch xuống vỉa hè 46 px |
| Người 2 (bé trai) `walker2Route` | (1150, 681) ↔ (1540, 874) | tâm C1 | vẽ lệch xuống vỉa hè 46 px |

Xe 1 đã đối chiếu từng điểm (mỗi 5 px) với mặt nhựa của `town_v3.webp`:
chỉ lệch ở vạch qua đường của ngã tư (chú thích `car1Route`). Tuyến
được khóa bằng test `town_roads_test.dart` (điểm đầu/cuối từng tuyến,
hướng ở t = 0, không cắt rect chân công trình).

> Chú thích đầu file `town_roads.dart` và vài comment trong
> `town_map.dart`/`townBuildingFootprints` vẫn nhắc "D1–D6", "nửa rộng
> 50 px", "25 px" — là comment cũ chưa sửa; số thật là các hằng ở trên
> (60 px, 46 px) và hai đoạn C1/C2.

### Rect chân công trình — test độc lập (vòng sửa PR #31)

Test "mọi điểm trên tuyến nằm trong vùng đường đã khai báo" không
bắt được lỗi khai báo sai (vùng sai thì test vẫn xanh — đúng lỗi D2
cũ cắt qua lều). Thêm test độc lập trong `town_roads_test.dart`:
không điểm nào của bất kỳ tuyến nào (kể cả lệch vỉa hè) được nằm
trong rect chân công trình nào — `townBuildingFootprints` trong
`town_roads.dart` + hàm `routeHitsBuilding` (lấy mẫu mỗi 5 px, cả
2 chiều) + test hồi quy: tuyến xe 1 với D2 cũ PHẢI chạm lều.

Rect chân công trình KHÁC vùng bấm (vùng bấm rộng, bao cả sân/vườn
để bé bấm dễ — đường chạy dọc mép sân/vườn nên rect bấm sẽ báo
sai). Rect chân chỉ lấy khối chính, có chừa chỗ ở chỗ đường chạy
sát; **Hội chợ TÁCH THÀNH 2 rect (lều + bệ vòng quay)** — lúc viết,
đường D2 (nay đã bỏ) chạy giữa hai khối; rect gộp cũ (1080, 5, 480,
375) bao cả đường nên test không bắt được lỗi. Danh sách rect vẫn là
`townBuildingFootprints`, nay kiểm với tuyến C1/C2. Vùng bấm Hội chợ KHÔNG đổi (vẫn một
rect 1080, 5, 480, 375 — bấm vào đường giữa hai khối vẫn mở Hội
chợ, chấp nhận được). Danh sách rect (khung 1600x900): lâu đài
(230, 0, 390, 150); tháp trên (670, 5, 115, 100) + tháp đế
(670, 295, 115, 40); lều (1050, 0, 300, 195); bệ vòng quay
(1340, 150, 180, 130); tiệm bánh (350, 340, 220, 200); vườn
(570, 620, 330, 125); nhà hồng (75, 545, 235, 130); công viên
(850, 340, 450, 180); hồ (1320, 590, 220, 170). Nhà cao (lâu đài,
tháp) chỉ lấy phần trên + chân đế — rect toàn thân phủ cả mặt
đường chạy sau lưng nó. Chi tiết chừa chỗ từng rect xem chú thích
trong `town_roads.dart`.

### Hướng và lật (quan trọng — có test khóa lại)

Xe/người vẽ góc isometric 3/4, mỗi mẫu 2 hướng (`dr`/`ur`); 2
hướng còn lại app lật ngang. Hướng mặt đo bằng mắt trên PNG thật
(xem bằng mắt từng lớp + ghi chú của Claude khi review decode
lần 2) — KHÔNG suy từ tên file, vì tên `ur` dễ gây nhầm:

- Xe `dr`: góc 3/4 trước, đầu xe ↘. Xe `ur`: NHÌN TỪ SAU, đầu
  xe ↖ (đuôi xe ở phía dưới-phải) — tức `ur` đi ↖ khi không lật,
  và đi ↗ khi lật ngang. Đây là điểm Claude dặn riêng (bản ghi
  giai đoạn 1b viết `ur` chạy ↗ là SAI đối với xe — chỉ đúng với
  người).
- Người `dr`: góc 3/4 trước, mặt ↘. Người `ur`: NHÌN TỪ SAU,
  mặt ↗ — tức `ur` đi ↗ khi không lật, và đi ↖ khi lật ngang.

Bảng chọn (xem `town_roads.dart` — `carSpriteFor` /
`personSpriteFor`): ↘ → `dr` không lật; ↙ → `dr` lật ngang;
↖ → xe `ur` không lật, người `ur` lật ngang; ↗ → xe `ur` lật
ngang, người `ur` không lật. Test hướng
(`town_roads_test.dart`) kiểm đủ 4 hướng × 2 mẫu xe + 2 mẫu người
(hướng mặt thực tế sau lật phải bằng hướng di chuyển) và khóa
bảng hướng mặt — ai "sửa" map theo tên file thì test đỏ.

### Neo chân, cỡ hiển thị, bóng đổ, thứ tự chiều sâu

- Neo chân trong khung ảnh 512 (đo từ PNG thật): xe đáy y = 390,
  người đáy y = 470, cây xanh 484, cây anh đào 469. Hộp ảnh là
  hình vuông, neo chân tại `anchorRow/512` chiều cao hộp.
- Cỡ hiển thị: hộp xe rộng 0,105 bề rộng bản đồ (~110–120 px dài
  trên đường — xe 3/4 bị rút ngắn theo phối cảnh, bề ngang ảnh
  302–371 px so với xe cũ nhìn ngang 430–432 px); hộp người rộng
  0,04 bề rộng bản đồ (~55–60 px cao). Cây: cây xanh chân
  (130, 230), hộp rộng 0,08; cây anh đào chân (1000, 865), hộp
  rộng 0,09 (dải cỏ đáy, không chồng công trình, không chặn đường).
  Chân cây xanh dời từ (72, 200) về (130, 230) ở vòng sửa PR #31:
  chân cũ đặt trên mép lối đi sáng màu nên nhìn như nổi trên vỉa
  hè — chân mới đúng gốc cây vẽ sẵn, trên cỏ.
- Bóng đổ: PNG lớp động KHÔNG có bóng sẵn — app vẽ ellipse mềm
  (đen 20%, blur 4, mẫu `_SoftShadow` ở màn Phòng) dưới chân
  xe/người/cây, rộng 0,85 hộp, cao 0,10 hộp, neo theo hàng đáy.
  (Vòng sửa PR #31: cây trước đây không có bóng app — nay có, như
  xe/người.)
- Thứ tự vẽ: lớp mặt đất (2 cây + 2 xe + 2 người) sắp theo y chân
  — càng ở dưới màn hình (y chân lớn) càng vẽ sau, che lớp ở trên
  (công trình trước che xe sau); rồi mây trên trời; vùng bấm trên
  cùng. Xe/người không đi xuyên qua công trình: tuyến chỉ chạy
  trên đường đã khai báo.
- Người đi bộ đổi qua lại khung a/b mỗi 30 px đường đã đi thành
  dáng đi + nhún nhẹ theo nhịp bước (ảnh nhún, bóng ở yên dưới
  chân). Ở t = 0 cả hai người đều ở khung a nên golden xác định.

### Chuyển động

- Chuyển động bằng Flutter animation
  (`app/lib/features/town/town_map.dart` + `town_roads.dart`):
  mây trôi ngang chậm (mỗi mây tốc độ/hướng khác nhau, lặp 90 s)
  — vòng sửa PR #31: mây CHỈ ở dải trời y < 120 (khung nền),
  nhỏ hơn (rộng 0,09/0,085/0,07 bề rộng bản đồ) và mờ hơn
  (opacity 0,75); mây cũ to + thấp (mép dưới tới y ≈ 150–210) đè
  lều Hội chợ và cỏ. Mép dưới phần mây nhìn thấy tính từ alpha
  PNG thật (xem chú thích trong `town_map.dart`): mây 1 ≈ 111,
  mây 2 ≈ 112, mây 3 ≈ 90 — đều < 120, không chạm nhãn (nhãn ở
  y ≥ 250);
  xe chạy tới-lui 30 s một lượt ping-pong; người đi bộ tới-lui
  24 s một lượt; cây đung đưa nhẹ (±2° quanh gốc, chu kỳ 4 s).
- Tất cả tắt được qua cổng [AnimationGate] trong test (mẫu PR #22):
  cổng tắt thì vị trí tĩnh t = 0, không tạo controller nào; cổng
  bật thì vẽ lại mỗi khung qua `AnimatedBuilder` (vị trí tính
  trong builder từ giá trị controller hiện tại).
- Vị trí ở t = 0 (tính từ `phase` trong `_actors` của `town_map.dart` +
  tuyến ở trên; vị trí chân người đã lệch vỉa hè 46 px): xe 1 ~(1239, 741)
  hướng ↘ trên C1; xe 2 ~(1223, 599) hướng ↗ trên C2; người 1
  ~(1073, 710) hướng ↗, khung a; người 2 ~(1254, 784) hướng ↘, khung a.
  Test khóa điểm đầu tuyến + hướng ở t = 0 (`town_roads_test.dart`:
  xe 1 ↘, xe 2 ↗).
- Test golden phải nạp trước nền + 17 lớp động bằng `runAsync` +
  `precacheImage` (mẫu `room_golden_test.dart` / A1) — không có
  bước này thì ảnh chụp thiếu nền/lớp động.

## Phòng v3b (D, 21/11; đi lại (G) + nhân vật toàn thân + pet lớn dần đã vào code ở PR #34)

Chủ dự án đã duyệt phòng v3b ngày 21/11 ~01:31: phòng LIỀN MỘT ẢNH
như phòng 3D thật, cùng phối cảnh 1 điểm tụ, cùng nguồn sáng (nắng
từ cửa sổ lớn), bóng đổ xuống sàn; đồ rời nhỏ chỉ đặt ở mặt phẳng
đã có trong ảnh, vẽ đúng góc nhìn của mặt đó. Nền + 5 món vẽ mới
bằng AI theo `docs/DESIGN.md`, `source` trong manifest ghi
"Muse vẽ AI 21/11 theo DESIGN.md". Chi tiết từng món (vị trí, điểm
neo, tỉ lệ, rect món trong nền) xem `docs/D_IMAGES.md`.

- **Nền** `app/assets/images/backgrounds/room_v3.webp`: PNG 1600x900
  RGB, **694.028 byte** (ảnh gốc 2048x1152 resize về 1600x900,
  lượng tử hóa 256 màu + dithering Floyd–Steinberg — cùng cách làm
  PR #26 và PR (C)). Giường + gối + gấu, đèn sao, bàn học + cốc +
  bình hoa, kệ sách, tủ quần áo, thảm tròn, chậu cây, cửa sổ +
  bóng nắng trên sàn gỗ còn nguyên, không cắt cụt.
- **Đồ rời** `app/assets/images/furniture/<tên>_v3.webp`: PNG trong
  suốt 512x512, `kind: furniture`, `status: ready`, tỉ lệ bán trong
  suốt 0,00% cả 5 món. KHÔNG cắt từ nền (viền mềm/phát sáng/tương
  phản thấp nên cắt không sạch) — vẽ riêng rồi đặt đúng vị trí để
  phủ khít món vẽ sẵn trong nền (món vẽ sẵn đóng vai trò nền, không
  lộ ra gây hình đôi). Đã ghép thử cả 5 món lên nền ở đúng vị trí
  và xem bằng mắt: không hình đôi, món nằm đúng mặt phẳng
  (giường/bàn/sàn), đúng phối cảnh, không nổi, không lệch.

| Món | Vị trí đặt (cỡ) | Điểm neo (đáy) | Tỉ lệ |
|---|---|---|---|
| Gấu bông | (296,343) 239 | (415,550) | 0,466 |
| Đèn sao | (49,408) 196 | (150,580) | 0,383 |
| Chậu cây | (678,378) 358 | (842,686) | 0,70 |
| Bình hoa | (1162,273) 283 | (1305,510) | 0,553 |
| Cốc bút | (1027,378) 161 | (1099,515) | 0,315 |

- **Cách vẽ cảnh** (`app/lib/features/room/room_screen.dart`):
  cảnh chiếm toàn bộ bề rộng, tỉ lệ 16:9 cố định (`AspectRatio`
  + `LayoutBuilder`), nền vẽ `BoxFit.fill` — KHÔNG dùng `cover`
  như bản v2 vì `cover` cắt nền làm lệch vị trí khung 1600x900.
  Mọi tọa độ trong `room_assets.dart` theo khung nền 1600x900.
- **Bóng đổ**: PNG đồ rời không nướng bóng; app vẽ ellipse mờ đen
  20% ngay dưới điểm neo đáy của mỗi món (rộng 85% bề ngang món,
  cao 10% bề ngang, mép trên ở neo − 0,3×cao bóng — cùng quy tắc
  A1), vẽ theo chân y: bình hoa, cốc bút, gấu bông, đèn sao, chậu
  cây, rồi nhân vật + pet (chân y = 810, gần nhất).
- **Sàn** (đa giác, nơi nhân vật + pet đứng, khung 1600x900):
  (0,795), (400,645), (1200,645), (1600,795), (1600,900), (0,900).
  Mặt giường y≈540–560 (x 155–760, gấu neo y = 550); mặt tủ đầu
  giường y≈580 (x 30–260, đèn neo y = 580); mặt bàn học y≈490–515
  (x 1070–1470, bình neo y = 510, cốc neo y = 515).
- **Dấu chân trên sàn** (`roomObstacleFootprints`; PR (G) ĐÃ LÀM —
  vùng đi được = đa giác sàn trừ các dấu chân này, xem mục "Đi lại
  trong Phòng (G)" dưới): giường (155,645)-(760,700); bàn học
  (1070,645)-(1470,790); tủ quần áo (1460,645)-(1600,880); tủ đầu
  giường (30,700)-(260,800). Kệ sách gắn tường nên không có dấu
  chân riêng (hình chiếu xuống sàn trùng dấu chân bàn học).
- **Ghế ở bàn học** (`roomChairRect`/`roomChairSeat`; mới là hằng số
  đo sẵn — **chưa có tương tác ngồi ghế** trong code, PR (G) chỉ làm đi
  lại): rect ghế
  (970,490)-(1240,790); mặt ghế (1000,615)-(1210,660), tâm
  ≈ (1105,640).
- **Mốc tỉ lệ** (đo từ ảnh thật, khung 1600x900): mặt trước giường
  cao 160 px; tủ quần áo y 70–880; bàn học cao 300 px; tủ đầu
  giường x 30–260, mặt y≈580, đáy y≈795; kệ sách x 1150–1470,
  y 40–640; cửa sổ x 590–1080, y 100–450; lò sưởi x 640–930,
  y 490–600; thảm tròn ellipse x 430–1060, y 700–875 (tâm
  ≈ (745,787)); rèm trái x ≈460–580, rèm phải x ≈1080–1180,
  y 60–460; kệ mây x 60–220, y 200–300; khung ảnh x 230–310,
  y 180–320; đèn mây trần x 730–870, y 0–55.
- **Nhân vật + pet** (hiện hành, `room_screen.dart`): nhân vật là
  `KidSprite` (ảnh toàn thân, xem "Nhân vật toàn thân"), cao 360 px
  trong khung nền — hộp cao `1536 × 360 / 1287` ≈ 430 px, rộng ≈ 286 px,
  chân ở `kidFeetFraction` (1429/1536) chiều cao hộp; chỗ đứng mặc định
  `roomCharacterFeet` = (630, 810), ~2,25 lần mặt trước giường, đúng cỡ
  so với giường/tủ/cửa sổ. Pet (trứng hoặc 3 giai đoạn, PNG thật PR #21)
  chân mặc định (420, 810), hộp vuông `petBoxSize(stage)` (xem "Thang cỡ
  pet" dưới), chân (đất y = 440/512) ở 440/512 chiều cao hộp. Cả hai
  đứng trên thảm, trước giường, có bóng đổ, và nhân thêm tỉ lệ chiều sâu
  (`roomDepthScale`). Các hằng `roomCharacterBox` (284x425) và
  `roomPetBox` (140x140) trong `room_assets.dart` là cỡ cũ của bản tạm,
  chưa dọn và không còn quyết định cỡ vẽ.

### Thang cỡ pet (F, `app/lib/features/room/pet_growth.dart`)

Chiều cao thân pet tính theo tỉ lệ so với nhân vật (360 px khung Phòng,
`petHeightRatio`); ảnh pet 512x512 có thân cao 400 px (y 40–440) ở mọi
giai đoạn nên hộp vẽ = chiều cao thân × 512/400 (`petBoxSize`).

| Giai đoạn (`PetStage`) | Tỉ lệ | Chiều cao thân | Hộp vẽ | Khi nào |
| --- | --- | --- | --- | --- |
| Trứng `egg` | 30% | 108 px | ~138 px | chưa nở |
| Mới nở `newborn` | 40% | 144 px | ~184 px | 0–2 ngày xong đề |
| Tuổi nhỡ `teen` | 58% | ~209 px | ~267 px | 3–7 ngày |
| Trưởng thành `adult` | 72% | ~259 px | ~332 px | từ 8 ngày |

- Tăng trưởng theo **số ngày bé xong TRỌN đề ngày** (đủ 5 chặng, đếm
  thẳng từ bảng `daily_sets` bằng `PetGrowthService.doneDays`;
  `petTeenDays` = 3, `petAdultDays` = 8), KHÔNG theo số dạng bài thành
  thạo như bản thiết kế đầu (DESIGN/PLAN T2-07).
- Nhỡ 58% là cỡ chủ dự án chốt "tạm thời để vậy xem sao". Bảng 33/43/58/69%
  trong `docs/E_IMAGES.md` là đề xuất của giai đoạn vẽ, đã bị thay bằng
  bảng này. Mã tên giai đoạn: `egg`/`newborn`/`teen`/`adult` (khớp tên
  file `<loài>_<giai đoạn>.webp`).

### Đi lại trong Phòng (G, `app/lib/features/room/room_walk.dart`)

ĐÃ LÀM (PR #34). Logic thuần, test ở `app/test/features/room/
room_walk_test.dart`; `room_screen.dart` chỉ gọi `roomWalkTarget` /
`roomWalkPath` / `roomPetFollowSpot` và chạy animation.

- **Vùng đi được**: đa giác sàn `roomFloorPolygon` trừ dấu chân đồ đạc
  `roomObstacleFootprints` (giường, bàn học, tủ quần áo, tủ đầu giường)
  **phình ra** `roomWalkMargin` = 14 px; chân y giới hạn trong
  [`roomWalkMinY` = 668, `roomWalkMaxY` = 880]; x cách mép ≥ 14 px; điểm
  phải nằm trong sàn khi dịch lên 14 px (`roomWalkable`).
- **Chạm đâu đi đó** (`roomWalkTarget`): chạm vào chỗ đứng được thì đi
  tới đúng đó; chạm tường/giường/đồ thì dò XUỐNG dần (bước 4 px) tới chỗ
  đứng được đầu tiên (nghĩa là đứng trước món đó), không được thì dò
  ngang hai phía, cuối cùng về chỗ mặc định.
- **Đường đi** (`roomWalkPath`): đi thẳng nếu đoạn không bị chặn; bị chặn
  thì vòng: đi xuống một hàng y (bước 6 px, tới `roomWalkMaxY`), đi ngang,
  rồi đi lên tới đích. Kiểm chặn bằng giao đoạn–hình chữ nhật CHÍNH XÁC
  (Liang–Barsky) với từng dấu chân đã phình, không lấy mẫu (lấy mẫu lọt
  góc); vùng sàn là hình lồi nên chỉ cần hai đầu mút đứng được.
- **Tỉ lệ chiều sâu** (`roomDepthScale`): `1 + (y − 810) × 0,0016`, kẹp
  trong [0,72; 1,12]; y = 810 đúng cỡ gốc, xa (y nhỏ) nhỏ dần. Nhân vật và
  pet vẽ theo chân y (xa trước, gần sau) nên ai đứng trước che đúng.
- **Tốc độ**: nhân vật `roomWalkSpeed` = 300 px khung/giây; pet 1,15 lần.
  Hướng đi sang trái thì lật ngang (`facingLeft`); đi lên rõ rệt
  (độ dốc > 0,35) thì dùng khung đi bộ `ur`.
- **Pet theo sau** (`roomPetFollowSpot`): đứng sau lưng bé (ngược hướng
  mặt) cách ~150 px, +6 px y; không đứng được thì thử phía trước, rồi về
  chỗ gần nhất. Pet bắt đầu đi sau bé 350 ms, tới nơi thì quay mặt về phía
  bé. Chỉ theo khi đã nở (trứng đứng yên).
- Khi chạy test (`AnimationGate` tắt) nhân vật tới nơi ngay, không animation.
- CHƯA làm: ngồi ghế ở bàn học (xem `roomChairSeat` ở trên).

- **Kiểm chứng bằng code** (bài học PR #31 — xem `docs/D_IMAGES.md`
  mục 8): mọi điểm neo/đa giác/dấu chân đã kiểm bằng code trên ảnh
  nền thật (mẫu màu pixel + alpha bbox PNG riêng), không tin mắt.
  Đã sửa: 3 món thiếu 2 px ở đáy (gấu/đèn/bình dời xuống 2 px);
  thảm tròn khai báo sai (đúng x 430–1060, y 700–875); rèm trái/
  phải khai báo sai (trái x ≈460–580, phải x ≈1080–1180); rect
  hiển thị đèn/cốc lệch 1–3 px (đèn x[86,209], cốc x[1058,1138]
  y[404,514]). Test `app/test/features/room/room_anchors_test.dart`
  khóa lại: điểm neo trên mặt phẳng đúng, rect hiển thị phủ khít
  món trong nền (dung sai 2 px), chân nhân vật/pet trên sàn, dấu
  chân chạm sàn.
- **Manifest**: thêm 6 mục v3b (nền + 5 món) → 107 mục lúc đó (nay 192, sau các lô nhân vật toàn thân);
  `check_assets.py` xanh. File + mục manifest v2 (`room_v2.webp` +
  8 món, không dùng nữa) GIỮ NGUYÊN như tiền lệ `town_v2.webp`
  (xóa mục khi file còn sẽ làm check fail); Claude có thể `git rm`
  file + mục v2 sau (xem "Việc còn lại" trong PR (D)).

## Âm thanh và nhạc nền (T2-08)

Toàn bộ âm thanh trong `app/assets/sounds/` do Claude **tự tổng hợp** bằng
`tools/audio/generate_audio.py` (sóng sin/tam giác có đường bao, vang nhẹ),
không lấy từ nguồn ngoài nên **không có giấy phép bên thứ ba** (bản gốc quy
định nguồn CC0 trong PLAN T2-08; chủ dự án đồng ý tự tạo vì sandbox không
tải được). 4 file WAV cũ (`correct`, `wrong`, `coin`, `stage_complete`) cũng
là tổng hợp (xem `app/assets/sounds/README.md`).

- Chạy lại: `python3 tools/audio/generate_audio.py [--preview /tmp/x.mp3]`
  (cần numpy + ffmpeg có libvorbis). Hạt giống cố định, hai lần chạy ra file
  giống hệt từng byte.
- Hiệu ứng mới (mono 44,1 kHz WAV, đỉnh −2 dBFS): `tap` 0,13 s, `swoosh`
  0,5 s, `hatch` 1,0 s, `level_up` 1,6 s, `purchase` 0,95 s, `gift_open`
  1,0 s, `streak` 1,0 s, `error_soft` 0,28 s.
- Nhạc nền (stereo OGG Vorbis ~80 kbps, ~−16 LUFS, đỉnh < −1 dBFS, độ dài
  đúng số ô nhịp + vang vòng tròn nên lặp liền mạch): `music_town.ogg`
  (Đô trưởng, 110 BPM, 32 ô ≈ 69,8 s, I–V–vi–IV) và `music_room.ogg`
  (Fa trưởng, 85 BPM, 24 ô ≈ 67,8 s, I–V–vi–IV, hộp nhạc). App phát nhạc
  ở âm lượng 0,35 nên nhỏ hơn hiệu ứng.
- Cài đặt: `sound_enabled` (hiệu ứng) và `music_enabled` (nhạc nền) trong
  `settings`, cấp máy, không đồng bộ (`isLocalOnlySettingKey`); nút loa
  `sound-settings-button` ở HUD Phòng/Thị trấn mở bảng `toggle-sfx` /
  `toggle-music`, không cần cổng phụ huynh.
- Integration test đặt `AudioGate.enabled = false` (`lib/features/sound/
  audio_gate.dart`) nên hiệu ứng và nhạc không phát trên máy ảo CI.
