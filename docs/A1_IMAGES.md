# Hình A1 Phòng (phong cách v2) — giai đoạn 1: chỉ đẩy hình, chưa có code

Nhánh `task/A1-phong-v2`, từ main `adf4e02` (PR #23 T2-04 đã merge).
Đẩy 9 ảnh dưới dạng base64 để Claude giải mã bằng
`python3 tools/assets/decode_incoming.py` rồi commit hình lên đúng nhánh,
sau đó mới làm giai đoạn 2 (code + manifest + mở PR).

## Lưu ý định dạng nền

- Nền phòng đẩy dạng **PNG** (`room_v2.webp`), KHÔNG phải JPEG như `docs/ASSETS.md`
  ghi cho loại `background`. Lý do: `tools/assets/decode_incoming.py` trên main
  chỉ chấp nhận PNG (kiểm tra signature PNG, báo lỗi với file khác).
- PNG 1600x900 này chỉ 928.630 byte (< 1 MB) nên đẩy PNG là được, không cần
  đổi script. Giai đoạn 2 sẽ cập nhật `docs/ASSETS.md` + manifest cho đúng
  (nền `room_v2.webp`, khung 1600x900).

## Danh sách file

| File .b64 | Đường dẫn đích | Cỡ gốc (byte) | Mô tả |
| --- | --- | ---: | --- |
| `app/assets/_incoming/app/assets/images/backgrounds/room_v2.png.b64` | `app/assets/images/backgrounds/room_v2.png` | 928630 | Nền phòng trống v2 (1600x900, phối cảnh 1 điểm tụ) |
| `app/assets/_incoming/app/assets/images/furniture/goi.png.b64` | `app/assets/images/furniture/goi.png` | 145272 | Gối hồng |
| `app/assets/_incoming/app/assets/images/furniture/coc_sao.png.b64` | `app/assets/images/furniture/coc_sao.png` | 170926 | Cốc sao xanh |
| `app/assets/_incoming/app/assets/images/furniture/binh_hoa.png.b64` | `app/assets/images/furniture/binh_hoa.png` | 177820 | Bình hoa |
| `app/assets/_incoming/app/assets/images/furniture/chau_cay.png.b64` | `app/assets/images/furniture/chau_cay.png` | 231044 | Chậu cây |
| `app/assets/_incoming/app/assets/images/furniture/khung_anh.png.b64` | `app/assets/images/furniture/khung_anh.png` | 184870 | Khung ảnh gỗ |
| `app/assets/_incoming/app/assets/images/furniture/gau_bong.png.b64` | `app/assets/images/furniture/gau_bong.png` | 219756 | Gấu bông |
| `app/assets/_incoming/app/assets/images/furniture/den_sao.png.b64` | `app/assets/images/furniture/den_sao.png` | 141418 | Đèn sao |
| `app/assets/_incoming/app/assets/images/furniture/day_co.png.b64` | `app/assets/images/furniture/day_co.png` | 81712 | Dây cờ |

Tất cả ảnh gốc đều <= 1 MB. Đồ rời PNG trong suốt 512x512, nền 1600x900.
Ảnh gốc: phong cách v2 đã duyệt (3D mềm, ánh sáng từ trên-trái, bóng đổ mềm).

## Giai đoạn 2a — sửa vệt bóng (chỉ hình, chưa code)

Sau khi Claude decode + commit 9 PNG (commit `138c2b2`), kiểm tra thấy 8 PNG
đồ rời đều dính vệt bóng màu loang dưới chân + mép răng cưa do tách nền.
Giai đoạn 2a cắt lại 8 PNG đó từ tấm nguồn, **xóa sạch vệt bóng khỏi PNG**
(alpha quanh món đồ sạch, không còn bóng nào trong ảnh). Nền `room_v2.webp`
không có lỗi này nên giữ nguyên, không đẩy lại.

Cách làm (script ở `~/workspace/timokid-review/a1-phong-v2/work/cut9.py`,
điểm đường chân đọc bằng mắt trên lưới tọa độ `grid_<tên>.webp`):
flood-fill tách nền theo màu nền từng ô, rồi cắt theo **đường chân thủ công**
(ground line) dọc mép dưới của món đồ — vì vệt bóng và phần shading dưới
của món đồ cùng tông màu, nối nhau bằng gradient mượt nên không có ngưỡng
màu/step nào tách được sạch mà không ăn vào món đồ (đã thử 5 biến thể
flood-fill/trim: hoặc còn vệt bóng, hoặc ăn cụt gối/gấu/cốc/bình).
Viền làm mềm 1,2 px. `den_sao` và `day_co` vốn đã sạch nên giữ nguyên bản
cắt flood-fill, chỉ mã hóa lại.

Đã kiểm chứng từng PNG trên nền caro + đo số pixel mờ dưới đáy: cả 8 món
đều nguyên vẹn (gối đủ 4 pom-pom, gấu đủ chân/tay, cốc đủ vành đáy, bình/chậu/
khung đủ đáy), không còn vệt bóng, không răng cưa, 0 pixel mờ dưới 60 hàng
cuối của ảnh 512x512. Xem `preview9_<tên>.webp` trong `work/`.

| File .b64 (đẩy lại) | Đường dẫn đích | Cỡ gốc mới (byte) | Ghi chú |
| --- | --- | ---: | --- |
| `app/assets/_incoming/app/assets/images/furniture/goi.png.b64` | `app/assets/images/furniture/goi.png` | 120570 | Đã xóa vệt bóng hồng + mép răng cưa; thêm cleanup góc lõm trái pom-pom dưới |
| `app/assets/_incoming/app/assets/images/furniture/coc_sao.png.b64` | `app/assets/images/furniture/coc_sao.png` | 89398 | Đã xóa blob bóng xanh dưới đáy cốc |
| `app/assets/_incoming/app/assets/images/furniture/binh_hoa.png.b64` | `app/assets/images/furniture/binh_hoa.png` | 113989 | Đã xóa vệt bóng xanh lá dưới đáy bình |
| `app/assets/_incoming/app/assets/images/furniture/chau_cay.png.b64` | `app/assets/images/furniture/chau_cay.png` | 123984 | Đã xóa vệt bóng nâu vàng dưới đáy chậu |
| `app/assets/_incoming/app/assets/images/furniture/khung_anh.png.b64` | `app/assets/images/furniture/khung_anh.png` | 110864 | Đã xóa vệt bóng tím dưới đáy khung |
| `app/assets/_incoming/app/assets/images/furniture/gau_bong.png.b64` | `app/assets/images/furniture/gau_bong.png` | 144654 | Đã xóa vệt bóng hồng dưới chân gấu |
| `app/assets/_incoming/app/assets/images/furniture/den_sao.png.b64` | `app/assets/images/furniture/den_sao.png` | 97915 | Vốn đã sạch, mã hóa lại từ bản cắt flood-fill |
| `app/assets/_incoming/app/assets/images/furniture/day_co.png.b64` | `app/assets/images/furniture/day_co.png` | 78811 | Vốn đã sạch, mã hóa lại từ bản cắt flood-fill |

Bóng đổ sẽ do app vẽ (xem `docs/STATUS_2B.md`), không nướng trong PNG.
Cần Claude decode lần 2 rồi mới làm giai đoạn 2b (code + manifest + mở PR).

## Giai đoạn 2a vòng 3 — sửa 6 món bị cắt cụt hai bên (chỉ hình, chưa code)

Claude decode THỬ commit `96ccf79` nhưng CHƯA commit: vệt bóng đã hết, nhưng
6/8 món bị CẮT MẤT HAI BÊN thành cạnh thẳng đứng — bình hoa (mất hai hông
bình), chậu cây (mất hai mép chậu), cốc (mất nửa quai phải), gối (mất mép
trái), khung ảnh (còn mẩu thừa góc trái dưới), gấu bông (ổn hơn nhưng kiểm
lại). Nguyên nhân: mặt nạ xóa bóng ở vòng 2 (`cut9.py`) cắt theo cột —
ngoài khoảng x của đường chân thì XÓA CẢ CỘT, nên đã cắt luôn phần thân/
quai/mép vốn nằm thấp hơn đường đó ở hai bên.

Vòng 3 làm lại từ bản cắt v5 (thân nguyên vẹn, chỉ còn vệt bóng), KHÔNG sửa
từ file vòng 2 (phần bị cắt đã mất). Cách làm (script
`~/workspace/timokid-review/a1-phong-v2/work/cut10.py`): đường viền đáy
theo BÓNG DÁNG THẬT của món — tức đường cong là mép dưới của món đồ, đọc
bằng mắt trên lưới tọa độ + dải đáy phóng to 2x (`grid_<tên>.webp`,
`zoom_bottom_<tên>.webp`), trải suốt bề rộng bóng dáng (hông bình, mép chậu,
quai cốc, mép gối, góc khung, tay/chân gấu); CHỈ xóa pixel nằm DƯỚI đường
đó, tuyệt đối không xóa theo cột; ngoài khoảng x của đường thì kéo phẳng
theo điểm đầu/cuối (chỉ xóa vệt bóng dưới, giữ nguyên mọi thứ phía trên).
Bias −2 px (cắt 2 px vào phần shading mềm ở đáy — không nhìn thấy) để
không còn sót vệt bóng; viền làm mềm 1,2 px. Gấu bông hạ thêm 3 px ở
khoảng x=320–345 (bản 548) để xóa một vệt mờ 10x3 px (alpha ≤ 110) còn sót
dưới chân phải.

Đã kiểm chứng từng PNG trên nền tối + nền caro + bản đồ alpha (trắng = mờ
đục, đỏ = mờ nhạt) + đo số: viền ngoài liền mạch, KHÔNG còn cạnh thẳng
đứng; hông bình / mép chậu / quai cốc (đủ cả quai phải) / mép gối / 4
pom-pom / khung (hết mẩu thừa góc trái dưới) / gấu (đủ 2 chân) còn nguyên;
không còn vệt bóng; 0 pixel mờ đục dưới hàng 470; điểm mờ nhạt rời rạc
còn lại ≤ alpha 7 (nhiễu resize, không nhìn thấy). Đèn sao + dây cờ vốn đã
sạch nên không động vào, giữ nguyên bản vòng 2.

| File .b64 (đẩy lại, vòng 3) | Đường dẫn đích | Cỡ gốc mới (byte) | Ghi chú |
| --- | --- | ---: | --- |
| `app/assets/_incoming/app/assets/images/furniture/binh_hoa.png.b64` | `app/assets/images/furniture/binh_hoa.png` | 126329 | Hông bình còn nguyên, hết vệt bóng xanh lá |
| `app/assets/_incoming/app/assets/images/furniture/chau_cay.png.b64` | `app/assets/images/furniture/chau_cay.png` | 135467 | Mép chậu còn nguyên, hết vệt bóng nâu vàng |
| `app/assets/_incoming/app/assets/images/furniture/coc_sao.png.b64` | `app/assets/images/furniture/coc_sao.png` | 95003 | Quai phải còn nguyên, hết vệt bóng xanh |
| `app/assets/_incoming/app/assets/images/furniture/goi.png.b64` | `app/assets/images/furniture/goi.png` | 124811 | Mép trái + 4 pom-pom còn nguyên, hết vệt bóng hồng (kể cả góc lõm pom-pom dưới) |
| `app/assets/_incoming/app/assets/images/furniture/khung_anh.png.b64` | `app/assets/images/furniture/khung_anh.png` | 107950 | Hết mẩu thừa góc trái dưới, hết vệt bóng tím |
| `app/assets/_incoming/app/assets/images/furniture/gau_bong.png.b64` | `app/assets/images/furniture/gau_bong.png` | 140609 | Đủ 2 chân/tay, hết vệt bóng hồng |

Cần Claude decode vòng 3 rồi mới làm giai đoạn 2b (code + manifest + mở PR).
