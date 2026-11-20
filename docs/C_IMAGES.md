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
| `car_01/02` | Chạy dọc đường (theo D1–D6), giữa làn, tới-lui; lật/xoay hình theo hướng đi |
| `person_01/02` | Đi bộ dọc vỉa hè (lệch tâm đường), lặp |
| `tree_01/02` | Đung đưa nhẹ (xoay ±2° quanh gốc thân) |

Lớp động vẽ rời nên app có thể đặt/animate độc lập trên nền; nhớ tắt bằng
`AnimationGate` trong test (theo quy tắc đã có từ PR #22).
