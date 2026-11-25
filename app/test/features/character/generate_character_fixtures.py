#!/usr/bin/env python3
"""Sinh fixture hình tạm cho T2-02 (CharacterView).

Mỗi lớp là một khối xám khác nhau, đúng khung hợp đồng 1024x1536,
đúng vị trí từng lớp theo mốc khung trong docs/ASSETS.md (tâm mắt
512±105/480, miệng 512/575, vai y=716, mặt đất y=1400). Màu xám
khác nhau theo lớp để golden test nhìn ra được thứ tự chồng và phép
nhân màu; file `_line` là nét đậm không đổi màu.

Chạy từ thư mục app/:  python3 test/features/character/generate_character_fixtures.py
Ghi ra test/features/character/character_fixtures.dart (base64).
Không đặt file PNG tạm vào app/assets/ (script check_assets.py sẽ
báo lỗi vì file không có trong manifest).
"""

import base64
import io
import os

from PIL import Image, ImageDraw

W, H = 1024, 1536
LINE = (58, 58, 58, 255)


def gray(v):
    return (v, v, v, 255)


def canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def rounded(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline,
                           width=width)


# --- Thân -----------------------------------------------------------------
def body():
    img, d = canvas(), None
    d = ImageDraw.Draw(img)
    d.ellipse([512 - 120, 430 - 120, 512 + 120, 430 + 120], fill=gray(217))
    d.rectangle([482, 540, 542, 720], fill=gray(217))
    rounded(d, [415, 700, 609, 1400], 60, fill=gray(217))
    return img


def body_line():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.ellipse([512 - 120, 430 - 120, 512 + 120, 430 + 120],
              outline=LINE, width=6)
    rounded(d, [415, 700, 609, 1400], 60, outline=LINE, width=6)
    return img


# --- Tóc ------------------------------------------------------------------
def hair_back(n):
    img = canvas()
    d = ImageDraw.Draw(img)
    boxes = {1: [380, 200, 644, 1000], 2: [360, 180, 664, 900],
             3: [400, 230, 624, 850]}
    rounded(d, boxes[n], 80, fill=gray(194))
    return img


def hair_front(n):
    img = canvas()
    d = ImageDraw.Draw(img)
    if n == 1:
        rounded(d, [380, 200, 644, 450], 60, fill=gray(194))
        rounded(d, [380, 200, 430, 700], 25, fill=gray(194))
        rounded(d, [594, 200, 644, 700], 25, fill=gray(194))
    elif n == 2:
        rounded(d, [370, 180, 654, 420], 60, fill=gray(194))
    else:
        rounded(d, [400, 230, 624, 470], 60, fill=gray(194))
        d.ellipse([350, 455, 440, 545], fill=gray(194))
        d.ellipse([584, 455, 674, 545], fill=gray(194))
    return img


# --- Giày, quần, áo --------------------------------------------------------
def shoes():
    img = canvas()
    d = ImageDraw.Draw(img)
    rounded(d, [425, 1330, 505, 1400], 18, fill=gray(176))
    rounded(d, [519, 1330, 599, 1400], 18, fill=gray(176))
    return img


def bottom(n):
    img = canvas()
    d = ImageDraw.Draw(img)
    rounded(d, [415, 1000, 609, 1270 if n == 1 else 1230], 30,
            fill=gray(207))
    return img


def top(n):
    img = canvas()
    d = ImageDraw.Draw(img)
    boxes = {1: [405, 716, 619, 1060], 2: [405, 716, 619, 1020],
             3: [395, 700, 629, 1100]}
    rounded(d, boxes[n], 40, fill=gray(221))
    return img


# --- Mắt, miệng ------------------------------------------------------------
def eyes(n):
    img = canvas()
    d = ImageDraw.Draw(img)
    if n == 1:
        d.ellipse([367, 448, 447, 512], fill=gray(230))
        d.ellipse([577, 448, 657, 512], fill=gray(230))
    elif n == 2:
        d.ellipse([355, 454, 459, 506], fill=gray(230))
        d.ellipse([565, 454, 669, 506], fill=gray(230))
    else:
        d.arc([367, 440, 447, 520], 200, 340, fill=gray(230), width=12)
        d.arc([577, 440, 657, 520], 200, 340, fill=gray(230), width=12)
    return img


def eyes_line(n):
    img = canvas()
    d = ImageDraw.Draw(img)
    if n == 1:
        d.ellipse([367, 448, 447, 512], outline=LINE, width=5)
        d.ellipse([577, 448, 657, 512], outline=LINE, width=5)
    elif n == 2:
        d.ellipse([355, 454, 459, 506], outline=LINE, width=5)
        d.ellipse([565, 454, 669, 506], outline=LINE, width=5)
    else:
        d.arc([367, 440, 447, 520], 200, 340, fill=LINE, width=5)
        d.arc([577, 440, 657, 520], 200, 340, fill=LINE, width=5)
    return img


def mouth(n):
    img = canvas()
    d = ImageDraw.Draw(img)
    if n == 1:
        d.arc([472, 540, 552, 610], 20, 160, fill=gray(224), width=10)
    elif n == 2:
        d.ellipse([474, 549, 550, 601], fill=gray(224))
    else:
        d.ellipse([492, 555, 532, 595], fill=gray(224))
    return img


