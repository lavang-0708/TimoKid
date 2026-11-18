# Âm thanh

Claude tự tổng hợp bằng Python (sóng sin có hòa âm và đường bao tắt dần), không lấy từ nguồn ngoài nên không vướng bản quyền. WAV mono 44,1 kHz.

| File | Dùng khi | Mô tả |
| --- | --- | --- |
| `correct.wav` | Trả lời đúng | Tiếng "ting" chuông 2 nốt đi lên |
| `wrong.wav` | Trả lời sai | Tiếng "è" nhẹ, 2 nốt trầm đi xuống. Cố ý mềm vì sai không bị phạt (DESIGN nguyên tắc 3) |
| `coin.wav` | Xu bay vào ví | 2 nốt cao nhanh |
| `stage_complete.wav` | Xong chặng | Hợp âm rải 4 nốt |

Tôn trọng cài đặt `sound_enabled` trong `settings`. Muốn thay âm khác thì giữ nguyên tên file.
