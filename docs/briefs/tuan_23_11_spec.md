# Đặc tả việc tuần 23/11/2026 (chủ dự án chốt 23/11 ~22:32)

Hai hướng: **(2) tiến bộ dài hạn** và **(3) gắn pet với việc học**, cộng phần pet
còn lại (ăn mừng lớn, chọn pet tiếp, pet mới mua bằng kim cương).
Mọi con số ở đây đặt trong file config của từng tính năng (một chỗ duy nhất),
để chủ dự án chỉnh sau.

Giữ nguyên các luật cũ: không hộp quà may rủi, không mua bằng tiền thật,
ngày tính theo giờ Việt Nam, "đúng" = đúng ngay lần đầu, số dư không âm.

## A. Tháp nhiều tầng + boss (PR riêng)

- Mỗi tòa nhà (5 mảng) có **30 tầng**. Chặng ngày giữ nguyên như cũ (đề ngày
  vẫn là việc chính mỗi ngày). Sau khi xong chặng ngày của tòa đó, nút
  "Thử thách" (chặng tự chọn) đổi thành **"Leo tầng N"**.
- Tầng n gồm 5 câu của mảng đó, bậc = `min(6, 1 + (n-1) ~/ 5)`
  (tầng 1–5 bậc 1, 6–10 bậc 2, …, 26–30 bậc 6). Kiểu trả lời theo bậc như
  thang ải.
- **Tầng boss** = tầng chia hết cho 5: bậc +1 (tối đa 6), cần đúng **4/5**;
  tầng thường cần **3/5**. Trượt thì thử lại ngay được, câu mới.
- Thưởng chỉ ở **lần qua đầu tiên** mỗi tầng: tầng thường 10 xu, tầng boss
  1 kim cương + 20 xu; tầng 30 (đỉnh) 3 kim cương. Xu từng câu vẫn tính như cũ.
- Màn Tòa nhà hiện cột tầng (tầng đã qua / tầng hiện tại / tầng khóa,
  tầng boss có huy hiệu). Ảnh `ui_tower_lock`, `ui_tower_boss` chưa có →
  dùng icon Material tạm, cờ `towerArtReady = false`.
- Lưu tầng cao nhất đã qua trong `settings` theo bé: `tower_floor.<strand>`.
- Câu làm ở tháp vẫn ghi vào bảng câu trả lời như chặng tự chọn (thang ải,
  sổ ôn tập vẫn chạy).

## B. Hạng đấu trường theo tuần (PR riêng)

- Tuần = thứ Hai 00:00 → Chủ nhật 23:59 giờ Việt Nam.
- **Điểm tuần** = tổng số câu đúng của các lần thi đấu trường trong tuần
  (mỗi ngày vẫn 1 lần, tối đa 25/ngày).
- Hạng: Đồng (đã thi ≥1 lần), Bạc ≥ 40, Vàng ≥ 80, Kim cương ≥ 120.
- Sảnh đấu trường hiện huy hiệu hạng hiện tại, thanh tiến độ tới hạng sau,
  số ngày còn lại trong tuần.
- **Rương cuối tuần**: lần đầu bé mở app sau khi tuần kết thúc, nếu tuần
  trước có thi thì hiện rương theo hạng tuần trước để bé bấm mở:
  Đồng 2, Bạc 4, Vàng 7, Kim cương 12 kim cương. Chỉ nhận một lần mỗi
  tuần (khóa `settings` `arena_week_claimed.<yyyy-mm-dd thứ Hai>`).
  Nội dung rương cố định theo hạng (không may rủi).
- Ảnh `ui_league_*`, `ui_chest_*` chưa có → icon tạm, cờ `leagueArtReady`.

## C. Nhiệm vụ ngày + chuỗi ngày (PR riêng, làm SAU A, B, D)

- Mỗi ngày 3 nhiệm vụ chọn từ kho, cố định theo (bé, ngày) bằng seed, không
  trùng loại. Kho gợi ý: đúng 5 câu mảng X; xong chặng ngày của tòa X; leo
  qua 1 tầng tháp; làm đấu trường hôm nay; xong đề ngày; làm lại đúng 2 câu
  trong sổ ôn tập; cho pet ăn; chơi với pet.
- Mỗi nhiệm vụ xong: bé bấm nhận 10 xu. Xong cả 3: thêm 1 kim cương.
- **Chuỗi ngày** = số ngày liên tiếp xong đủ 3 nhiệm vụ. Ngày thứ 7, 14, 21…
  của chuỗi: rương chuỗi 5 kim cương. Lỡ một ngày thì chuỗi về 0.
