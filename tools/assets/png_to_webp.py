#!/usr/bin/env python3
"""Đổi mọi PNG trong app/assets/images/ sang WebP lossless (giảm dung lượng APK).

Mỗi file được giải mã lại và so với PNG gốc (RGBA, bỏ RGB của pixel
alpha == 0) — lệch dù một pixel là dừng, không xóa gì. Chỉ khi mọi file
đều khớp mới ``git rm`` các PNG.

Dùng:
    python3 tools/assets/png_to_webp.py            # chuyển cả thư mục
    python3 tools/assets/png_to_webp.py --keep     # giữ PNG, không git rm
Hàm ``convert_png_to_webp`` được ``decode_incoming.py`` dùng lại.
"""
import argparse
import multiprocessing
import pathlib
import subprocess
import sys

from PIL import Image, ImageChops

ROOT = pathlib.Path(__file__).resolve().parents[2]
IMAGES = ROOT / "app" / "assets" / "images"


def _normalized(img: Image.Image) -> Image.Image:
    """RGBA với RGB = 0 ở pixel trong suốt hoàn toàn."""
    rgba = img.convert("RGBA")
    zero = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    mask = rgba.getchannel("A").point(lambda a: 255 if a == 0 else 0)
    return Image.composite(zero, rgba, mask)


def convert_png_to_webp(src: pathlib.Path, dst: pathlib.Path | None = None,
                        verify: bool = True) -> pathlib.Path:
    """Chuyển một PNG sang WebP lossless và kiểm giống hệt. Trả đường dẫn WebP."""
    src = pathlib.Path(src)
    dst = pathlib.Path(dst) if dst else src.with_suffix(".webp")
    with Image.open(src) as im:
        im.load()
        im.save(dst, "WEBP", lossless=True, quality=100, method=6)
        if verify:
            with Image.open(dst) as out:
                out.load()
                if im.size != out.size:
                    raise ValueError(f"{src}: sai kích thước sau khi chuyển")
                diff = ImageChops.difference(_normalized(im), _normalized(out))
                if diff.getbbox() is not None:
                    raise ValueError(f"{src}: WebP khác PNG gốc ở {diff.getbbox()}")
    return dst


def _job(path: str):
    p = pathlib.Path(path)
    try:
        out = convert_png_to_webp(p)
        return path, p.stat().st_size, out.stat().st_size, None
    except Exception as exc:  # noqa: BLE001
        return path, 0, 0, str(exc)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep", action="store_true", help="không xóa PNG")
    args = ap.parse_args()
    pngs = sorted(str(p) for p in IMAGES.rglob("*.png"))
    print(f"{len(pngs)} file PNG")
    before = after = 0
    errors = []
    with multiprocessing.Pool() as pool:
        for i, (path, b, a, err) in enumerate(
                pool.imap_unordered(_job, pngs), 1):
            if err:
                errors.append(err)
                print("LỖI", err, flush=True)
                continue
            before += b
            after += a
            if i % 50 == 0:
                print(f"  {i}/{len(pngs)}", flush=True)
    if errors:
        print(f"ĐÃ DỪNG: {len(errors)} file lệch, không xóa PNG nào")
        return 1
    print(f"Trước {before/1e6:.1f} MB -> sau {after/1e6:.1f} MB")
    if not args.keep:
        for i in range(0, len(pngs), 200):
            subprocess.run(["git", "rm", "-q", "--", *pngs[i:i + 200]],
                           cwd=ROOT, check=True)
        print("Đã git rm", len(pngs), "PNG")
    return 0


if __name__ == "__main__":
    sys.exit(main())
