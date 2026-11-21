#!/usr/bin/env python3
"""Test cho tools/assets/check_assets.py (chỉ dùng thư viện chuẩn).

Chạy:  python3 tools/assets/check_assets_test.py
Mỗi test dựng một cây repo tạm (manifest + vài file hình) rồi gọi
Checker trên đó. Ảnh PNG mẫu được ghi bằng code thuần (struct +
zlib), không cần PIL.
"""

import json
import pathlib
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from check_assets import Checker  # noqa: E402


def write_png(path: pathlib.Path, width: int, height: int,
              color_type: int, pixel) -> None:
    """Ghi PNG 8-bit, lọc None. pixel(x, y) trả tuple kênh (RGBA hoặc
    xám+alpha). Chỉ dùng cho ảnh nhỏ trong test."""
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw += bytes(pixel(x, y))
    assert len(raw) == height * (1 + width * bpp)
    _write_png_bytes(path, width, height, color_type, bytes(raw))


def write_png_rows(path: pathlib.Path, width: int, height: int,
                   color_type: int, top_row: bytes, mid_row: bytes) -> None:
    """Ghi PNG 8-bit từ 2 hàng mẫu (hàng viền + hàng giữa) — nhanh cho
    ảnh đúng khung 1024x1536/512x512. Hàng dưới = hàng viền."""
    bpp = 2 if color_type == 4 else 4
    assert len(top_row) == width * bpp and len(mid_row) == width * bpp
    raw = b"\x00" + top_row
    raw += (b"\x00" + mid_row) * (height - 2)
    raw += b"\x00" + top_row
    _write_png_bytes(path, width, height, color_type, raw)


