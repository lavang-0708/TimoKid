# Hình A1 Phòng (phong cách v2) — giai đoạn 1: chỉ đẩy hình, chưa có code

Nhánh `task/A1-phong-v2`, từ main `adf4e02` (PR #23 T2-04 đã merge).
Đẩy 9 ảnh dưới dạng base64 để Claude giải mã bằng
`python3 tools/assets/decode_incoming.py` rồi commit hình lên đúng nhánh,
sau đó mới làm giai đoạn 2 (code + manifest + mở PR).

## Lưu ý định dạng nền

- Nền phòng đẩy dạng **PNG** (`room_v2.png`), KHÔNG phải JPEG như `docs/ASSETS.md`
  ghi cho loại `background`. Lý do: `tools/assets/decode_incoming.py` trên main
  chỉ chấp nhận PNG (kiểm tra signature PNG, báo lỗi với file khác).
- PNG 1600x900 này chỉ 928.630 byte (< 1 MB) nên đẩy PNG là được, không cần
  đổi script. Giai đoạn 2 sẽ cập nhật `docs/ASSETS.md` + manifest cho đúng
  (nền `room_v2.png`, khung 1600x900).

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