- Bảng nhiệm vụ mở từ nút trên HUD Thị trấn và Phòng (có chấm đỏ khi có
  quà chưa nhận). Ảnh `ui_quest_*`, `ui_streak_*` chưa có → icon tạm.

## D. Pet: chăm sóc, lớn theo câu đúng, ăn mừng, nhiều pet (PR riêng)

Chủ dự án chốt 23/11: pet có đói/buồn theo ngày (thay quyết định cũ ở
PLAN T2-07 "không có trạng thái đói, ốm, buồn"). Làm nhẹ nhàng: không ốm,
không chết, không mất pet, không trừ gì cả.

- **Bảng `pets`** (DB v4, migration): id, child_id, species, xp (số câu đúng
  ngay lần đầu tích lũy khi pet đi theo), stage_seen, created_at, hatched
  (bool), active (đúng 1 pet active mỗi bé). Migration chuyển pet hiện có
  (từ `selected_egg`/`egg_hatched`) sang bảng, xp khởi điểm = số ngày xong
  đề × 20 để bé không bị tụt giai đoạn.
- **Lớn theo câu đúng**: câu đúng ngay lần đầu ở bất kỳ đâu (đề ngày, tháp,
  đấu trường) cộng 1 xp cho pet đang đi theo. Mới nở 0, tuổi nhỡ ≥ 80,
  trưởng thành ≥ 250.
- **Màn ăn mừng lớn lên**: khi vào Phòng mà giai đoạn > stage_seen: lớp phủ
  toàn màn, pháo giấy, pet cũ phóng to thành pet mới, chữ "<tên> đã lớn
  thành <giai đoạn>!", nút Tuyệt vời. Ảnh `ui_celebrate_burst` chưa có →
  vẽ pháo giấy bằng code.
- **Đói / buồn theo ngày**: mỗi ngày pet cần 1 lần ăn và 1 lần chơi.
  Chưa ăn → bong bóng đói; đã ăn mà chưa chơi → bong bóng buồn; đủ cả hai →
  vui (bong bóng tim, nhảy happy). Chỉ ảnh hưởng hình, không trừ xp.
- **Suất ăn nhận khi học**: xong mỗi chặng (chặng ngày, tầng tháp, đấu
  trường) được 1 "suất ăn" (`ui_pet_meal`, cộng vào kho thức ăn hiện có
  dạng món miễn phí `meal`). Cho ăn dùng suất ăn hoặc thức ăn mua bằng xu.
  Chơi dùng đồ chơi đã mua hoặc nút "vuốt ve" luôn có (vuốt ve chỉ được tính
  sau khi bé đã xong ít nhất 1 chặng hôm nay — "học xong mới chơi").
- **Pet đủ lớn → chọn pet tiếp**: khi pet trưởng thành, Phòng hiện "Nhận
  trứng mới": bé chọn 1 trong các loài khởi đầu (chó/mèo/thỏ) chưa có.
  Trứng nở theo luồng nở cũ (xong 1 chặng → màn nở dần).
- **Pet mua bằng kim cương** (thẻ "Pet" trong Cửa hàng): sóc (squirrel,
  thường) 20 💎, capybara (hiếm) 60 💎, rồng con (dragon, siêu hiếm) 150 💎.
  Mua được trứng, nở như trên. Thẻ ghi độ hiếm. Ảnh chưa có (Muse đang vẽ
  lô 12) → cờ theo loài `newPetArtReady = {squirrel:false, capybara:false,
  dragon:false}`; loài chưa có ảnh hiện "Sắp có", không mua được.
- **Chọn pet đi theo**: Phòng có nút "Pet của bé" mở danh sách pet đã có,
  bấm để đổi pet đi theo. Mỗi lúc chỉ 1 pet đi theo.
- Ảnh `ui_emote_*`, `ui_pet_meal` chưa có → icon/emoji vẽ code, cờ
  `petUiArtReady`.

## Ảnh Muse (lô 12, 13) — xem docs/E_IMAGES.md khi về

- Lô 12: `squirrel_*`, `capybara_*`, `dragon_*`, mỗi loài 27 file như mèo.
- Lô 13: `ui_emote_hungry|sad|happy`, `ui_pet_meal`, `ui_league_*`,
  `ui_chest_*`, `ui_quest_board`, `ui_quest_check`, `ui_streak_flame`,
  `ui_streak_chest`, `ui_tower_lock`, `ui_tower_boss`, `ui_celebrate_burst`.
