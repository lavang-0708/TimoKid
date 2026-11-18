# Hình trong app (hợp đồng nạp hình)

Tài liệu này là **hợp đồng** cho mọi hình đưa vào app từ bản 0.2: tên lớp,
thứ tự chồng, khung, cách đặt tên, cách đổi màu. Người cắt/vẽ hình làm
theo đúng tài liệu này; script `tools/assets/check_assets.py` kiểm tra
tự động theo cùng các quy tắc (và chạy trong CI).

Nguồn hình chính là các tấm trong `assets/concept/` (anh Điệp chốt
18/11, PLAN điểm (k)): tách nền, cắt từng món, sửa lỗi theo bảng trong
`assets/concept/README.md`. Món thiếu hoặc hỏng thì vẽ bổ sung cùng
phong cách pastel mềm, viền trắng kiểu sticker. Chi tiết quy cách vẽ
xem `docs/DESIGN.md` mục "Hướng dẫn vẽ cho họa sĩ".

## File hợp đồng

| File | Vai trò |
| --- | --- |
| `assets/manifest.json` | Liệt kê mọi hình: mã, loại, dáng, lớp, có đổi màu không, giá, trạng thái. Đây là danh sách duy nhất app và script cùng đọc. |
| `tools/assets/check_assets.py` | Script kiểm tra (Python, chỉ dùng thư viện chuẩn): khung, PNG trong suốt, tên file, manifest khớp file thật. |
| `tools/assets/check_assets_test.py` | Test cho script (18 test): JPEG báo lỗi, PNG nền đặc báo lỗi, file đúng qua được. |
| `tools/assets/decode_incoming.py` | Giải mã ảnh Muse đẩy dạng base64 (xem "Đường đưa ảnh lên repo"). |
| `app/test/assets_manifest_test.dart` | Test Dart gọi script kiểm tra trong lúc chạy `flutter test` (để CI kiểm tra mà không cần sửa workflow). |

## Thứ tự lớp, từ dưới lên

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
| `background` | Không cố định | JPEG | Nền phòng/thị trấn; JPEG không có nền trong suốt nên không chồng lớp được. Tỉ lệ ngang 16:9, khuyến nghị 1600x900 trở lên. |
| `icon` | Không cố định | SVG | Biểu tượng giao diện (vector). 5 icon khu Thị trấn (T1-12) nằm ngay ở `app/assets/images/area_*.svg`; icon mới cho vào `app/assets/images/icons/`. |

## Quy tắc đặt tên

Mã (`id`) của mỗi mục **trùng với tên file** (không tính đuôi):

- Lớp nhân vật: `<dáng>_<lớp>_<tên món>.png`, ví dụ
  `girl_hair_front_bob.png`, `girl_top_tshirt.png`. Thư mục:
  `app/assets/images/character/<dáng>/` (`girl` hoặc `boy`).
- Pet: `<loài>_<giai đoạn>.png` với loài `dog`/`cat`/`rabbit`, giai đoạn
  `egg`/`newborn`/`teen`/`adult`, ví dụ `dog_egg.png`. Thư mục:
  `app/assets/images/pets/`.
- Đồ vật: `app/assets/images/items/<tên món>.png`.
- Nội thất: `app/assets/images/furniture/<tên món>.png`.
- Nền: `app/assets/images/backgrounds/<tên>.jpg`.
- Icon: `app/assets/images/icons/<tên>.svg` (icon cũ ở gốc
  `app/assets/images/` vẫn hợp lệ).

## Đổi màu (lớp xám) và file `_line`

- Phần cần đổi màu (da, tóc, mắt, miệng, vải quần áo) tô **một màu xám
  sáng duy nhất**, bóng đổ dùng xám đậm hơn. App nhân màu lên lớp xám
  này để đổi màu da/tóc/mắt/quần áo. Script kiểm tra: mọi pixel còn
  thấy được của lớp đổi màu (`recolorable: true`) phải gần như xám
  (R, G, B lệch nhau tối đa 8).
- Nét viền và chi tiết không đổi màu (khuy áo, họa tiết cố định, mi
  mắt, viền miệng) xuất thành file riêng, tên thêm đuôi `_line`, ví dụ
  `girl_top_tshirt_line.png`. File `_line` cùng lớp và cùng z với file
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

