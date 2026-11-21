#!/usr/bin/env python3
"""Kiểm tra hình đầu vào theo hợp đồng trong ``assets/manifest.json``.

Hợp đồng (xem ``docs/ASSETS.md``): khung nhân vật 1024x1536, pet/đồ vật/
nội thất/lớp động thị trấn 512x512, nền JPEG hoặc PNG, tên file
``<dáng>_<lớp>_<tên món>.png``,
lớp đổi màu tô xám để app nhân màu, chi tiết không đổi màu đi file
riêng đuôi ``_line``, thứ tự chồng 8 lớp từ tóc sau lên phụ kiện.

Script kiểm tra:
  - manifest đúng lược đồ (lớp, trường bắt buộc, tên file khớp mã);
  - file trạng thái ``ready`` phải tồn tại và đúng nội dung: PNG đúng
    kích thước khung, có kênh alpha, có ít nhất một pixel trong suốt
    (kể cả ở viền), lớp đổi màu phải tô xám; riêng nền PNG thì không
    yêu cầu alpha (nền đặc, không chồng lớp);
  - file trạng thái ``planned`` chưa được có mặt (có rồi thì đổi
    status thành ``ready``);
  - mọi file hình trong ``app/assets/images/`` đều phải có dòng
    manifest tương ứng (trừ thư mục ``_incoming/``).

Cách dùng:
    python3 tools/assets/check_assets.py [--root <gốc repo>]
Trả 0 khi mọi kiểm tra qua, 1 khi có lỗi. Chỉ dùng thư viện chuẩn.
"""

import argparse
import json
import pathlib
import re
import struct
import sys
import zlib
from itertools import accumulate

# --- Hợp đồng cố định (khớp docs/ASSETS.md) -------------------------------

# 10 mã lớp, mỗi mã gắn một bậc chồng z (mắt và miệng cùng z 6,
# phụ kiện đầu và tay cùng z 8 — xem DESIGN mục "Thứ tự lớp").
LAYERS = {
    "hair_back": 1,
    "body": 2,
    "shoes": 3,
    "bottom": 4,
    "top": 5,
    "eyes": 6,
    "mouth": 6,
    "hair_front": 7,
    "accessory_head": 8,
    "accessory_hand": 8,
}

KINDS = {
    "character_layer",
    "character_full",
    "character_patch",
    "pet",
    "item",
    "furniture",
    "background",
    "icon",
    "town_layer",
}
FORMS = {"girl", "boy", "any"}
STATUSES = {"ready", "planned"}

# Khung (rộng, cao) cho từng loại; nền và icon SVG không kiểm tra
# kích thước (xem docs/ASSETS.md).
FRAMES = {
    "character_layer": (1024, 1536),
    # Ảnh toàn thân + phụ kiện phủ cùng khung (E, 21/11). Miếng vá mắt
    # nhắm (character_patch) có kích thước riêng nên không kiểm khung.
    "character_full": (1024, 1536),
    "pet": (512, 512),
    "item": (512, 512),
    "furniture": (512, 512),
    "town_layer": (512, 512),
}

# Tên file cho từng loại (chỉ tên file, không tính thư mục — thư mục
# kiểm riêng trong _check_entry_name).
NAME_PATTERNS = {
    "character_layer": re.compile(
        r"^(girl|boy)_"
        r"(hair_back|body|shoes|bottom|top|eyes|mouth|hair_front"
        r"|accessory_head|accessory_hand)"
        r"_[a-z0-9]+(_line)?\.png$"
    ),
    # Ảnh toàn thân 3 bộ × (nghỉ/vẫy) và phụ kiện phủ cùng khung (E).
    "character_full": re.compile(
        r"^(girl|boy)_(full_0[1-3](_wave|_walk_(dr|ur)_[a-d])?(_backpack)?"
        r"|hat_01|bow_01|clip_01"
        r"|glasses_01|backpack_01|shoes_02)\.png$"
    ),
    "character_patch": re.compile(
        r"^(girl|boy)_eyes_closed_patch(_0[1-3]_wave)?\.png$"
    ),
    "pet": re.compile(r"^(dog|cat|rabbit)_(egg|newborn|teen|adult)\.png$"),
    "item": re.compile(r"^[a-z0-9_]+\.png$"),
    "furniture": re.compile(r"^[a-z0-9_]+\.png$"),
    "background": re.compile(r"^[a-z0-9_]+\.(jpg|jpeg|png)$"),
    "icon": re.compile(r"^[a-z0-9_]+\.svg$"),
    "town_layer": re.compile(r"^[a-z0-9_]+\.png$"),
}