def _write_png_bytes(path: pathlib.Path, width: int, height: int,
                     color_type: int, raw: bytes, extra=None,
                     trns: bytes | None = None) -> None:

    def chunk(ctype: bytes, data: bytes) -> bytes:
        out = struct.pack(">I", len(data)) + ctype + data
        return out + struct.pack(">I", zlib.crc32(ctype + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    data = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + (chunk(*extra) if extra else b"")
        + (chunk(b"tRNS", trns) if trns else b"")
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def write_png_filtered(path: pathlib.Path, width: int, height: int,
                       color_type: int, pixel, filters) -> None:
    """Ghi PNG 8-bit với bộ lọc thật: dòng y dùng loại lọc
    filters[y % len(filters)] (0 None, 1 Sub, 2 Up, 3 Average, 4 Paeth).
    Dùng để kiểm đường giải lọc nhanh. Chỉ cho ảnh nhỏ."""
    bpp = {4: 2, 6: 4}[color_type]
    stride = width * bpp
    rows = [
        bytes(v for x in range(width) for v in pixel(x, y))
        for y in range(height)
    ]
    raw = bytearray()
    prev = bytes(stride)
    for y, row in enumerate(rows):
        ftype = filters[y % len(filters)]
        out = bytearray()
        for i in range(stride):
            a = row[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if ftype == 0:
                pred = 0
            elif ftype == 1:
                pred = a
            elif ftype == 2:
                pred = b
            elif ftype == 3:
                pred = (a + b) // 2
            else:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (
                    b if pb <= pc else c)
            out.append((row[i] - pred) & 0xFF)
        raw.append(ftype)
        raw += out
        prev = row
    _write_png_bytes(path, width, height, color_type, bytes(raw))


LAYERS = [
    {"id": "hair_back", "z": 1, "name_vi": "Tóc sau"},
    {"id": "body", "z": 2, "name_vi": "Thân (da)"},
    {"id": "shoes", "z": 3, "name_vi": "Giày"},
    {"id": "bottom", "z": 4, "name_vi": "Quần hoặc váy"},
    {"id": "top", "z": 5, "name_vi": "Áo"},
    {"id": "eyes", "z": 6, "name_vi": "Mắt"},
    {"id": "mouth", "z": 6, "name_vi": "Miệng"},
    {"id": "hair_front", "z": 7, "name_vi": "Tóc trước"},
    {"id": "accessory_head", "z": 8, "name_vi": "Phụ kiện đầu"},
    {"id": "accessory_hand", "z": 8, "name_vi": "Phụ kiện tay"},
]


def entry(eid, file, kind="character_layer", form="girl", layer="top",
          recolorable=True, line=False, set_=None, status="ready"):
    return {
        "id": eid, "file": file, "kind": kind, "form": form,
        "layer": layer, "recolorable": recolorable, "line": line,
        "set": set_, "price_xu": None, "price_gem": None,
        "status": status, "name_vi": eid, "source": "test",
    }


class CheckAssetsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        (self.root / "assets").mkdir()
        (self.root / "app" / "assets" / "images").mkdir(parents=True)
        self.manifest = {"version": 1, "docs": "docs/ASSETS.md",
                         "frames": {}, "layers": LAYERS, "entries": []}

    def tearDown(self):
        self.tmp.cleanup()

    def write_manifest(self):
        (self.root / "assets" / "manifest.json").write_text(
            json.dumps(self.manifest, ensure_ascii=False), encoding="utf-8"
        )

    def run_checker(self):
        checker = Checker(self.root)
        code = checker.run()
        return code, checker.errors

    def add_valid_top(self, eid="girl_top_01", w=1024, h=1536):
        path = self.root / f"app/assets/images/character/girl/{eid}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 200, 200, 0]) * w
        mid_row = (
            bytes([200, 200, 200, 0])
            + bytes([200, 200, 200, 255]) * (w - 2)
            + bytes([200, 200, 200, 0])
        )
        write_png_rows(path, w, h, 6, top_row, mid_row)
        self.manifest["entries"].append(
            entry(eid, f"app/assets/images/character/girl/{eid}.png")
        )
        return path

    def test_valid_tree_passes(self):
        self.add_valid_top()
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    def test_opaque_png_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.png"
        write_png(path, 1024, 1536, 6, lambda x, y: (200, 200, 200, 255))
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.png")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("không có pixel trong suốt" in e for e in errors),
                        errors)

    def test_transparent_center_but_opaque_border_fails(self):
        # Trong suốt ở giữa nhưng viền đặc (hình chạm mép khung).
        def pixel(x, y, w=64, h=64):
            if 10 <= x < w - 10 and 10 <= y < h - 10:
                return (200, 200, 200, 0)
            return (200, 200, 200, 255)
        path = self.root / "app/assets/images/character/girl/girl_top_01.png"
        write_png(path, 64, 64, 6, pixel)
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.png")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("ở viền" in e for e in errors), errors)

    def test_wrong_frame_size_fails(self):
        self.add_valid_top(w=512, h=512)
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("sai kích thước khung" in e for e in errors),
                        errors)

    def test_jpeg_bytes_as_png_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.png")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("không phải file PNG" in e for e in errors),
                        errors)

    def test_png_without_alpha_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.png"
        write_png(path, 16, 16, 2, lambda x, y: (200, 200, 200))
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.png")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("kênh alpha" in e for e in errors), errors)

    def test_colored_recolorable_layer_fails(self):
        # Ảnh đúng khung, viền trong suốt, một pixel đỏ chói ở giữa.
        path = self.root / "app/assets/images/character/girl/girl_top_01.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 200, 200, 0]) * 1024
        mid = bytearray(bytes([200, 200, 200, 255]) * 1024)
        mid[0:4] = bytes([200, 200, 200, 0])
        mid[-4:] = bytes([200, 200, 200, 0])
        mid[4:8] = bytes([255, 0, 0, 255])  # đỏ chói, không phải xám
        write_png_rows(path, 1024, 1536, 6, top_row, bytes(mid))
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.png")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("phải tô xám" in e for e in errors), errors)

    def test_gray_alpha_png_passes(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 0]) * 1024
        mid_row = bytes([200, 0]) + bytes([200, 255]) * 1022 + bytes([200, 0])
        write_png_rows(path, 1024, 1536, 4, top_row, mid_row)
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.png")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    # -- Đường giải lọc nhanh / không giải đủ ---------------------------

    def _add_small(self, pixel, color_type=6, filters=(0,), w=48, h=40,
                   recolorable=False, eid="girl_top_01"):
        """PNG nhỏ có lọc thật; kích thước khung sai nên lọc bỏ lỗi
        khung khi so sánh thông báo."""
        path = self.root / f"app/assets/images/character/girl/{eid}.png"
        write_png_filtered(path, w, h, color_type, pixel, filters)
        self.manifest["entries"].append(
            entry(eid, f"app/assets/images/character/girl/{eid}.png",
                  recolorable=recolorable)
        )
        self.write_manifest()
        code, errors = self.run_checker()
        return code, [e for e in errors if "sai kích thước khung" not in e]

    def test_every_filter_type_with_transparent_corner_passes(self):
        # Mỗi loại lọc (và xen kẽ) vẫn phải thấy góc trong suốt.
        def pixel(x, y):
            alpha = 0 if (x == 0 or y == 0 or x == 47 or y == 39) else 255
            return (90 + x, 100 + y, 110 + (x ^ y) % 7, alpha)
        for filters in ((0,), (1,), (2,), (3,), (4,), (4, 3, 2, 1, 0)):
            with self.subTest(filters=filters):
                self.setUp()
                code, errors = self._add_small(pixel, filters=filters)
                self.assertEqual(errors, [])
                self.assertEqual(code, 1)  # chỉ còn lỗi khung sai (đã lọc)

    def test_border_touching_fails_with_every_filter(self):
        # Trong suốt chỉ ở giữa: đường nhanh không kết luận được, phải
        # giải đủ và báo chạm mép.
        def pixel(x, y):
            inner = 5 <= x < 40 and 5 <= y < 30
            return (90, 100 + x, 110 + y, 0 if inner else 255)
        for filters in ((0,), (1,), (2,), (3,), (4,), (4, 3, 2, 1, 0)):
            with self.subTest(filters=filters):
                self.setUp()
                _, errors = self._add_small(pixel, filters=filters)
                self.assertEqual(len(errors), 1, errors)
                self.assertIn("không có pixel trong suốt ở viền", errors[0])

    def test_opaque_png_with_paeth_fails(self):
        def pixel(x, y):
            return (x * 5 % 256, y * 3 % 256, (x + y) % 256, 255)
        _, errors = self._add_small(pixel, filters=(4, 1, 3, 2))
        self.assertEqual(len(errors), 1, errors)
        self.assertIn("không có pixel trong suốt nào", errors[0])

    def test_transparent_only_at_left_column_passes_fast_path(self):
        # Chỉ cột đầu có alpha < 255 ở các dòng giữa (lọc Up/Paeth/Sub
        # phải giữ đúng giá trị cột đầu qua nhiều dòng).
        def pixel(x, y):
            alpha = 128 if (x == 0 and y == 20) else 255
            return (50, 60, 70, alpha)
        for filters in ((2,), (4,), (1,), (3,), (4, 2, 3)):
            with self.subTest(filters=filters):
                self.setUp()
                _, errors = self._add_small(pixel, filters=filters)
                self.assertEqual(errors, [])

    def test_gray_alpha_with_filters_passes(self):
        def pixel(x, y):
            return (x * 4 % 256, 0 if (x == 0 or y == 0) else 255)
        _, errors = self._add_small(pixel, color_type=4, filters=(4, 3, 1, 2))
        self.assertEqual(errors, [])

    def test_recolorable_colored_pixel_with_paeth_reports_position(self):
        def pixel(x, y):
            alpha = 0 if (x == 0 or y == 0) else 255
            if (x, y) == (7, 9):
                return (255, 0, 0, 255)
            return (120, 120, 120, alpha)
        _, errors = self._add_small(pixel, filters=(4,), recolorable=True)
        self.assertEqual(len(errors), 1, errors)
        self.assertIn("pixel (7, 9) có màu (255, 0, 0)", errors[0])

    def test_palette_png_with_trns_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.png"
        raw = b"".join(b"\x00" + bytes([0, 1] * 8) for _ in range(16))
        _write_png_bytes(path, 16, 16, 3, raw,
                         extra=(b"PLTE", bytes([9, 9, 9, 200, 200, 200])),
                         trns=bytes([0, 255]))
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.png")
        )
        self.write_manifest()
        _, errors = self.run_checker()
        self.assertTrue(any("kênh alpha" in e for e in errors), errors)

    def test_truncated_image_data_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.png"
        _write_png_bytes(path, 16, 16, 6, b"\x00" + bytes(16 * 4) * 3)
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.png")
        )
        self.write_manifest()
        _, errors = self.run_checker()
        self.assertTrue(any("ngắn hơn khai báo" in e for e in errors), errors)

    def test_unknown_filter_type_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.png"
        _write_png_bytes(path, 4, 2, 6, (b"\x07" + bytes(16)) * 2)
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.png")
        )
        self.write_manifest()
        _, errors = self.run_checker()
        self.assertTrue(any("loại lọc PNG lạ (7)" in e for e in errors),
                        errors)

    def test_missing_ready_file_fails(self):
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.png")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("thiếu file" in e for e in errors), errors)

    def test_planned_file_present_fails(self):
        self.add_valid_top()
        self.manifest["entries"][0]["status"] = "planned"
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("đổi status thành ready" in e for e in errors),
                        errors)

    def test_orphan_file_fails(self):
        self.add_valid_top()
        orphan = self.root / "app/assets/images/pets/dog_egg.png"
        orphan.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 200, 200, 0]) * 512
        mid_row = (
            bytes([200, 200, 200, 0])
            + bytes([200, 200, 200, 255]) * 510
            + bytes([200, 200, 200, 0])
        )
        write_png_rows(orphan, 512, 512, 6, top_row, mid_row)
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("không có dòng manifest" in e for e in errors),
                        errors)

    def test_bad_name_fails(self):
        self.add_valid_top()
        # Đổi tên file thành dạng sai (đuôi .jpeg cho lớp nhân vật).
        self.manifest["entries"][0]["file"] = (
            "app/assets/images/character/girl/girl_top_01.jpeg"
        )
        self.manifest["entries"][0]["id"] = "girl_top_01"
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("sai quy tắc đặt tên" in e for e in errors),
                        errors)

    def test_wrong_layer_z_fails(self):
        self.add_valid_top()
        self.manifest["layers"] = [
            dict(layer, z=9) if layer["id"] == "top" else layer
            for layer in LAYERS
        ]
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("phải có z = 5" in e for e in errors), errors)

    def test_duplicate_id_fails(self):
        self.add_valid_top()
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_02.png")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("mã trùng nhau" in e for e in errors), errors)

    def test_line_without_base_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01_line.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 200, 200, 0]) * 1024
        mid_row = (
            bytes([200, 200, 200, 0])
            + bytes([200, 200, 200, 255]) * 1022
            + bytes([200, 200, 200, 0])
        )
        write_png_rows(path, 1024, 1536, 6, top_row, mid_row)
        self.manifest["entries"].append(
            entry("girl_top_01_line",
                  "app/assets/images/character/girl/girl_top_01_line.png",
                  recolorable=False, line=True)
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("thiếu file gốc" in e for e in errors), errors)

    def test_incomplete_hair_set_fails(self):
        back = self.root / "app/assets/images/character/girl/girl_hair_back_01.png"
        back.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 200, 200, 0]) * 1024
        mid_row = (
            bytes([200, 200, 200, 0])
            + bytes([200, 200, 200, 255]) * 1022
            + bytes([200, 200, 200, 0])
        )
        write_png_rows(back, 1024, 1536, 6, top_row, mid_row)
        self.manifest["entries"].append(
            entry("girl_hair_back_01",
                  "app/assets/images/character/girl/girl_hair_back_01.png",
                  layer="hair_back", set_="girl_hair_01")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("bộ tóc" in e for e in errors), errors)

    def test_pet_frame_passes(self):
        path = self.root / "app/assets/images/pets/dog_egg.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 200, 200, 0]) * 512
        mid_row = (
            bytes([200, 200, 200, 0])
            + bytes([200, 200, 200, 255]) * 510
            + bytes([200, 200, 200, 0])
        )
        write_png_rows(path, 512, 512, 6, top_row, mid_row)
        self.manifest["entries"].append(
            entry("dog_egg", "app/assets/images/pets/dog_egg.png",
                  kind="pet", form="any", layer=None, recolorable=False)
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    def test_svg_icon_passes(self):
        path = self.root / "app/assets/images/area_logic.svg"
        path.write_text('<svg xmlns="http://www.w3.org/2000/svg"/>',
                        encoding="utf-8")
        self.manifest["entries"].append(
            entry("area_logic", "app/assets/images/area_logic.svg",
                  kind="icon", form="any", layer=None, recolorable=False)
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    def _add_background_png(self, eid="room_v2", color_type=2):
        """Nền PNG đặc 1600x900 (không pixel trong suốt): đúng hợp
        đồng A1 (đường đưa ảnh base64 chỉ nhận PNG)."""
        path = self.root / f"app/assets/images/backgrounds/{eid}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        if color_type == 2:
            write_png(path, 1600, 900, 2, lambda x, y: (250, 220, 230))
        else:
            write_png(path, 1600, 900, 6,
                      lambda x, y: (250, 220, 230, 255))
        self.manifest["entries"].append(
            entry(eid, f"app/assets/images/backgrounds/{eid}.png",
                  kind="background", form="any", layer=None,
                  recolorable=False)
        )
        return path

    def test_png_background_rgb_passes(self):
        # Nền PNG RGB đặc (không kênh alpha) vẫn qua được.
        self._add_background_png(color_type=2)
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    def test_png_background_rgba_passes(self):
        # Nền PNG RGBA đặc (alpha toàn 255) vẫn qua được.
        self._add_background_png(color_type=6)
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    def test_background_gif_name_fails(self):
        self._add_background_png()
        self.manifest["entries"][0]["file"] = (
            "app/assets/images/backgrounds/room_v2.gif"
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("sai quy tắc đặt tên" in e for e in errors),
                        errors)

    def _add_town_layer(self, eid="cloud_01", w=512, h=512):
        """Lớp động thị trấn: PNG trong suốt 512x512 ở thư mục town/."""
        path = self.root / f"app/assets/images/town/{eid}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([255, 255, 255, 0]) * w
        mid_row = (
            bytes([255, 255, 255, 0])
            + bytes([255, 255, 255, 255]) * (w - 2)
            + bytes([255, 255, 255, 0])
        )
        write_png_rows(path, w, h, 6, top_row, mid_row)
        self.manifest["entries"].append(
            entry(eid, f"app/assets/images/town/{eid}.png",
                  kind="town_layer", form="any", layer=None,
                  recolorable=False)
        )
        return path

    def test_town_layer_valid_passes(self):
        self._add_town_layer()
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    def test_town_layer_wrong_dir_fails(self):
        # Lớp động thị trấn phải nằm trong thư mục town/, không phải
        # furniture/ (cùng khung 512x512 nhưng khác loại).
        self._add_town_layer()
        self.manifest["entries"][0]["file"] = (
            "app/assets/images/furniture/cloud_01.png"
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("phải nằm trong thư mục" in e for e in errors),
                        errors)

    def test_town_layer_wrong_size_fails(self):
        self._add_town_layer(w=256, h=256)
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("sai kích thước khung" in e for e in errors),
                        errors)


if __name__ == "__main__":
    unittest.main(verbosity=2)
