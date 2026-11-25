# Hình A2 Thị trấn (phong cách v2) — giai đoạn 1: chỉ đẩy hình, chưa có code

Nhánh `task/A2-thi-tran-v2`, từ main `adf4e02` (PR #23 T2-04 đã merge).
Đẩy 11 ảnh dưới dạng base64 để Claude giải mã bằng
`python3 tools/assets/decode_incoming.py` rồi commit hình lên đúng nhánh,
sau đó mới làm giai đoạn 2 (code + manifest + mở PR).

Ảnh gốc: thị trấn v2 composite isometric đã được chủ dự án duyệt
(6 công trình + cây/hoa/đèn/ghế/xe/người nhỏ/biển hiệu hình, nhà xa mờ dần,
mặt sáng/tối + bóng mềm, ánh sáng từ trên-trái). Lớp động vẽ rời bằng AI
cùng phong cách, tách nền magenta bằng chroma-key, xem bằng mắt trên nền
caro: cùng tông với nền, không lẫn nền, không cắt cụt.

## Lưu ý định dạng nền

- Nền thị trấn đẩy dạng **PNG** (`town_v2.webp`), KHÔNG phải JPEG như
  `docs/ASSETS.md` ghi cho loại `background`. Lý do: `tools/assets/decode_incoming.py`
  trên main chỉ chấp nhận PNG (kiểm tra signature PNG, báo lỗi với file khác).
- PNG 1600x900 đủ màu là 1.984.654 byte (> 1 MB) nên đã lượng tử hóa 256 màu
  + dithering Floyd-Steinberg: còn **581.584 byte** (< 1 MB), xem bằng mắt
  không thấy nhiễu dithering ở cỡ hiển thị, đủ 6 công trình, không cắt cụt.
- Giai đoạn 2 sẽ cập nhật `docs/ASSETS.md` + manifest cho đúng
  (nền `town_v2.webp`, khung 1600x900).

## Danh sách file

| File .b64 | Đường dẫn đích | Cỡ gốc (byte) | Khung | Mô tả |
| --- | --- | ---: | --- | --- |
| `app/assets/_incoming/app/assets/images/backgrounds/town_v2.png.b64` | `app/assets/images/backgrounds/town_v2.png` | 581584 | 1600x900 | Nền thị trấn v2 (isometric, 6 công trình) |
| `app/assets/_incoming/app/assets/images/town/cloud_01.png.b64` | `app/assets/images/town/cloud_01.png` | 126076 | 512x512 | Mây trắng tròn phồng |
| `app/assets/_incoming/app/assets/images/town/cloud_02.png.b64` | `app/assets/images/town/cloud_02.png` | 94987 | 512x512 | Mây trắng dẹt, đáy phẳng |
| `app/assets/_incoming/app/assets/images/town/cloud_03.png.b64` | `app/assets/images/town/cloud_03.png` | 146828 | 512x512 | Mây trắng tròn nhỏ |
| `app/assets/_incoming/app/assets/images/town/car_01.png.b64` | `app/assets/images/town/car_01.png` | 155671 | 512x512 | Xe hơi hồng |
| `app/assets/_incoming/app/assets/images/town/car_02.png.b64` | `app/assets/images/town/car_02.png` | 147708 | 512x512 | Xe hơi xanh nhạt |
| `app/assets/_incoming/app/assets/images/town/fountain.png.b64` | `app/assets/images/town/fountain.png` | 236877 | 512x512 | Đài phun nước đá, tia nước xanh |
| `app/assets/_incoming/app/assets/images/town/tree_01.png.b64` | `app/assets/images/town/tree_01.png` | 181096 | 512x512 | Cây xanh tán tròn |
| `app/assets/_incoming/app/assets/images/town/tree_02.png.b64` | `app/assets/images/town/tree_02.png` | 239911 | 512x512 | Cây hoa anh đào hồng |
| `app/assets/_incoming/app/assets/images/town/person_01.png.b64` | `app/assets/images/town/person_01.png` | 175530 | 512x512 | Bé gái mũ hồng, váy xanh |
| `app/assets/_incoming/app/assets/images/town/person_02.png.b64` | `app/assets/images/town/person_02.png` | 153976 | 512x512 | Bé trai mũ xanh, áo xanh lá |

Tất cả ảnh gốc đều <= 1 MB. Lớp động PNG trong suốt 512x512, nền 1600x900.

## Vị trí 6 công trình trong khung nền 1600x900 (đo bằng mắt, gần đúng)

Dùng cho giai đoạn 2 đặt vùng bấm. Tọa độ (x, y, w, h), gốc trên-trái.

| Công trình | Rect (x, y, w, h) | Ghi chú |
| --- | --- | --- |
| Trường học (xanh, chuông) | 585, 95, 360, 280 | Tòa nhà chính + tháp chuông |
| Tiệm bánh (vàng, biển bánh sừng bò) | 315, 320, 355, 245 | Kèm chậu hoa trước cửa |
| Tiệm quần áo (tím, mái sọc) | 660, 490, 330, 240 | Mái sọc hồng-trắng |
| Cửa hàng thú cưng (xanh lá, biển dấu chân) | 1260, 450, 290, 230 | Góc phải |
| Nhà hồng (Phòng) | 95, 545, 300, 225 | Góc trái dưới, có hàng rào trắng |
| Công viên (xích đu, cầu trượt) | 860, 300, 400, 280 | Khuôn viên có rào, cây anh đào + cây xanh. Bóng dáng đo được tới x = 1440 nhưng vùng bấm cắt ở x = 1260 (mép trái cửa hàng thú cưng) để không chồng vùng bấm thú cưng — tâm vùng thú cưng (1405, 565) nằm trong rect cũ nên tap chặng 2 rơi nhầm sang chặng 3 (bắt bằng test thị trấn, A2 giai đoạn 2). |

## Lớp động — cách chuyển động (giai đoạn 2, Flutter animation + AnimationGate)

| Lớp | Chuyển động |
| --- | --- |
| `cloud_01/02/03` | Trôi ngang qua bầu trời, chậm, mỗi mây tốc độ/hướng khác nhau, lặp |
| `car_01/02` | Chạy dọc đường (theo đường trong nền), lặp |
| `fountain` | Nước phun nhấp nhô (scale/opacity tia nước), lặp |
| `tree_01/02` | Đung đưa nhẹ (xoay ±2° quanh gốc thân) |
| `person_01/02` | Đi bộ dọc vỉa hè (dịch chuyển theo đường đi), lặp |

Lớp động vẽ rời nên app có thể đặt/animate độc lập trên nền; nhớ tắt bằng
`AnimationGate` trong test (theo quy tắc đã có từ PR #22).
