# Hình PR (C) Thị trấn v3b — giai đoạn 1: chỉ đẩy hình, chưa có code

Nhánh `task/C-thi-tran-v3b`, từ main `f45c940d` (PR #30 (B) đã merge).
Đẩy 10 ảnh dưới dạng base64 để Claude giải mã bằng
`python3 tools/assets/decode_incoming.py` rồi commit hình lên đúng nhánh,
sau đó mới làm giai đoạn 2 (code + manifest + mở PR).

Ảnh gốc: thị trấn v3b phong cách isometric 3D mềm khối tròn pastel, đúng
6 công trình, đã được chủ dự án duyệt (21/11 ~01:31). Nền sạch lấy từ bản
xem trước đã duyệt, đã xóa xe và người khỏi đường/vỉa hè (đường và vỉa hè
TRỐNG, app vẽ lớp động chạy theo đường). Lớp động vẽ rời bằng AI cùng
phong cách v3b, tách nền magenta bằng chroma-key, xem bằng mắt trên nền
caro và ghép thử lên nền thật: cùng tông với nền, không lẫn nền, không
cắt cụt, tỉ lệ hợp lý so với công trình.

## Lưu ý định dạng nền

- Nền thị trấn đẩy dạng **PNG** (`town_v3.png`), KHÔNG phải JPEG như
  `docs/ASSETS.md` ghi cho loại `background`. Lý do: `tools/assets/decode_incoming.py`
  trên main chỉ chấp nhận PNG (kiểm tra signature PNG, báo lỗi với file khác).
- PNG 1600x900 đủ màu là 2.243.101 byte (> 1 MB) nên đã lượng tử hóa 256 màu
  + dithering Floyd-Steinberg: còn **678.089 byte** (< 1 MB), xem bằng mắt
  không thấy nhiễu dithering ở cỡ hiển thị, đủ 6 công trình, không cắt cụt.
- Giai đoạn 2 sẽ cập nhật `docs/ASSETS.md` + manifest cho đúng
  (nền `town_v3.png`, khung 1600x900).

## Đài phun nước: KHÔNG có

Thị trấn v3b có **hồ nước** (góc phải dưới), không có đài phun nước nên
không bịa thêm lớp `fountain`. Mây, cây đung đưa là lớp rời như v2.

## Danh sách file

| File .b64 | Đường dẫn đích | Cỡ gốc (byte) | Khung | Mô tả |
| --- | --- | ---: | --- | --- |
| `app/assets/_incoming/app/assets/images/backgrounds/town_v3.png.b64` | `app/assets/images/backgrounds/town_v3.png` | 678089 | 1600x900 | Nền thị trấn v3b (isometric, 6 công trình, đường/vỉa hè trống) |
| `app/assets/_incoming/app/assets/images/town/car_01.png.b64` | `app/assets/images/town/car_01.png` | 156252 | 512x512 | Xe hơi hồng, nhìn sang trái |
| `app/assets/_incoming/app/assets/images/town/car_02.png.b64` | `app/assets/images/town/car_02.png` | 123984 | 512x512 | Xe hơi xanh nhạt, nhìn sang phải |
| `app/assets/_incoming/app/assets/images/town/cloud_01.png.b64` | `app/assets/images/town/cloud_01.png` | 112330 | 512x512 | Mây trắng phồng |
| `app/assets/_incoming/app/assets/images/town/cloud_02.png.b64` | `app/assets/images/town/cloud_02.png` | 91522 | 512x512 | Mây trắng (lật ngang + thu 0,85 từ cloud_01) |
| `app/assets/_incoming/app/assets/images/town/cloud_03.png.b64` | `app/assets/images/town/cloud_03.png` | 116622 | 512x512 | Mây trắng (lật ngang + phóng 1,10, dẹt 0,92 từ cloud_01) |
| `app/assets/_incoming/app/assets/images/town/person_01.png.b64` | `app/assets/images/town/person_01.png` | 145025 | 512x512 | Bé gái mũ hồng, váy xanh |
| `app/assets/_incoming/app/assets/images/town/person_02.png.b64` | `app/assets/images/town/person_02.png` | 141329 | 512x512 | Bé trai mũ xanh, áo xanh lá |
| `app/assets/_incoming/app/assets/images/town/tree_01.png.b64` | `app/assets/images/town/tree_01.png` | 182944 | 512x512 | Cây xanh tán tròn |
| `app/assets/_incoming/app/assets/images/town/tree_02.png.b64` | `app/assets/images/town/tree_02.png` | 228039 | 512x512 | Cây hoa anh đào hồng |

Tất cả ảnh gốc đều <= 1 MB. Lớp động PNG trong suốt 512x512, nền 1600x900.

## Vị trí 6 công trình trong khung nền 1600x900 (đo từ nền sạch thật)

Đo bằng mắt trên lưới 100px + quét màu đường bằng pixel, gần đúng.
Dùng cho giai đoạn 2 đặt vùng bấm. Tọa độ (x, y, w, h), gốc trên-trái.

| Công trình | Rect (x, y, w, h) | Ghi chú |
| --- | --- | --- |
| Lâu đài Lôgic (tím/xanh đá, cờ) | 165, 0, 450, 290 | Lâu đài + tường đá bao quanh; tháp cao nhất chạm mép trên ảnh |
| Tháp Con số (vàng, mặt đồng hồ) | 520, 185, 560, 205 | Cả khuôn viên có rào (ghế, cây, cầu trượt + xích đu nhỏ trong khuôn viên tháp); riêng thân tháp 675, 5, 100, 325 |
| Hội chợ Tổ hợp (lều sọc + vòng quay) | 1020, 5, 540, 375 | Gộp 2 lô (lều + vòng quay) có đường chéo chạy giữa, không có công trình khác ở đó nên không chồng vùng bấm |
| Tiệm bánh Số học (vàng, biển bánh sừng bò) | 290, 305, 350, 255 | Chỉ thân tiệm (mái + tường + chậu hoa trước cửa) |
| Vườn Hình học (khối lập phương/kim tự tháp/cầu/trụ) | 480, 520, 445, 225 | Vườn có rào, cây + chậu hoa |
| Nhà của bé (nhà hồng, Phòng) | 35, 525, 455, 330 | Nhà + sân có hàng rào trắng; riêng thân nhà 75, 545, 235, 245 |

Khối trang trí, KHÔNG có vùng bấm: công viên giữa-phải (850, 290, 510, 270)
có xích đu + cầu trượt (giữ nguyên từ bản nền sạch); hồ nước góc phải
dưới (1160, 520, 440, 280).

## Đoạn đường (để giai đoạn 2 khai báo đường đi cho xe/người)

Đường đi là các đoạn thẳng (polyline) theo hướng đường isometric, tâm đường
+ nửa rộng 50px (gồm mặt đường + vỉa hè). Đo từ nền thật bằng quét màu
đường + xem bằng mắt; **gần đúng ±40px — giai đoạn 2 kiểm chứng bằng test**
(mọi điểm trên đường đi phải nằm trong vùng đường đã khai báo) và hiệu
chỉnh theo ảnh nếu lệch.

| Đoạn | Hướng | Polyline (x, y) | Tách |
| --- | --- | --- | --- |
| D1 | ↙ | (880,70) → (600,210) → (300,360) → (0,480) | Lâu đài khỏi tháp/tiệm bánh |
| D2 | ↘ | (880,70) → (1120,220) → (1420,380) → (1600,470) | Tháp khỏi hội chợ |
| D3 | ↙ | (720,450) → (550,560) → (250,710) → (0,830) | Trước tiệm bánh + nhà hồng |
| D4 | ↘ | (720,450) → (880,550) → (1090,650) → (1400,800) → (1500,850) | Vườn khỏi công viên/hồ |
| D5 | ↙ | (1400,480) → (1250,570) → (1100,650) → (900,750) → (700,850) | Công viên khỏi hồ, xuống ngã tư dưới |
| D6 | ↘ | (1150,680) → (1300,760) → (1500,850) → (1600,900) | Dưới hồ |

Ngã giao: D1×D2 tại (880,70); D3×D4 tại (720,450); D4×D5 tại
(1100,650); D5×D6 tại (1300,760). Các đoạn cụt ở mép khung (thị trấn còn
nối ra ngoài khung); đường đi giai đoạn 2 chạy tới-lui trên các đoạn này:
xe chạy giữa làn, người đi trên vỉa hè (lệch tâm đường ~25px sang một bên).
Vẽ theo thứ tự chiều sâu: công trình trước che xe sau (giai đoạn 2 quyết
thứ tự vẽ theo y); không đi xuyên qua công trình.

## Lớp động — cách chuyển động (giai đoạn 2, Flutter animation + AnimationGate)

| Lớp | Chuyển động |
| --- | --- |
| `cloud_01/02/03` | Trôi ngang qua bầu trời, chậm, mỗi mây tốc độ/hướng khác nhau, lặp |
| `car_01_dr/ur`, `car_02_dr/ur` | Chạy dọc đường (theo D1–D6), giữa làn, tới-lui; dr chạy ↘ (D2/D4/D6), ur chạy ↗ (ngược D1/D3/D5); lật ngang cho 2 hướng còn lại (lật dr → ↙, lật ur → ↖) |
| `person_01_dr_a/b`, `person_01_ur_a/b`, `person_02_dr_a/b`, `person_02_ur_a/b` | Đi bộ dọc vỉa hè (lệch tâm đường), đổi khung a/b xen kẽ thành dáng đi, lặp |
| `tree_01/02` | Đung đưa nhẹ (xoay ±2° quanh gốc thân) |

Lớp động vẽ rời nên app có thể đặt/animate độc lập trên nền; nhớ tắt bằng
`AnimationGate` trong test (theo quy tắc đã có từ PR #22).

## Giai đoạn 1b: sửa 4 lớp lỗi (21/11, sau decode lần 1 commit `9e09cdd`)

Nền `town_v3.png` ĐẠT (đường trống, đủ 6 công trình). 4 lớp lỗi, làm lại:

- `person_01`, `person_02`: da mặt/tay/chân trong suốt loang — đo lại
  bằng code: person_01 **30,37%**, person_02 **23,64%** điểm ảnh bán trong
  suốt. Vẽ lại góc isometric 3/4, cùng nhân vật (bé gái mũ hồng/váy xanh,
  bé trai mũ xanh/áo xanh lá).
- `car_01`: kính/thân trong suốt loang (**28,68%**). Vẽ lại góc 3/4.
  `car_02` cũ 5,67% (về độ đặc thì đạt) nhưng cũng vẽ lại theo góc mới cho
  đồng bộ hai xe.
- `tree_02`: hoa anh đào bán trong suốt **46,46%** — SỬA BẰNG CODE, không vẽ
  lại: tán hoa gần giống màu magenta nên chroma-key giai đoạn 1 đã ăn mòn
  cả tán; ép alpha ≥64 → 255, chỉ giữ mép ngoài mềm 1 px → còn **4,53%**.

Tỉ lệ bán trong suốt = số pixel có 0 < alpha < 255 chia cho số pixel có
alpha > 0; **phải < 5% cho mọi file** (đo bằng code sau khi tách nền +
resize + đóng gói 512x512, đã xem bằng mắt từng lớp trên nền xám: mặt/tay/
chân đặt lên đường xám không nhìn xuyên qua).

### Danh sách file 1b (13 file .b64, đẩy cùng lần này)

| File .b64 | Đường dẫn đích | Cỡ gốc (byte) | Tỉ lệ bán trong suốt | Mô tả |
| --- | --- | ---: | ---: | --- |
| `app/assets/_incoming/app/assets/images/town/car_01_dr.png.b64` | `app/assets/images/town/car_01_dr.png` | 85534 | 1,64% | Xe hồng, góc 3/4 trước, đầu xe hướng xuống-phải (↘) |
| `app/assets/_incoming/app/assets/images/town/car_01_ur.png.b64` | `app/assets/images/town/car_01_ur.png` | 88800 | 1,35% | Xe hồng, góc 3/4 sau, đuôi xe hướng lên-phải (↗) |
| `app/assets/_incoming/app/assets/images/town/car_02_dr.png.b64` | `app/assets/images/town/car_02_dr.png` | 93584 | 0,99% | Xe xanh nhạt, góc 3/4 trước, ↘ |
| `app/assets/_incoming/app/assets/images/town/car_02_ur.png.b64` | `app/assets/images/town/car_02_ur.png` | 105857 | 0,94% | Xe xanh nhạt, góc 3/4 sau, ↗ |
| `app/assets/_incoming/app/assets/images/town/person_01_dr_a.png.b64` | `app/assets/images/town/person_01_dr_a.png` | 121063 | 2,53% | Bé gái, góc 3/4 trước, ↘, khung bước chân a |
| `app/assets/_incoming/app/assets/images/town/person_01_dr_b.png.b64` | `app/assets/images/town/person_01_dr_b.png` | 123066 | 2,46% | Bé gái, góc 3/4 trước, ↘, khung bước chân b |
| `app/assets/_incoming/app/assets/images/town/person_01_ur_a.png.b64` | `app/assets/images/town/person_01_ur_a.png` | 134056 | 3,03% | Bé gái, góc 3/4 sau, ↗, khung a (chân trái trước) |
| `app/assets/_incoming/app/assets/images/town/person_01_ur_b.png.b64` | `app/assets/images/town/person_01_ur_b.png` | 136370 | 2,80% | Bé gái, góc 3/4 sau, ↗, khung b (chân phải trước) |
| `app/assets/_incoming/app/assets/images/town/person_02_dr_a.png.b64` | `app/assets/images/town/person_02_dr_a.png` | 116387 | 2,50% | Bé trai, góc 3/4 trước, ↘, khung a |
| `app/assets/_incoming/app/assets/images/town/person_02_dr_b.png.b64` | `app/assets/images/town/person_02_dr_b.png` | 114466 | 2,59% | Bé trai, góc 3/4 trước, ↘, khung b |
| `app/assets/_incoming/app/assets/images/town/person_02_ur_a.png.b64` | `app/assets/images/town/person_02_ur_a.png` | 116406 | 2,14% | Bé trai, góc 3/4 sau, ↗, khung a |
| `app/assets/_incoming/app/assets/images/town/person_02_ur_b.png.b64` | `app/assets/images/town/person_02_ur_b.png` | 109484 | 1,90% | Bé trai, góc 3/4 sau, ↗, khung b |
| `app/assets/_incoming/app/assets/images/town/tree_02.png.b64` | `app/assets/images/town/tree_02.png` | 207196 | 4,53% | Cây hoa anh đào, ghi đè cùng tên (sửa bằng code, không vẽ lại) |

Tất cả đều 512x512, PNG trong suốt, ≤ 1 MB. Ghi chú: tỉ lệ của 2 file
`person_01_ur_a/b` cao nhất (3,03%/2,80%) do vân len của mũ có rãnh nhỏ
vẫn giữ lại sau khi thu nhỏ — vẫn dưới 5%.

### Hướng, khung bước chân và neo chân (giai đoạn 2 lưu ý)

- `dr` = xuống-phải (↘): chạy trên D2, D4, D6. `ur` = lên-phải (↗): chạy
  ngược chiều D1, D3, D5. Hai hướng còn lại app lật ngang: lật `dr` → ↙,
  lật `ur` → ↖. Đã ghép thử xe/người lên nền thật: góc 3/4 trùng hướng
  đường chéo, không lệch phối cảnh.
- Khung `a/b` của cùng một người/hướng là cùng nhân vật, chỉ khác vị trí
  chân + tay (đã kiểm bằng mắt); app đổi a/b xen kẽ thành dáng đi.
- Xe 3/4 bị rút ngắn theo phối cảnh: bề ngang lớp 302–371 px (xe cũ nhìn
  ngang 430–432 px) ở cùng chiều cao ~275 px. Giai đoạn 2 kiểm cỡ hiển thị
  trên đường (~110–120 px dài) chứ không giả định tỉ lệ lớp cũ.
- Neo chân trong khung 512x512: xe đáy y=390 (bánh xe), người đáy y=470
  (chân) — đặt lớp sao cho điểm neo này chạm mặt đường/vỉa hè.
- Lớp KHÔNG có bóng đổ sẵn (chroma-key đã tách cả bóng mềm của AI, kể cả
  vệt bóng loang còn sót — đã xóa bằng lọc thành phần liên thông + xóa
  điểm ảnh magenta đậm). Giai đoạn 2 tự vẽ bóng ellipse mềm dưới xe/người
  như PR Phòng đã làm cho đồ rời.

### File cũ Claude XÓA BẰNG GIT sau khi decode lần 2

`push-files` không xóa được file. Sau khi decode 13 file 1b, xóa trên nhánh
`task/C-thi-tran-v3b` bằng git (đã bị thay bằng file hướng/khung mới):

- `app/assets/images/town/car_01.png`
- `app/assets/images/town/car_02.png`
- `app/assets/images/town/person_01.png`
- `app/assets/images/town/person_02.png`

`tree_02.png` ghi đè cùng tên nên không cần xóa. Các file còn lại của giai
đoạn 1 (`town_v3.png`, `cloud_01/02/03.png`, `tree_01.png`) giữ nguyên.