def mouth_line(n):
    img = canvas()
    d = ImageDraw.Draw(img)
    if n == 1:
        d.arc([472, 540, 552, 610], 20, 160, fill=LINE, width=5)
    elif n == 2:
        d.ellipse([474, 549, 550, 601], outline=LINE, width=5)
    else:
        d.ellipse([492, 555, 532, 595], outline=LINE, width=5)
    return img


# --- Phụ kiện ---------------------------------------------------------------
def accessory_head(n):
    img = canvas()
    d = ImageDraw.Draw(img)
    if n == 1:  # Nơ ở góc phải trên đầu.
        d.polygon([(620, 250), (560, 215), (560, 285)], fill=gray(208))
        d.polygon([(620, 250), (680, 215), (680, 285)], fill=gray(208))
        d.ellipse([604, 234, 636, 266], fill=gray(208))
    else:  # Mũ phù thủy.
        d.polygon([(512, 120), (440, 280), (584, 280)], fill=gray(208))
        d.ellipse([420, 270, 604, 300], fill=gray(208))
    return img


def accessory_hand():
    img = canvas()  # Ô dù bên tay phải.
    d = ImageDraw.Draw(img)
    d.pieslice([630, 780, 770, 920], 180, 360, fill=gray(192))
    d.line([700, 850, 700, 950], fill=gray(192), width=8)
    return img


BUILDERS = {
    "girl_body_01": body,
    "girl_body_01_line": body_line,
    "girl_shoes_01": shoes,
    "girl_accessory_hand_01": accessory_hand,
}
for n in (1, 2, 3):
    BUILDERS[f"girl_hair_back_0{n}"] = (lambda n: lambda: hair_back(n))(n)
    BUILDERS[f"girl_hair_front_0{n}"] = (lambda n: lambda: hair_front(n))(n)
    BUILDERS[f"girl_eyes_0{n}"] = (lambda n: lambda: eyes(n))(n)
    BUILDERS[f"girl_eyes_0{n}_line"] = (lambda n: lambda: eyes_line(n))(n)
    BUILDERS[f"girl_mouth_0{n}"] = (lambda n: lambda: mouth(n))(n)
    BUILDERS[f"girl_mouth_0{n}_line"] = (lambda n: lambda: mouth_line(n))(n)
    BUILDERS[f"girl_top_0{n}"] = (lambda n: lambda: top(n))(n)
for n in (1, 2):
    BUILDERS[f"girl_bottom_0{n}"] = (lambda n: lambda: bottom(n))(n)
    BUILDERS[f"girl_accessory_head_0{n}"] = (
        lambda n: lambda: accessory_head(n))(n)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out_path = os.path.join(here, "character_fixtures.dart")
    entries = []
    total = 0
    for layer_id in sorted(BUILDERS):
        raw = png_bytes(BUILDERS[layer_id]())
        total += len(raw)
        assert len(raw) > 100, layer_id
        img = Image.open(io.BytesIO(raw))
        assert img.size == (W, H), (layer_id, img.size)
        assert img.mode == "RGBA", layer_id
        b64 = base64.b64encode(raw).decode("ascii")
        asset = f"assets/images/character/girl/{layer_id}.webp"
        entries.append((asset, b64))
    lines = [
        "/// Fixture hình tạm cho T2-02 (file sinh tự động, đừng sửa tay).",
        "///",
        "/// Chạy `python3 test/features/character/generate_character_fixtures.py`",
        "/// từ thư mục app/ để sinh lại. Mỗi lớp là một khối xám khác nhau,",
        "/// đúng khung hợp đồng 1024x1536, đúng vị trí từng lớp theo mốc",
        "/// khung trong docs/ASSETS.md. File hình thật thay thế fixture 1:1",
        "/// tại đúng đường dẫn manifest — code `CharacterView` không đổi.",
        "library;",
        "",
        "import 'dart:convert';",
        "",
        "import 'package:material_ui/material_ui.dart';",
        "",
        "/// Base64 PNG từng lớp tạm, key = đường dẫn asset Flutter.",
        "const Map<String, String> characterFixtureBase64 = {",
    ]
    for asset, b64 in entries:
        lines.append(f"  '{asset}': '{b64}',")
    lines += [
        "};",
        "",
        "/// Bộ nạp lớp cho test: giải mã fixture thành MemoryImage.",
        "ImageProvider characterFixtureLoader(String assetPath) {",
        "  final b64 = characterFixtureBase64[assetPath];",
        "  if (b64 == null) {",
        "    throw ArgumentError('Không có fixture cho \\$assetPath');",
        "  }",
        "  return MemoryImage(base64Decode(b64));",
        "}",
        "",
    ]
    with open(out_path, "w") as f:
        f.write("\n".join(lines))
    print(f"wrote {out_path}: {len(entries)} layers, "
          f"{total} bytes PNG, {sum(len(b) for _, b in entries)} chars base64")


if __name__ == "__main__":
    main()