# Thư mục con cho từng loại (tính từ app/assets/images/); icon không
# bắt buộc thư mục (5 icon khu T1-12 nằm ngay ở gốc).
KIND_DIRS = {
    "character_layer": "character/{form}",
    "character_full": "character/{form}",
    "character_patch": "character/{form}",
    "pet": "pets",
    "item": "items",
    "furniture": "furniture",
    "background": "backgrounds",
    "icon": None,
    "town_layer": "town",
}

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".svg"}

# Pixel đổi màu phải gần như xám tuyệt đối (R, G, B lệch nhau tối đa
# chừng này mới nhân màu không bị ám màu).
GRAY_TOLERANCE = 8

def _add8(x: int, y: int) -> int:
    """Cộng hai byte theo modulo 256 (dùng cho bộ lọc Up)."""
    return (x + y) & 0xFF


PNG_SIG = b"\x89PNG\r\n\x1a\n"
JPEG_SOI = b"\xff\xd8\xff"


class CheckError(Exception):
    """Một lỗi kiểm tra (đã có tiền tố vị trí trong thông báo)."""


class Checker:
    def __init__(self, root: pathlib.Path):
        self.root = root
        self.images_dir = root / "app" / "assets" / "images"
        self.errors: list[str] = []

    def fail(self, where: str, msg: str) -> None:
        self.errors.append(f"LỖI {where}: {msg}")

    # -- PNG (chỉ dùng thư viện chuẩn) ------------------------------------

    def _read_png(self, path: pathlib.Path, where: str):
        """Đọc PNG, trả (rộng, cao, loại màu, dữ liệu thô đã inflate).

        Chỉ hỗ trợ PNG 8-bit không interlaced, loại màu 4 (xám+alpha)
        hoặc 6 (RGBA). Các trường hợp khác báo lỗi rõ ràng. Chưa gỡ
        bộ lọc từng dòng ở đây (xem ``_scan_rows`` / ``_unfilter``):
        phần lớn ảnh chỉ cần nhìn vài pixel, giải đủ cả ảnh rất chậm
        trong Python thuần.
        """
        data = path.read_bytes()
        if not data.startswith(PNG_SIG):
            raise CheckError(f"{where}: không phải file PNG")
        pos = 8
        width = height = bit_depth = color_type = interlace = None
        idat = bytearray()
        has_trns = False
        while pos + 8 <= len(data):
            length = struct.unpack(">I", data[pos:pos + 4])[0]
            ctype = data[pos + 4:pos + 8].decode("latin-1")
            chunk = data[pos + 8:pos + 8 + length]
            if ctype == "IHDR":
                width, height, bit_depth, color_type, _, _, interlace = (
                    struct.unpack(">IIBBBBB", chunk)
                )
            elif ctype == "IDAT":
                idat += chunk
            elif ctype == "tRNS":
                has_trns = True
            elif ctype == "IEND":
                break
            pos += 12 + length
        if width is None:
            raise CheckError(f"{where}: thiếu khối IHDR")
        if bit_depth != 8:
            raise CheckError(
                f"{where}: chỉ hỗ trợ PNG 8-bit (đang là {bit_depth}-bit)"
            )
        if interlace != 0:
            raise CheckError(f"{where}: không dùng PNG interlaced")
        if color_type not in (4, 6):
            raise CheckError(
                f"{where}: PNG phải có kênh alpha (loại màu 4 hoặc 6, "
                f"đang là {color_type})"
            )
        if has_trns:
            raise CheckError(
                f"{where}: không dùng khối tRNS, hãy xuất PNG có kênh "
                "alpha thật (loại màu 4 hoặc 6)"
            )
        try:
            raw = zlib.decompress(bytes(idat))
        except zlib.error:
            raise CheckError(f"{where}: không giải nén được dữ liệu IDAT")
        return width, height, color_type, raw

    def _check_rows(self, raw, width: int, height: int, bpp: int,
                    where: str) -> None:
        """Mỗi dòng phải đủ dữ liệu và có loại lọc hợp lệ (0-4)."""
        row_len = 1 + width * bpp
        for y in range(height):
            if y * row_len + row_len > len(raw):
                raise CheckError(f"{where}: dữ liệu ảnh ngắn hơn khai báo")
            if raw[y * row_len] > 4:
                raise CheckError(
                    f"{where}: loại lọc PNG lạ ({raw[y * row_len]})"
                )

    def _unfilter(self, raw, width: int, height: int, bpp: int,
                  where: str) -> bytes:
        """Gỡ bộ lọc mọi dòng, trả bytes pixel (chậm: chỉ dùng khi cần).

        Mỗi kênh được lọc độc lập (hàng xóm cách đúng ``bpp`` byte)
        nên Sub/Up chạy bằng slicing và cộng dồn ở tốc độ C; chỉ
        Average và Paeth mới phải lặp từng byte.
        """
        self._check_rows(raw, width, height, bpp, where)
        stride = width * bpp
        pixels = bytearray(width * height * bpp)
        prev = bytearray(stride)
        offset = 0
        for y in range(height):
            ftype = raw[offset]
            line = bytearray(raw[offset + 1:offset + 1 + stride])
            offset += 1 + stride
            if ftype == 0:
                pass
            elif ftype == 1:
                # Sub: cộng dồn theo từng kênh (cách nhau bpp byte).
                for c in range(bpp):
                    line[c::bpp] = bytes(
                        v & 0xFF for v in accumulate(line[c::bpp])
                    )
            elif ftype == 2:
                # Up: cộng với dòng trước, từng byte nhưng qua map (C).
                line = bytearray(map(_add8, line, prev))
            elif ftype == 3:
                for i in range(stride):
                    left = line[i - bpp] if i >= bpp else 0
                    line[i] = (line[i] + (left + prev[i]) // 2) & 0xFF
            else:
                for i in range(stride):
                    a = line[i - bpp] if i >= bpp else 0
                    b = prev[i]
                    c = prev[i - bpp] if i >= bpp else 0
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    pred = a if (pa <= pb and pa <= pc) else (
                        b if pb <= pc else c
                    )
                    line[i] = (line[i] + pred) & 0xFF
            pixels[y * stride:(y + 1) * stride] = line
            prev = line
        return bytes(pixels)

    def _quick_transparent_edge(self, raw, width: int, height: int,
                                bpp: int) -> bool:
        """True nếu dòng đầu hoặc cột đầu có pixel alpha < 255.

        Chỉ giải đúng chỗ cần: dòng đầu (trước đó chưa có dòng nào nên
        giải rẻ) và cột đầu (pixel x = 0 không có hàng xóm trái, nên
        giá trị chỉ phụ thuộc cột đầu của dòng trên). Gặp một pixel
        trong suốt ở viền là đủ chứng minh cả hai điều kiện "có pixel
        trong suốt" và "có pixel trong suốt ở viền", khỏi giải cả ảnh.
        Trả False nghĩa là chưa kết luận (phải giải đủ).
        """
        row_len = 1 + width * bpp
        alpha_at = bpp - 1
        # Dòng đầu: giải đủ một dòng, prev toàn 0.
        first = self._unfilter(
            raw[:row_len], width, 1, bpp, ""
        )
        if min(first[alpha_at::bpp]) < 255:
            return True
        up = first[alpha_at]  # alpha cột đầu của dòng trước
        for y in range(1, height):
            base = y * row_len
            ftype = raw[base]
            v = raw[base + 1 + alpha_at]
            if ftype == 0:
                up = v
            elif ftype == 1:
                up = v  # Sub: hàng xóm trái = 0
            elif ftype == 2:
                up = (v + up) & 0xFF
            elif ftype == 3:
                up = (v + up // 2) & 0xFF
            else:
                up = (v + up) & 0xFF  # Paeth: a = c = 0 nên đoán = b
            if up < 255:
                return True
        return False

    def _check_png(self, entry: dict, path: pathlib.Path) -> None:
        where = entry["file"]
        try:
            width, height, color_type, raw = self._read_png(path, where)
            bpp = 2 if color_type == 4 else 4
            # Kiểm dòng/lọc cho cả ảnh trước (giữ nguyên lỗi như cũ).
            self._check_rows(raw, width, height, bpp, where)
        except CheckError as exc:
            self.fail(where, str(exc).removeprefix(f"{where}: "))
            return
        frame = FRAMES.get(entry["kind"])
        if frame is not None and (width, height) != frame:
            # Ghi lỗi nhưng vẫn kiểm tiếp độ trong suốt/xám để người
            # cắt thấy hết lỗi trong một lần chạy.
            self.fail(
                where,
                f"sai kích thước khung: {width}x{height}, "
                f"loại {entry['kind']} phải là {frame[0]}x{frame[1]}",
            )
        alpha_at = bpp - 1
        pixels = None  # chỉ giải đủ cả ảnh khi thật sự cần

        # Ít nhất một pixel trong suốt (ảnh không được là nền đặc) và
        # ít nhất một pixel trong suốt ở viền (lớp phải nằm trong khung,
        # không chạm mép an toàn). Đường nhanh: ảnh thường có góc trong
        # suốt nên dòng đầu/cột đầu đã đủ; không thì giải đủ rồi kiểm.
        if not self._quick_transparent_edge(raw, width, height, bpp):
            pixels = self._unfilter(raw, width, height, bpp, where)
            alphas = pixels[alpha_at::bpp]
            if min(alphas) == 255:
                self.fail(where, "PNG không có pixel trong suốt nào (nền đặc)")
                return
            border = (
                alphas[:width]
                + alphas[(height - 1) * width:]
                + alphas[::width]
                + alphas[width - 1::width]
            )
            if min(border) == 255:
                self.fail(
                    where,
                    "PNG không có pixel trong suốt ở viền — hình chạm mép "
                    "khung, xem lại mép an toàn trong assets/templates/",
                )
                return
        # Lớp đổi màu phải tô xám (app nhân màu lên lớp xám). Loại màu 4
        # (xám+alpha) mặc nhiên thỏa; loại màu 6 kiểm từng pixel còn
        # thấy được (alpha > 0). Chỉ lớp recolorable mới tốn công này.
        if entry.get("recolorable") and color_type == 6:
            if pixels is None:
                pixels = self._unfilter(raw, width, height, bpp, where)
            alphas = pixels[3::4]
            reds = pixels[0::4]
            greens = pixels[1::4]
            blues = pixels[2::4]
            for i, (r, g, b, a) in enumerate(
                zip(reds, greens, blues, alphas)
            ):
                if a == 0:
                    continue
                if max(r, g, b) - min(r, g, b) > GRAY_TOLERANCE:
                    self.fail(
                        where,
                        "lớp đổi màu phải tô xám (R, G, B gần bằng nhau) "
                        "để app nhân màu được; pixel "
                        f"({i % width}, {i // width}) có màu ({r}, {g}, {b})",
                    )
                    return

    def _check_png_background(self, entry: dict, path: pathlib.Path) -> None:
        """Nền PNG: chỉ cần là PNG 8-bit thật, không yêu cầu alpha.

        Nền là ảnh đặc (không chồng lớp) nên không cần pixel trong
        suốt ở viền như lớp nhân vật/pet/nội thất, và được phép là
        RGB không kênh alpha (loại màu 2). Nền PNG được phép từ A1
        vì đường đưa ảnh base64 chỉ nhận PNG (xem docs/ASSETS.md).
        """
        where = entry["file"]
        data = path.read_bytes()
        if not data.startswith(PNG_SIG) or len(data) < 26:
            self.fail(where, "không phải file PNG")
            return
        width, height, bit_depth, color_type, _, _, interlace = (
            struct.unpack(">IIBBBBB", data[16:29])
        )
        if bit_depth != 8:
            self.fail(where, f"chỉ hỗ trợ PNG 8-bit (đang là {bit_depth}-bit)")
        if interlace != 0:
            self.fail(where, "không dùng PNG interlaced")
        if color_type not in (0, 2, 3, 4, 6):
            self.fail(where, f"loại màu PNG lạ ({color_type})")
        if width <= 0 or height <= 0:
            self.fail(where, "kích thước PNG không hợp lệ")

    # -- Manifest -----------------------------------------------------------

    def _check_manifest(self, manifest: dict) -> list[dict]:
        if not isinstance(manifest, dict):
            self.fail("assets/manifest.json", "file manifest phải là object JSON")
            return []
        if manifest.get("version") != 1:
            self.fail(
                "assets/manifest.json",
                f"version phải là 1 (đang là {manifest.get('version')!r})",
            )
        layers = manifest.get("layers")
        if not isinstance(layers, list):
            self.fail("assets/manifest.json", "thiếu danh sách 'layers'")
            layers = []
        for layer in layers:
            if not isinstance(layer, dict):
                self.fail("assets/manifest.json", "mục trong 'layers' phải là object")
                continue
            lid = layer.get("id")
            z = layer.get("z")
            if not isinstance(z, int) or isinstance(z, bool):
                self.fail(
                    "assets/manifest.json", f"lớp {lid!r} thiếu z (số nguyên)"
                )
                continue
            if lid not in LAYERS:
                self.fail(
                    "assets/manifest.json",
                    f"mã lớp lạ {lid!r} (hợp đồng chỉ có: "
                    f"{', '.join(LAYERS)})",
                )
            elif LAYERS[lid] != z:
                self.fail(
                    "assets/manifest.json",
                    f"lớp {lid!r} phải có z = {LAYERS[lid]} "
                    f"(đang là {z!r})",
                )
            # Hai lớp được phép chung một z (mắt/miệng z 6, phụ kiện
            # đầu/tay z 8) nên không kiểm trùng z ở đây.
        missing_layers = set(LAYERS) - {
            l.get("id") for l in layers if isinstance(l, dict)
        }
        if missing_layers:
            self.fail(
                "assets/manifest.json",
                "thiếu lớp trong hợp đồng: " + ", ".join(sorted(missing_layers)),
            )
        entries = manifest.get("entries")
        if not isinstance(entries, list):
            self.fail("assets/manifest.json", "thiếu danh sách 'entries'")
            return []
        return entries

    def _check_entry_fields(self, entry: dict, index: int) -> bool:
        where = f"assets/manifest.json entries[{index}]"
        if not isinstance(entry, dict):
            self.fail(where, "mục phải là object")
            return False
        ok = True
        required = (
            "id", "file", "kind", "form", "layer", "recolorable",
            "line", "set", "price_xu", "price_gem", "status", "name_vi",
            "source",
        )
        for field in required:
            if field not in entry:
                self.fail(where, f"thiếu trường {field!r}")
                ok = False
        if not ok:
            return False
        kind = entry["kind"]
        if kind not in KINDS:
            self.fail(where, f"loại lạ {kind!r} (chỉ có: {', '.join(sorted(KINDS))})")
            ok = False
        if entry["form"] not in FORMS:
            self.fail(where, f"dáng lạ {entry['form']!r} (girl/boy/any)")
            ok = False
        if entry["status"] not in STATUSES:
            self.fail(where, f"trạng thái lạ {entry['status']!r} (ready/planned)")
            ok = False
        if not isinstance(entry["recolorable"], bool):
            self.fail(where, "trường 'recolorable' phải là true/false")
            ok = False
        if not isinstance(entry["line"], bool):
            self.fail(where, "trường 'line' phải là true/false")
            ok = False
        if entry["line"] and entry["recolorable"]:
            self.fail(where, "file _line không đổi màu (line=true thì recolorable=false)")
            ok = False
        if entry["kind"] == "character_layer":
            if entry["layer"] not in LAYERS:
                self.fail(where, f"lớp lạ {entry['layer']!r} cho lớp nhân vật")
                ok = False
        elif entry["layer"] is not None:
            self.fail(where, "chỉ lớp nhân vật mới có trường 'layer'")
            ok = False
        for price in ("price_xu", "price_gem"):
            value = entry[price]
            if value is not None and (
                not isinstance(value, int) or isinstance(value, bool) or value < 0
            ):
                self.fail(where, f"trường {price!r} phải là số nguyên >= 0 hoặc null")
                ok = False
        return ok

    def _check_entry_name(self, entry: dict) -> bool:
        where = f"assets/manifest.json ({entry['id']})"
        rel = entry["file"]
        prefix = "app/assets/images/"
        if not rel.startswith(prefix):
            self.fail(where, f"đường dẫn phải bắt đầu bằng {prefix!r}")
            return False
        short = rel[len(prefix):]
        parts = short.split("/")
        basename = parts[-1]
        # Thư mục con đúng loại (lớp nhân vật: character/<dáng>/).
        want_dir = KIND_DIRS[entry["kind"]]
        if want_dir is not None:
            want_dir = want_dir.format(form=entry["form"])
            actual_dir = "/".join(parts[:-1])
            if actual_dir != want_dir:
                self.fail(
                    where,
                    f"file loại {entry['kind']} phải nằm trong thư mục "
                    f"{want_dir!r} (đang là {actual_dir!r})",
                )
                return False
        pattern = NAME_PATTERNS[entry["kind"]]
        match = pattern.match(basename)
        if not match:
            self.fail(
                where,
                f"tên file {basename!r} sai quy tắc đặt tên của loại "
                f"{entry['kind']}",
            )
            return False
        stem = pathlib.PurePosixPath(basename).stem
        if entry["id"] != stem:
            self.fail(where, f"mã {entry['id']!r} phải trùng tên file {stem!r}")
            return False
        if entry["kind"] == "character_layer":
            form, layer = match.group(1), match.group(2)
            if form != entry["form"]:
                self.fail(where, f"tên file ghi dáng {form!r} nhưng trường form là {entry['form']!r}")
                return False
            if layer != entry["layer"]:
                self.fail(where, f"tên file ghi lớp {layer!r} nhưng trường layer là {entry['layer']!r}")
                return False
            has_line = match.group(3) is not None
            if has_line != entry["line"]:
                self.fail(
                    where,
                    "tên file có đuôi _line nhưng trường line là "
                    f"{entry['line']!r} (hoặc ngược lại)",
                )
                return False
        return True

    def run(self) -> int:
        manifest_path = self.root / "assets" / "manifest.json"
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            self.fail("assets/manifest.json", "không tìm thấy file manifest")
            return self._report(0)
        except json.JSONDecodeError as exc:
            self.fail("assets/manifest.json", f"JSON hỏng: {exc}")
            return self._report(0)

        entries = self._check_manifest(manifest)
        seen_ids: set[str] = set()
        seen_files: set[str] = set()
        hair_sets: dict[str, list[str]] = {}
        line_bases: set[str] = set()
        for index, entry in enumerate(entries):
            if not isinstance(entry, dict):
                continue
            if not self._check_entry_fields(entry, index):
                continue
            eid = entry["id"]
            if eid in seen_ids:
                self.fail("assets/manifest.json", f"mã trùng nhau: {eid!r}")
                continue
            seen_ids.add(eid)
            if entry["file"] in seen_files:
                self.fail(
                    "assets/manifest.json",
                    f"đường dẫn trùng nhau: {entry['file']!r}",
                )
                continue
            seen_files.add(entry["file"])
            if not self._check_entry_name(entry):
                continue
            if entry["kind"] == "character_layer" and entry["line"]:
                line_bases.add(entry["id"].removesuffix("_line"))
            if entry.get("set") is not None:
                hair_sets.setdefault(entry["set"], []).append(entry["id"])

            path = self.root / entry["file"]
            if entry["status"] == "planned":
                if path.exists():
                    self.fail(
                        entry["file"],
                        "file đã có trên repo nhưng manifest còn ghi "
                        "planned — đổi status thành ready",
                    )
                continue
            # status == ready: file phải tồn tại và đúng nội dung.
            if not path.exists():
                self.fail(entry["file"], "manifest ghi ready nhưng thiếu file")
                continue
            if entry["file"].endswith(".png"):
                if entry["kind"] == "background":
                    self._check_png_background(entry, path)
                else:
                    self._check_png(entry, path)
            elif entry["file"].endswith((".jpg", ".jpeg")):
                if not path.read_bytes().startswith(JPEG_SOI):
                    self.fail(entry["file"], "không phải file JPEG thật")
            elif entry["file"].endswith(".svg"):
                pass  # SVG vector: chỉ kiểm tra tồn tại + tên file.

        # File _line phải có file gốc đi kèm.
        for base in sorted(line_bases):
            if base not in seen_ids:
                self.fail(
                    "assets/manifest.json",
                    f"file _line {base}_line có trong manifest nhưng thiếu "
                    f"file gốc {base}",
                )
        # Mỗi bộ tóc phải đủ tóc sau + tóc trước cùng dáng.
        for set_name, ids in sorted(hair_sets.items()):
            backs = [i for i in ids if "_hair_back_" in i]
            fronts = [i for i in ids if "_hair_front_" in i]
            if len(backs) != 1 or len(fronts) != 1:
                self.fail(
                    "assets/manifest.json",
                    f"bộ tóc {set_name!r} phải có đúng 1 tóc sau + 1 tóc "
                    f"trước (đang có: {', '.join(ids)})",
                )

        # Mọi file hình trong thư mục ảnh đều phải có trong manifest.
        if self.images_dir.is_dir():
            for path in sorted(self.images_dir.rglob("*")):
                if not path.is_file() or path.suffix.lower() not in IMAGE_EXTS:
                    continue
                rel = path.relative_to(self.root).as_posix()
                if "_incoming/" in rel:
                    continue
                if rel not in seen_files:
                    self.fail(
                        rel,
                        "file hình không có dòng manifest tương ứng — "
                        "thêm một dòng vào assets/manifest.json",
                    )
        return self._report(len(entries))

    def _report(self, total: int) -> int:
        for error in self.errors:
            print(error)
        if self.errors:
            print(
                f"KIỂM TRA HÌNH: {len(self.errors)} lỗi / {total} mục "
                "trong manifest"
            )
            return 1
        print(f"KIỂM TRA HÌNH: OK ({total} mục trong manifest)")
        return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Kiểm tra hình theo assets/manifest.json"
    )
    parser.add_argument(
        "--root",
        type=pathlib.Path,
        default=pathlib.Path(__file__).resolve().parents[2],
        help="gốc repo (mặc định: suy ra từ vị trí script)",
    )
    args = parser.parse_args(argv)
    return Checker(args.root).run()


if __name__ == "__main__":
    sys.exit(main())
