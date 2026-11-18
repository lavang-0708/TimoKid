#!/usr/bin/env python3
"""Giải mã ảnh Muse đẩy dạng base64 thành PNG thật.

Muse không đẩy được file nhị phân qua MCP, nên mỗi ảnh được đẩy thành
file text ``app/assets/_incoming/<đường dẫn đích>.b64`` (nội dung là một
chuỗi base64 của PNG). Script này ghi PNG ra đúng ``<đường dẫn đích>``
(tính từ gốc repo), kiểm tra đúng là PNG, rồi xóa file .b64.

Cách dùng (Claude chạy trên nhánh PR, rồi commit):
    python3 tools/assets/decode_incoming.py
"""
import base64
import pathlib
import sys

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
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        f.unlink()
        print(f"OK {target.relative_to(ROOT)} ({len(data)} byte)")
    for d in sorted(INCOMING.rglob("*"), reverse=True):
        if d.is_dir() and not any(d.iterdir()):
            d.rmdir()
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
