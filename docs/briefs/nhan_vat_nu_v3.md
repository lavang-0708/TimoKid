# Giao việc cho Muse: nhân vật nữ bản 3 (vẽ lại theo khuôn)

> **Đã thay thế (19/11):** Muse vẽ lại chưa đạt, chủ dự án chọn bộ Claude cắt từ tấm concept. Xem `docs/ASSETS.md` mục "Bộ nhân vật nữ 1".

Chủ dự án đã chốt hướng này ngày 19/11. Claude giao, Muse vẽ.

## Mục tiêu

Vẽ lại cô bé chính trên tấm concept `assets/concept/nho/girl_character_sheet.jpg` thành các lớp rời để thay đồ được.

- **Phong cách** lấy y hệt cô bé trên tấm concept: mặt, mắt to long lanh, má hồng, nét viền nâu mảnh, tô bóng mềm, tóc dài xoăn buộc hai bên. Xem `assets/concept/tham_chieu/girl_muc_tieu_phong_cach.png` (Claude cắt nguyên từ tấm). Đây là đích cần đạt.
- **Tư thế, tỉ lệ và vị trí** lấy y hệt khuôn `assets/templates/girl_base_v3_template.png`:
  - đứng thẳng, nhìn thẳng, tay hơi dang ra hai bên;
  - mặc đồ lót đơn giản (áo ba lỗ, quần đùi);
  - mặt có ô đánh dấu chỗ mắt và miệng.
  - Khuôn đã đặt đúng khung 1024 x 1536.
- File `assets/concept/tham_chieu/girl_base_v3_color_mau.png` là bản Claude tô thử trên khuôn. Muse chỉ xem để biết các lớp chồng lên nhau ra sao. **Không** lấy phong cách từ file này: nó phẳng và đơn giản hơn concept.
- File `so_sanh_concept_va_nu_goc2.jpg` cho thấy vấn đề cần tránh.
  - Hàng trên đẹp, nhưng đồ dính liền vào người nên thay váy bị lộ đồ cũ.
  - Hàng dưới thay đồ khít, nhưng xấu hơn concept.
  - Bản 3 phải vừa đẹp như hàng trên, vừa khít như hàng dưới.

## Mốc trong khung 1024 x 1536 (đo từ khuôn)

Mốc dưới đây thay cho mốc cũ của khung nữ trong `docs/ASSETS.md`.

| Mốc | Giá trị |
| --- | --- |
| Đỉnh đầu | y ≈ 200 |
| Tâm mắt trái / phải | (441, 457) / (584, 457) |
| Tâm miệng | (513, 518) |
| Cổ / vai | y ≈ 595 / 616 |
| Mặt đất (gót chân) | y = 1400 |
| Tâm ngang | x = 512 |

Mọi lớp phải chồng khít lên khuôn. Đặt lớp lên khuôn (bật 50% trong suốt) mà lệch quá 3 px là phải sửa.

## Hợp đồng file (giữ nguyên `docs/ASSETS.md`)

- Mỗi lớp là một PNG trong suốt 1024 x 1536, chỉ chứa phần của lớp đó, đặt đúng chỗ.
- **Lớp đổi màu (da, tóc, tròng mắt):**
  - tô xám, R, G, B lệch nhau không quá 8;
  - nét viền và chi tiết cố định để ở file `_line`.
- **Quần áo, giày:** để màu thật như concept, `recolorable: false`. Không cần file `_line`.
- **Váy liền** xếp vào lớp `top`, lớp `bottom` để trống.
- **Không được lộ đồ lót.**
  - Váy phải che kín áo ba lỗ của thân, kể cả chỗ nách và vai. Lấy khuôn để kiểm.
  - Váy phải che kín quần đùi.
- **Tóc tách hai lớp:**
  - `hair_back` gồm phần tóc sau lưng và đuôi tóc;
  - `hair_front` gồm mái, hai bên má và nơ cột tóc nếu nơ dính vào tóc.
  - Tóc trước không được che mắt.
- **Thân `body`:**
  - da, tai và đồ lót;
  - không có mắt, không có miệng, không có tóc;
  - mặt để trơn, chỉ có má hồng nhạt nếu được (hoặc để má hồng ở lớp mắt).

## Lô 1 (làm trước, gửi để Claude duyệt rồi mới làm tiếp)

| id trong manifest | Nội dung |
| --- | --- |
| `girl_body_01` + `_line` | Thân xám, đồ lót, theo khuôn, vẽ theo phong cách concept |
| `girl_hair_back_01`, `girl_hair_front_01` | Tóc dài xoăn buộc hai bên như cô bé concept (bộ `girl_hair_01`), xám |
| `girl_eyes_01` + `_line` | Mắt to long lanh như concept; tròng mắt xám, mi và ánh sáng ở `_line` |
| `girl_mouth_01` + `_line` | Miệng cười nhỏ |
| `girl_top_01` | Váy hồng (lấy mẫu váy hồng trên tấm concept), vẽ lại cho vừa thân |
| `girl_top_02` | Váy tím (mẫu váy tím trên `girl_outfits_gray.jpg` hoặc tấm concept), vẽ lại cho vừa thân |
| `girl_shoes_01` | Giày hồng có nơ kèm tất trắng như concept |

**Gửi kèm:** một ảnh ghép 3 hình gồm thân + tóc + mắt + miệng mặc đồ lót, mặc váy hồng, mặc váy tím. Đặt cạnh `girl_muc_tieu_phong_cach.webp` để so.

**Chỉ gửi ảnh ghép xem trước.** Ảnh ghép được duyệt thì mới gửi các lớp lên repo. Claude chưa duyệt thì chưa gửi lớp.

## Cách gửi

- Ảnh xem trước gửi ngay trong chat.
- Khi gửi lớp:
  - đẩy dạng `.b64` vào `app/assets/_incoming/` như lần trước, đặt tên trùng `id`;
  - Claude chạy `tools/assets/decode_incoming.py`;
  - sau đó Muse mở PR sửa `assets/manifest.json`: đổi `status` các mục trên sang `ready`, điền `source: "vẽ mới theo girl_character_sheet + girl_base_v3_template"`.
