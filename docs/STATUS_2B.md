# Ghi chú cho giai đoạn 2b — PR (1) Phòng (code + manifest + mở PR)

## Quy tắc bóng đổ (quan trọng)

- **PNG đồ rời KHÔNG còn bóng trong ảnh** (giai đoạn 2a đã xóa sạch vệt bóng
  màu loang + mép răng cưa; alpha quanh món đồ sạch). Vì vậy **code Phòng
  phải tự vẽ bóng đổ mềm dưới mỗi món đồ khi đặt vào phòng**: một ellipse mờ,
  màu đen 20% (`Colors.black.withOpacity(0.20)`), đặt ngay dưới mép đáy của
  món đồ, rộng khoảng 80–90% bề ngang món đồ, cao khoảng 8–12% bề ngang.
  Không dùng bóng nướng sẵn trong PNG nữa.
- Bóng vẽ bằng app thì đồng bộ với mọi món đồ, không loang màu nền, và tắt
  được khi cần (ví dụ khi món đồ đang được kéo/di chuyển).

## Quy tắc alpha sạch — áp dụng tiếp cho nhân vật và pet

- Nhân vật (PR 3) và pet (PR 4) cũng phải cắt với alpha sạch như 8 món đồ
  này: không nướng bóng/vệt màu vào PNG, app tự vẽ bóng đổ mềm dưới chân.
- Bài học từ giai đoạn 2a: vệt bóng và phần shading dưới của món đồ cùng
  tông màu, nối nhau bằng gradient mượt — **không có ngưỡng màu hay step
  nào tách được sạch mà không ăn vào món đồ** (đã thử 5 biến thể flood-fill/
  trim). Cách làm được là cắt theo **đường chân thủ công** (ground line)
  đọc bằng mắt trên lưới tọa độ, rồi làm mềm viền 1–1,2 px. Áp dụng tương
  tự khi cắt nhân vật/pet sau này; xem script
  `~/workspace/timokid-review/a1-phong-v2/work/cut9.py`.

## Khung + mốc của 8 PNG đồ rời (đã decode lần 2, chờ giai đoạn 2b)

- Tất cả PNG trong suốt 512x512. Mép đáy của món đồ (ground line) là mốc
  đặt đồ xuống sàn phòng — app neo món đồ theo mép đáy, rồi vẽ bóng ellipse
  ngay dưới mốc đó.
- Vị trí đáy trong ảnh 512x512 (đo từ bản cuối, tính theo hàng pixel mờ
  cuối cùng): gối ~429, cốc ~391, bình hoa ~429, chậu cây ~421, khung ảnh
  ~423, gấu bông ~434, đèn sao ~480, dây cờ ~360 (dây cờ treo, không đặt sàn).
  Con số chỉ để tham khảo khi căn vị trí; mốc chính xác lấy theo mép đáy
  thực của từng ảnh khi code.

## Việc còn lại của giai đoạn 2b

1. Chờ Claude decode lần 2 (8 file `.b64` mới) + commit PNG lên nhánh
   `task/A1-phong-v2`, xóa `.b64`.
2. Code Phòng dùng nền `room_v2.png` + 8 PNG đồ rời (thay SVG tạm của T2-04),
   vẽ bóng ellipse đen 20% dưới mỗi món như mục trên.
3. Cập nhật `docs/ASSETS.md` (nền `room_v2.png` PNG thay vì JPEG; 8 món đồ
   nguồn "Muse vẽ AI 20/11 theo DESIGN.md", alpha sạch, bóng do app vẽ)
   + `assets/manifest.json` (8 mục đồ rời → `ready`).
4. Chạy đủ test (kể cả overflow 608x248 / 640x320), cập nhật
   `docs/HANDOVER.md`, mở PR (1) rồi báo số PR.
