#!/usr/bin/env python3
"""Test cho tools/assets/check_assets.py (cần Pillow).

Chạy:  python3 tools/assets/check_assets_test.py
Mỗi test dựng một cây repo tạm (manifest + vài file hình) rồi gọi
Checker trên đó. Ảnh WebP lossless mẫu được ghi bằng Pillow.
"""

import json
import pathlib
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from check_assets import Checker  # noqa: E402


def write_png(path: pathlib.Path, width: int, height: int,
              color_type: int, pixel) -> None:
    """Ghi WebP lossless. pixel(x, y) trả tuple RGB hoặc RGBA; color_type
    2 = RGB (không alpha), còn lại = RGBA. Tên hàm giữ từ thời PNG."""
    mode = "RGB" if color_type == 2 else "RGBA"
    img = Image.new(mode, (width, height))
    img.putdata([tuple(pixel(x, y)) for y in range(height)
                 for x in range(width)])
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "WEBP", lossless=True, exact=True)


def write_png_rows(path: pathlib.Path, width: int, height: int,
                   color_type: int, top_row: bytes, mid_row: bytes) -> None:
    """Ghi WebP RGBA từ 2 hàng mẫu (hàng viền + hàng giữa) — nhanh cho
    ảnh đúng khung 1024x1536/512x512. Hàng dưới = hàng viền. color_type
    4 = hàng mẫu dạng xám+alpha (2 byte/pixel)."""
    if color_type == 4:
        def expand(row):
            return b"".join(
                bytes([row[i], row[i], row[i], row[i + 1]])
                for i in range(0, len(row), 2)
            )
        top_row, mid_row = expand(top_row), expand(mid_row)
    assert len(top_row) == width * 4 and len(mid_row) == width * 4
    raw = top_row + mid_row * (height - 2) + top_row
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.frombytes("RGBA", (width, height), raw).save(
        path, "WEBP", lossless=True, exact=True
    )


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
        path = self.root / f"app/assets/images/character/girl/{eid}.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 200, 200, 0]) * w
        mid_row = (
            bytes([200, 200, 200, 0])
            + bytes([200, 200, 200, 255]) * (w - 2)
            + bytes([200, 200, 200, 0])
        )
        write_png_rows(path, w, h, 6, top_row, mid_row)
        self.manifest["entries"].append(
            entry(eid, f"app/assets/images/character/girl/{eid}.webp")
        )
        return path

    def test_valid_tree_passes(self):
        self.add_valid_top()
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    def test_opaque_webp_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.webp"
        write_png(path, 1024, 1536, 6, lambda x, y: (200, 200, 200, 255))
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.webp")
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
        path = self.root / "app/assets/images/character/girl/girl_top_01.webp"
        write_png(path, 64, 64, 6, pixel)
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.webp")
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

    def test_jpeg_bytes_as_webp_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.webp")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("không phải file WebP" in e for e in errors),
                        errors)

    def test_webp_without_alpha_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.webp"
        write_png(path, 16, 16, 2, lambda x, y: (200, 200, 200))
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.webp")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("kênh alpha" in e for e in errors), errors)

    def test_colored_recolorable_layer_fails(self):
        # Ảnh đúng khung, viền trong suốt, một pixel đỏ chói ở giữa.
        path = self.root / "app/assets/images/character/girl/girl_top_01.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 200, 200, 0]) * 1024
        mid = bytearray(bytes([200, 200, 200, 255]) * 1024)
        mid[0:4] = bytes([200, 200, 200, 0])
        mid[-4:] = bytes([200, 200, 200, 0])
        mid[4:8] = bytes([255, 0, 0, 255])  # đỏ chói, không phải xám
        write_png_rows(path, 1024, 1536, 6, top_row, bytes(mid))
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.webp")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("phải tô xám" in e for e in errors), errors)

    def test_gray_alpha_webp_passes(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 0]) * 1024
        mid_row = bytes([200, 0]) + bytes([200, 255]) * 1022 + bytes([200, 0])
        write_png_rows(path, 1024, 1536, 4, top_row, mid_row)
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.webp")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    # -- Đường giải lọc nhanh / không giải đủ ---------------------------

    def test_missing_ready_file_fails(self):
        self.manifest["entries"].append(
            entry("girl_top_01",
                  "app/assets/images/character/girl/girl_top_01.webp")
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
        orphan = self.root / "app/assets/images/pets/dog_egg.webp"
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
                  "app/assets/images/character/girl/girl_top_02.webp")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("mã trùng nhau" in e for e in errors), errors)

    def test_line_without_base_fails(self):
        path = self.root / "app/assets/images/character/girl/girl_top_01_line.webp"
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
                  "app/assets/images/character/girl/girl_top_01_line.webp",
                  recolorable=False, line=True)
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("thiếu file gốc" in e for e in errors), errors)

    def test_incomplete_hair_set_fails(self):
        back = self.root / "app/assets/images/character/girl/girl_hair_back_01.webp"
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
                  "app/assets/images/character/girl/girl_hair_back_01.webp",
                  layer="hair_back", set_="girl_hair_01")
        )
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 1)
        self.assertTrue(any("bộ tóc" in e for e in errors), errors)

    def test_pet_frame_passes(self):
        path = self.root / "app/assets/images/pets/dog_egg.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([200, 200, 200, 0]) * 512
        mid_row = (
            bytes([200, 200, 200, 0])
            + bytes([200, 200, 200, 255]) * 510
            + bytes([200, 200, 200, 0])
        )
        write_png_rows(path, 512, 512, 6, top_row, mid_row)
        self.manifest["entries"].append(
            entry("dog_egg", "app/assets/images/pets/dog_egg.webp",
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

    def _add_background_webp(self, eid="room_v2", color_type=2):
        """Nền PNG đặc 1600x900 (không pixel trong suốt): đúng hợp
        đồng A1 (đường đưa ảnh base64 chỉ nhận PNG)."""
        path = self.root / f"app/assets/images/backgrounds/{eid}.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        if color_type == 2:
            write_png(path, 1600, 900, 2, lambda x, y: (250, 220, 230))
        else:
            write_png(path, 1600, 900, 6,
                      lambda x, y: (250, 220, 230, 255))
        self.manifest["entries"].append(
            entry(eid, f"app/assets/images/backgrounds/{eid}.webp",
                  kind="background", form="any", layer=None,
                  recolorable=False)
        )
        return path

    def test_webp_background_rgb_passes(self):
        # Nền PNG RGB đặc (không kênh alpha) vẫn qua được.
        self._add_background_webp(color_type=2)
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    def test_webp_background_rgba_passes(self):
        # Nền PNG RGBA đặc (alpha toàn 255) vẫn qua được.
        self._add_background_webp(color_type=6)
        self.write_manifest()
        code, errors = self.run_checker()
        self.assertEqual(code, 0, errors)

    def test_background_gif_name_fails(self):
        self._add_background_webp()
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
        path = self.root / f"app/assets/images/town/{eid}.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        top_row = bytes([255, 255, 255, 0]) * w
        mid_row = (
            bytes([255, 255, 255, 0])
            + bytes([255, 255, 255, 255]) * (w - 2)
            + bytes([255, 255, 255, 0])
        )
        write_png_rows(path, w, h, 6, top_row, mid_row)
        self.manifest["entries"].append(
            entry(eid, f"app/assets/images/town/{eid}.webp",
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
            "app/assets/images/furniture/cloud_01.webp"
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
