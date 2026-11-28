#!/usr/bin/env python3
"""Kiểm tra hình đầu vào theo hợp đồng trong ``assets/manifest.json``.

Hợp đồng (xem ``docs/ASSETS.md``): khung nhân vật 1024x1536, pet/đồ vật/
nội thất/lớp động thị trấn 512x512, nền JPEG hoặc WebP, tên file
``<dáng>_<lớp>_<tên món>.webp``,
lớp đổi màu tô xám để app nhân màu, chi tiết không đổi màu đi file
riêng đuôi ``_line``, thứ tự chồng 8 lớp từ tóc sau lên phụ kiện.

Script kiểm tra:
  - manifest đúng lược đồ (lớp, trường bắt buộc, tên file khớp mã);
  - file trạng thái ``ready`` phải tồn tại và đúng nội dung: WebP đúng
    kích thước khung, có kênh alpha, có ít nhất một pixel trong suốt
    (kể cả ở viền), lớp đổi màu phải tô xám; riêng nền WebP thì không
    yêu cầu alpha (nền đặc, không chồng lớp);
  - file trạng thái ``planned`` chưa được có mặt (có rồi thì đổi
    status thành ``ready``);
  - mọi file hình trong ``app/assets/images/`` đều phải có dòng
    manifest tương ứng (trừ thư mục ``_incoming/``).

Cách dùng:
    python3 tools/assets/check_assets.py [--root <gốc repo>]
Trả 0 khi mọi kiểm tra qua, 1 khi có lỗi. Cần Pillow để đọc điểm ảnh WebP
(ảnh trong app/assets/images/ là WebP lossless, xem png_to_webp.py).
"""

import argparse
import json
import pathlib
import re
import sys

try:  # Pillow chỉ cần để đọc điểm ảnh WebP
    from PIL import Image, ImageChops
except ImportError:  # pragma: no cover
    Image = ImageChops = None

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
    "town_building",
    "ui",
    "resident",
    "sticker",
    "unlock",
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
    "resident": (512, 512),
    "sticker": (512, 512),  # riêng bìa sổ 1024x512 và khung vàng: trường "frame"
}

# Tên file cho từng loại (chỉ tên file, không tính thư mục — thư mục
# kiểm riêng trong _check_entry_name).
NAME_PATTERNS = {
    "character_layer": re.compile(
        r"^(girl|boy)_"
        r"(hair_back|body|shoes|bottom|top|eyes|mouth|hair_front"
        r"|accessory_head|accessory_hand)"
        r"_[a-z0-9]+(_line)?\.webp$"
    ),
    # Ảnh toàn thân 3 bộ × (nghỉ/vẫy) và phụ kiện phủ cùng khung (E).
    "character_full": re.compile(
        r"^(girl|boy)_(full_(0[1-9]|1[01])(_wave|_walk_(dr|ur)_[a-d])?(_backpack)?"
        r"|hat_01|bow_01|clip_01"
        r"|glasses_01|backpack_01|shoes_02)\.webp$"
    ),
    "character_patch": re.compile(
        r"^(girl|boy)_eyes_closed_patch(_0[1-3]_wave)?\.webp$"
    ),
    # Ảnh giai đoạn + trứng nứt/vỏ (lô 8A) + khung đi/vui/ngồi (lô 8B).
    "pet": re.compile(
        r"^(dog|cat|rabbit|squirrel|capybara|dragon)_("
        r"egg|newborn|teen|adult"
        r"|egg_crack_[1-3]|shell_(top|bottom)"
        r"|(newborn|teen|adult)_(walk_[a-d]|happy|sit)"
        r"|(fire|water)_[1-4]|fly_[a-d]|aura"
        r")\.webp$"
    ),
    "item": re.compile(r"^[a-z0-9_]+\.webp$"),
    "furniture": re.compile(r"^[a-z0-9_]+\.webp$"),
    "background": re.compile(r"^[a-z0-9_]+\.(jpg|jpeg|webp)$"),
    "icon": re.compile(r"^[a-z0-9_]+\.svg$"),
    "town_layer": re.compile(r"^[a-z0-9_]+\.webp$"),
    # Hình giao diện kiểu game (lô 6, 21/11): nút, icon, biển, logo,
    # nền màn chờ/mở đầu; mỗi hình một cỡ riêng nên không kiểm khung.
    # Công trình thêm lên bản đồ Thị trấn (lô 11: Đấu trường), mỗi
    # tòa một cỡ nên không kiểm khung.
    "town_building": re.compile(r"^[a-z0-9_]+_building\.webp$"),
    # Huy chương Đấu trường (lô 11) cũng thuộc loại ui.
    "ui": re.compile(r"^(ui|medal)_[a-z0-9_]+\.webp$"),
    # Lô 17 (bản 0.4): cư dân, sổ sticker, đồ mở khóa.
    "resident": re.compile(r"^[a-z_]+_(portrait|talk)\.webp$"),
    "sticker": re.compile(
        r"^(sticker_(frame|base)_[a-z]+|sticker_locked|sticker_book_cover"
        r"|form_[a-z0-9_]+)\.webp$"
    ),
    "unlock": re.compile(
        r"^(sticker_book_gold_frame|town_fountain|title_badge)\.webp$"
    ),
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
    "ui": "ui",
    "town_building": "town",
    "resident": "residents",
    "sticker": "stickers",
    "unlock": "unlocks",
}

