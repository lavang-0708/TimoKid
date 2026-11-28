"""Sinh icon Android của TimoKid từ 2 lớp gốc 1024x1024 (lô 16 của Muse).

Dùng: python3 tools/assets/make_app_icon.py <fg.png> <bg.png>
- Chép 2 lớp gốc vào assets/icon/ (lưu trữ, không đóng gói vào app).
- Adaptive icon (API 26+): mipmap-*/ic_launcher_foreground.png và
  ic_launcher_background.png (108 dp mỗi mật độ).
- Icon cũ (API < 26): mipmap-*/ic_launcher.png (bo góc) và
  ic_launcher_round.png (tròn), cắt vùng hiển thị 72/108 như launcher.
"""
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / 'app/android/app/src/main/res'
DENS = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def mask(size: int, round_: bool) -> Image.Image:
    m = Image.new('L', (size * 4, size * 4))
    d = ImageDraw.Draw(m)
    if round_:
        d.ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    else:
        d.rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=int(size * 4 * 0.2), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def main(fg_path: str, bg_path: str) -> None:
    fg = Image.open(fg_path).convert('RGBA')
    bg = Image.open(bg_path).convert('RGBA')
    assert fg.size == bg.size == (1024, 1024), (fg.size, bg.size)
    keep = ROOT / 'assets/icon'
    keep.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(fg_path, keep / 'app_icon_fg.png')
    shutil.copyfile(bg_path, keep / 'app_icon_bg.png')
    full = bg.copy()
    full.alpha_composite(fg)
    c = round(1024 * 18 / 108)
    visible = full.crop((c, c, 1024 - c, 1024 - c))
    for name, k in DENS.items():
        out = RES / f'mipmap-{name}'
        out.mkdir(parents=True, exist_ok=True)
        layer = round(108 * k)
        fg.resize((layer, layer), Image.LANCZOS).save(out / 'ic_launcher_foreground.png', optimize=True)
        bg.convert('RGB').resize((layer, layer), Image.LANCZOS).save(out / 'ic_launcher_background.png', optimize=True)
        legacy = round(48 * k)
        icon = visible.resize((legacy, legacy), Image.LANCZOS)
        for fname, rnd in (('ic_launcher.png', False), ('ic_launcher_round.png', True)):
            o = Image.new('RGBA', (legacy, legacy), (0, 0, 0, 0))
            o.paste(icon, (0, 0), mask(legacy, rnd))
            o.save(out / fname, optimize=True)
    # Ảnh 512 cho cửa hàng/README.
    visible.resize((512, 512), Image.LANCZOS).convert('RGB').save(keep / 'app_icon_512.png', optimize=True)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
