# Menu QA ẩn (T1-13)

Menu kiểm tra dành cho Claude (người kiểm tra), không phải màn cho bé.
Mở bằng cách **nhấn giữ 5 giây vào góc trên-trái màn hình** — giữ đến khi
vòng tiến độ nhỏ trong góc chạy hết thì menu mở. Buông tay trước 5 giây
thì không mở.

## Cách bật

| Bản build | Cách bật |
| --- | --- |
| Debug (`flutter run`, APK debug) | Luôn bật sẵn |
| Release | Build kèm `--dart-define=QA_MENU=true` |
| Release không có cờ | Không có menu (cả vùng nhấn giữ cũng không tồn tại) |

## Chức năng

- **Ngày QA** — "Sang ngày mai (+1 ngày)" nhảy sang ngày hôm sau (theo
  giờ app), "Về hôm nay" quay lại ngày thật. Nhảy ngày chỉ lệch trong
  bộ nhớ: tắt/mở lại app là về ngày thật. Dùng để kiểm tra T1-08 (mở
  Thị trấn ở ngày mới thì có đề mới) và T1-10 (mục ôn tập đến hạn thì
  hiện trong đề ngày).
- **Bậc từng mảng** — đặt bậc 1–6 cho từng mảng. Đặt bậc thì cửa sổ
  10 câu tính lại từ đầu (luật của `SkillProgressDao`).
- **Sổ ôn tập** — toàn bộ mục trong sổ: dạng bài, bậc, chuỗi đúng
  (n/3), ngày hỏi lại, mục nào đã đến hạn.
- **20 lượt trả lời gần nhất** — mới nhất trước: dạng bài, mức, bậc,
  đúng ngay hay chưa, có phải câu ôn tập không, giờ làm.
- **Xem thử dạng bài** — chọn 1 trong 84 dạng + mức nó hỗ trợ, bấm
  "Sinh câu" để xem đề song ngữ, hình (nếu có), đáp án đúng, gợi ý và
  lời giải. Chỉ sinh để xem: không ghi lượt trả lời, không động vào
  bậc/thành thạo/sổ ôn tập. "Câu khác" sinh câu mới cùng dạng/mức.
- **Giả lập mùa** (T5-02) — ép một mùa (Tết, Trung thu, Giáng sinh) hoặc
  "Theo ngày thật". Ép mùa chỉ trong bộ nhớ (tắt app là hết): Thị trấn
  hiện biển mùa, Cửa hàng có tab "Bộ sưu tập mùa" + ruy băng + giảm giá
  20% món thuộc mùa, đề ngày được +50% xu. Về Thị trấn/Cửa hàng để thấy.
- **Xóa dữ liệu** — xóa toàn bộ dữ liệu của bé (lượt trả lời, bậc,
  sổ ôn tập, đề ngày, xu/kim cương) về trạng thái mới cài, rồi về màn
  Thị trấn. Có hộp thoại xác nhận; không khôi phục được.

## Ghi chú kỹ thuật

- Nhảy ngày đi qua `DebugClock` (`lib/features/qa/debug_clock.dart`)
  bọc đồng hồ thật của database — xem `docs/DECISIONS.md` (mục T1-13).
- Xóa dữ liệu DROP toàn bộ bảng rồi tạo lại (kể cả trigger append-only)
  vì trigger chặn DELETE trên `attempts`/`wallet_ledger`.
- Ảnh chụp màn menu ở `docs/screenshots-t1-13/` (chỉ lưu local, không
  đẩy lên GitHub).