IMAGE_EXTS = {".png", ".webp", ".jpg", ".jpeg", ".svg"}

# Pixel đổi màu phải gần như xám tuyệt đối (R, G, B lệch nhau tối đa
# chừng này mới nhân màu không bị ám màu).
GRAY_TOLERANCE = 8

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

    # -- WebP (cần Pillow để giải mã điểm ảnh) ------------------------------

    def _open_webp(self, path: pathlib.Path, where: str):
        """Mở ảnh WebP, trả về ảnh RGBA đã nạp; lỗi thì ghi và trả None."""
        if Image is None:
            raise SystemExit(
                "Thiếu Pillow để đọc WebP: pip install pillow"
            )
        data = path.read_bytes()
        if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
            self.fail(where, "không phải file WebP thật")
            return None, None
        try:
            with Image.open(path) as im:
                if im.format != "WEBP":
                    self.fail(where, "không phải file WebP thật")
                    return None, None
                has_alpha = "A" in im.getbands() or im.mode == "P"
                rgba = im.convert("RGBA")
                rgba.load()
        except Exception as exc:  # noqa: BLE001
            self.fail(where, f"không giải mã được WebP: {exc}")
            return None, None
        return rgba, has_alpha

    def _check_webp(self, entry: dict, path: pathlib.Path,
                    require_alpha: bool = True) -> None:
        where = entry["file"]
        rgba, has_alpha = self._open_webp(path, where)
        if rgba is None:
            return
        width, height = rgba.size
        frame = FRAMES.get(entry["kind"])
        # Nội thất lớn (lô 15) có khung riêng: trường "frame": [rộng, cao].
        if entry.get("frame"):
            frame = tuple(entry["frame"])
        if frame is not None and (width, height) != frame:
            # Ghi lỗi nhưng vẫn kiểm tiếp độ trong suốt/xám để người
            # cắt thấy hết lỗi trong một lần chạy.
            self.fail(
                where,
                f"sai kích thước khung: {width}x{height}, "
                f"loại {entry['kind']} phải là {frame[0]}x{frame[1]}",
            )
        if not require_alpha:
            return  # nền đặc: không cần kênh alpha
        if not has_alpha:
            self.fail(
                where,
                "WebP không có pixel trong suốt nào (nền đặc, không có "
                "kênh alpha)",
            )
            return
        alpha = rgba.getchannel("A")
        # Ít nhất một pixel trong suốt (ảnh không được là nền đặc) và
        # ít nhất một pixel trong suốt ở viền (lớp phải nằm trong khung,
        # không chạm mép an toàn).
        if alpha.getextrema()[0] == 255:
            self.fail(where, "WebP không có pixel trong suốt nào (nền đặc)")
            return
        edges = (
            alpha.crop((0, 0, width, 1)),
            alpha.crop((0, height - 1, width, height)),
            alpha.crop((0, 0, 1, height)),
            alpha.crop((width - 1, 0, width, height)),
        )
        if min(e.getextrema()[0] for e in edges) == 255:
            self.fail(
                where,
                "WebP không có pixel trong suốt ở viền — hình chạm mép "
                "khung, xem lại mép an toàn trong assets/templates/",
            )
            return
        # Lớp đổi màu phải tô xám (app nhân màu lên lớp xám): mọi pixel
        # còn thấy được (alpha > 0) có R, G, B lệch nhau tối đa
        # GRAY_TOLERANCE.
        if entry.get("recolorable"):
            r, g, b, _ = rgba.split()
            spread = ImageChops.lighter(
                ImageChops.lighter(
                    ImageChops.difference(r, g), ImageChops.difference(g, b)
                ),
                ImageChops.difference(r, b),
            )
            visible = alpha.point(lambda v: 255 if v > 0 else 0)
            bad = ImageChops.multiply(
                spread.point(lambda v: 255 if v > GRAY_TOLERANCE else 0),
                visible,
            )
            if bad.getbbox() is not None:
                i = bad.tobytes().find(b"\xff")
                x, y = i % width, i // width
                pr, pg, pb, _ = rgba.getpixel((x, y))
                self.fail(
                    where,
                    "lớp đổi màu phải tô xám (R, G, B gần bằng nhau) "
                    f"để app nhân màu được; pixel ({x}, {y}) có màu "
                    f"({pr}, {pg}, {pb})",
                )

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
            if entry["file"].endswith(".webp"):
                # Nền màn chờ/mở đầu của lô 6 (ui_*_bg) là ảnh nền kín
                # như nền phòng: kiểm như background (không cần alpha).
                solid = entry["kind"] == "background" or (
                    entry["kind"] == "ui" and entry["id"].endswith("_bg")
                ) or entry["id"] == "sticker_book_cover"
                self._check_webp(entry, path, require_alpha=not solid)
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
