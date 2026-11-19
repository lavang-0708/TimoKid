# Tấm phác ý tưởng (concept sheets)

Các tấm này vẽ bằng công cụ AI. **Từ 18/11/2026 chủ dự án chốt: đây là nguồn hình chính của app**, không còn chỉ để tham khảo.

Cách dùng:

1. **Ưu tiên lấy từ các tấm này**: tách nền cho trong suốt, cắt từng món ra file riêng, đưa về đúng khung trong `assets/templates/` (nhân vật 1024 x 1536, pet và đồ vật theo `khung_pet_do_vat.svg`).
2. **Sửa theo bảng lỗi bên dưới** khi cắt: bỏ nhãn và tên sẵn, đổi tên pet đúng, bỏ chữ trên tường, tách lớp tóc và áo cho đủ.
3. **Thiếu hình hoặc hình lỗi không sửa được thì Muse vẽ bổ sung** theo đúng phong cách của các tấm này. Ví dụ: icon app, nền Thị trấn, biểu tượng nút, hiệu ứng khi đúng, phần thú cưng thiếu.
4. Tông chuẩn là **pastel mềm, viền trắng kiểu sticker** (theo `girl_character_sheet.png`, `pet_*.png`, `room.png`). Hai tấm màu đậm (`boy_character_sheet.png`, `chibi_board_vivid.png`) phải chỉnh màu về pastel khi dùng.
5. Các tấm xám (`*_gray.png`) minh họa cách tách lớp và tô xám để app đổi màu.

Hình sau khi cắt và sửa để ở `app/assets/images/`. File PNG do Muse làm thì gửi qua chat, Claude commit bằng git; hình vẽ mới ưu tiên SVG để Muse tự đẩy được.

## Lỗi đã biết trong các tấm, không làm theo

| File | Lỗi |
| --- | --- |
| pet_evolution.png | Nhãn "Trứng Thỏ Hà Lan" đặt trên cả chó và mèo; bên thỏ lặp nhãn "Sơ sinh"; biểu tượng trứng đặt lệch; tên giống cũ (Shiba, Mèo Anh lông dài, Thỏ Hà Lan). Tên đúng: Chó Tinh Anh, Mèo Mũm Mĩm, Thỏ Bánh Bao |
| pet_eggs.png | Tên trứng theo giống cũ |
| girl_character_sheet.png | Ô "Kiểu miệng" vẽ mắt; ô "Kiểu mắt" lẫn tim, sao, vòng tròn; phần thú cưng chỉ có mèo |
| boy_character_sheet.png | Ô "Kiểu miệng" vẽ mắt; thú cưng là cáo/sói xanh, không thuộc 3 loài đã chọn; màu đậm, lệch tông |
| eyes_mouths_gray.png | Nhãn mang tên nhân vật (Kai, Luna, Leo, Nia) phải bỏ; nhãn `_line` đặt cạnh mảng giống miệng; miệng nữ không có nhãn |
| hairstyles_gray.png | Nhãn `_front_bangs`, `_back_hair` lệch hình; `_front_fringe` chỉ vào một lọn tóc |
| girl_outfits_gray.png | Mỗi bộ đồ vẽ liền thân và tóc bob; mũ phù thủy, cây dù đè sang ô bên |
| boy_outfits_gray.png | Hàng trên vẽ liền thân và tóc; hàng dưới tách chưa đủ (áo hoodie mất tay) |
| chibi_board_vivid.png | 6 nhân vật đặt tên sẵn (Kai, Mimi, Leo, Luna, Ben, Nia) phải bỏ vì bé tự đặt tên; màu đậm, lệch tông |
| room.png | Dòng chữ "Phòng của Kai & Mimi" phải bỏ; lịch treo tường chữ và số lộn xộn; nội thất vẽ liền nền |
