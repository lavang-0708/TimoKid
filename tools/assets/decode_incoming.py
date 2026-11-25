#!/usr/bin/env python3
"""Giải mã ảnh Muse đẩy dạng base64 thành WebP lossless thật.

Muse không đẩy được file nhị phân qua MCP, nên mỗi ảnh được đẩy thành
file text ``app/assets/_incoming/<đường dẫn đích>.b64`` (nội dung là một
chuỗi base64 của PNG). Script này giải mã, kiểm tra đúng là PNG, đổi
sang WebP lossless (cùng đường dẫn, đuôi ``.webp``; có kiểm giống hệt
từng pixel, xem ``png_to_webp.py``), rồi xóa file .b64.

Cách dùng (Claude chạy trên nhánh PR, rồi commit):
    python3 tools/assets/decode_incoming.py
"""
import base64
import pathlib
import sys
import tempfile

from png_to_webp import convert_png_to_webp

ROOT = pathlib.Path(__file__).resolve().parents[2]
INCOMING = ROOT / "app" / "assets" / "_incoming"
PNG_SIG = b"\x89PNG\r\n\x1a\n"


def main() -> int:
    files = sorted(INCOMING.rglob("*.b64")) if INCOMING.exists() else []
    if not files:
        print("Không có file .b64 nào trong", INCOMING.relative_to(ROOT))
        return 0
    bad = 0
    for f in files:
        target = ROOT / f.relative_to(INCOMING).with_suffix("")
        data = base64.b64decode("".join(f.read_text().split()), validate=True)
        if not data.startswith(PNG_SIG):
            print("LỖI không phải PNG:", f.relative_to(ROOT))
            bad += 1
            continue
        target = target.with_suffix(".webp")
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as tmp:
            src = pathlib.Path(tmp) / "decoded.png"
            src.write_bytes(data)
            try:
                convert_png_to_webp(src, target)
            except Exception as exc:  # noqa: BLE001
                print("LỖI không đổi được sang WebP:", f.relative_to(ROOT), exc)
                target.unlink(missing_ok=True)
                bad += 1
                continue
        f.unlink()
        print(f"OK {target.relative_to(ROOT)} ({len(data)} byte PNG -> "
              f"{target.stat().st_size} byte WebP)")
    for d in sorted(INCOMING.rglob("*"), reverse=True):
        if d.is_dir() and not any(d.iterdir()):
            d.rmdir()
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