- **Dáng nữ** (29 mục, `planned`): thân ×1 (+ viền), mắt ×3 (+ viền),
  miệng ×3 (+ viền), tóc ×3 kiểu (sau + trước), áo ×3, quần/váy ×2,
  giày ×1, phụ kiện đầu ×2 (nơ/kẹp tóc, mũ phù thủy), phụ kiện tay ×1
  (ô dù). Tên món mắt/miệng lấy từ tấm `eyes_mouths_gray.png` đã xem:
  mắt mi dài (×2 kiểu) và mắt tròn; miệng cười, miệng cười hở,
  miệng chữ O. Tên món trang phục để dạng `top_01`… vì chưa xem tấm
  `girl_outfits_gray.png` — người cắt giữ nguyên mã, chỉ điền tên
  hiển thị (`name_vi`) cho đúng món đã cắt.
- **Pet** (12 mục, `planned`): 3 trứng (Chó Tinh Anh, Mèo Mũm Mĩm,
  Thỏ Bánh Bao) + 3 pet mới nở + 3 giai đoạn nhỡ + 3 giai đoạn lớn.
  Lô đầu chỉ cần 3 trứng + 3 pet mới nở; giai đoạn nhỡ/lớn vẽ sau.
- **Dáng nam** (24 mục, `planned`): thân, mắt, miệng, tóc ×2 kiểu,
  trang phục — vẽ dần sau dáng nữ.
- **Nền** (2 mục, `planned`): `room_01.jpg`, `town_01.jpg`.
- **Icon khu Thị trấn** (5 mục, `ready`): `area_logic`,
  `area_arith`, `area_number`, `area_geo`, `area_comb` (SVG, T1-12).

## Thêm một món đồ mới

1. Cắt/vẽ file đúng khung, đúng tên, đúng thư mục (xem bảng trên).
2. Thêm **một dòng** vào `assets/manifest.json` (đủ 13 trường, xem
   mục trên; `status: "ready"`).
3. Chạy `python3 tools/assets/check_assets.py` ở gốc repo — phải
   báo `OK`. Nếu báo lỗi, sửa file hoặc dòng manifest theo đúng
   thông báo (sai khung, thiếu alpha, tên sai, thiếu file…).

## Đường đưa ảnh lên repo

Muse không đẩy được file nhị phân qua GitHub MCP. Ảnh PNG đưa lên
bằng đường vòng base64 (anh Điệp chốt 19/11):

1. Muse đẩy mỗi ảnh thành file text `app/assets/_incoming/
   <đường dẫn đích>.b64` (nội dung chỉ một chuỗi base64 của PNG),
   vài file mỗi lần push nếu file lớn.
2. Claude chạy `python3 tools/assets/decode_incoming.py` trên nhánh
   PR: script giải mã thành PNG đúng đường dẫn, xóa file `.b64` và
   commit lên cùng nhánh.
3. Ảnh xem trước gửi qua chat cho Claude và anh Điệp duyệt mắt
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

Muse không đẩy được file `.github/workflows/` qua MCP (GitHub App
thiếu quyền `workflows`, trả 403) nên bước CI dưới đây nhờ Claude
commit giúp bằng git. Thêm vào `.github/workflows/ci.yml`, ngay sau
step "Câu hỏi mẫu (check.py)" (xem thêm
`tools/assets/ci-step-snippet.yml`):

```yaml
      - name: Kiểm tra hình (manifest)
        working-directory: .
        run: python3 tools/assets/check_assets.py

      - name: Test script kiểm tra hình
        working-directory: .
        run: python3 tools/assets/check_assets_test.py
```

Trong lúc chờ step này lên CI, test Dart
`app/test/assets_manifest_test.dart` đã gọi script kiểm tra trong
bước `flutter test` sẵn có, nên PR vẫn được kiểm tra hình trên CI.
Khi step CI trực tiếp đã chạy ổn, test Dart có thể giữ nguyên làm
kiểm tra dự phòng khi chạy `flutter test` ở local.
