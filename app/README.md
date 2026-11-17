# TimoKid — app Flutter

App Android giúp bé lớp 2 ôn thi Olympic Toán TIMO. Chỉ build Android, chạy màn hình ngang, chạy offline ở bản 0.1 và 0.2.

- Package Android: `vn.timokid.app`, tên hiển thị: TimoKid.
- Thiết kế tổng: `../docs/DESIGN.md`. Kế hoạch: `../docs/PLAN.md`.

## Chạy test

```sh
flutter analyze
flutter test
```

## Cấu trúc `lib/`

- `lib/core/` — theme, router, database, tiện ích chung.
- `lib/features/` — mỗi tính năng một thư mục (`town`, `math`, `stage_result`, ...).
