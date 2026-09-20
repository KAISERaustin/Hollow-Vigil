"""Deterministic palette enforcement and locked-layer assembly for this commission.

ImageGen creates all artwork. This script only selects generated addition layers,
composites them over the preceding stage, applies the selected palette without
dithering, and makes review sheets. No generated source is resized or redrawn.
"""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PALETTE = json.loads((ROOT / "palette.json").read_text())["colors"]
RGB = np.array([tuple(bytes.fromhex(c["hex"][1:])) for c in PALETTE], dtype=np.int32)


def enforce(image, indices=range(13)):
    """Change RGB only, retaining alpha, coordinates and dimensions exactly."""
    data = np.array(image.convert("RGBA"))
    original_alpha = data[:, :, 3].copy()
    flat = data[:, :, :3].reshape(-1, 3)
    selected = RGB[list(indices)]
    for start in range(0, len(flat), 16384):
        pixels = flat[start:start + 16384].astype(np.int32)
        distance = ((pixels[:, None, :] - selected[None, :, :]) ** 2).sum(axis=2)
        flat[start:start + 16384] = selected[distance.argmin(axis=1)]
    assert np.array_equal(original_alpha, data[:, :, 3])
    return Image.fromarray(data)


def review(names, output="family-review.png"):
    width, height = 1700, 960
    sheet = Image.new("RGB", (width, height), "#1C2321")
    draw = ImageDraw.Draw(sheet)
    fonts = Path("C:/Windows/Fonts")
    title_font = ImageFont.truetype(str(fonts / "georgiab.ttf"), 37)
    label_font = ImageFont.truetype(str(fonts / "arial.ttf"), 21)
    small_font = ImageFont.truetype(str(fonts / "arial.ttf"), 17)
    draw.text((40, 24), "IRONSPIKE - THE SIEGE BALLISTA", font=title_font, fill="#C2B99F")
    draw.text((40, 81), "Original timber-and-iron defense  /  3 tiers + 2 final branches", font=label_font, fill="#929687")
    labels = ["Tier 1", "Tier 2 - Braced", "Tier 3 - Siege Frame", "Tier 4 - Bolt Battery", "Tier 4 - Breacher"]
    for i, name in enumerate(names):
        source = Image.open(ROOT / f"{name}.png").convert("RGBA")
        # Review derivatives only: final sprites retain their native dimensions.
        preview = source.resize((330, 330), Image.Resampling.LANCZOS)
        sheet.paste(preview, (25 + i * 330, 145), preview)
        draw.text((190 + i * 330, 495), labels[i], anchor="mm", font=label_font, fill="#C2B99F")
        for size, y in [(160, 562), (96, 775)]:
            thumbnail = source.resize((size, size), Image.Resampling.LANCZOS)
            sheet.paste(thumbnail, (190 + i * 330 - size // 2, y), thumbnail)
    draw.text((40, 926), "Same canvas and ground anchor in every sprite. Small rows show 160px and 96px canvases.", font=small_font, fill="#929687")
    sheet.save(ROOT / output)


def base(source):
    raw = Image.open(source).convert("RGBA")
    (ROOT / "sources").mkdir(exist_ok=True)
    raw.save(ROOT / "sources/tier-1-generated.png")
    result = enforce(raw)
    result.save(ROOT / "tier-1.png")
    alpha = np.array(result)[:, :, 3]
    print(json.dumps({"size": result.size, "alpha_bounds": result.getbbox(), "solid_bounds": Image.fromarray((alpha > 128).astype(np.uint8)).getbbox()}))
    review(["tier-1"], "base-review.png")


def assemble(name):
    spec = json.loads((ROOT / "layers.json").read_text())[name]
    parent = Image.open(ROOT / f'{spec["parent"]}.png').convert("RGBA")
    source = Image.open(ROOT / f"sources/{name}-generated.png").convert("RGBA")
    assert parent.size == source.size, "Do not resize artwork to repair alignment."
    if "canvas" in spec:
        padded_parent = Image.new("RGBA", tuple(spec["canvas"]))
        padded_parent.paste(parent, tuple(spec["parent_offset"]))
        parent = padded_parent
        padded_source = Image.new("RGBA", tuple(spec["canvas"]))
        padded_source.paste(source, tuple(spec["source_offset"]))
        source = padded_source
    if spec.get("offset", [0, 0]) != [0, 0]:
        translated = Image.new("RGBA", source.size)
        translated.paste(source, tuple(spec["offset"]))
        source = translated
    indices = list(range(13)) + spec.get("accents", [])
    source = enforce(source, indices)
    mask = Image.new("L", source.size)
    draw = ImageDraw.Draw(mask)
    for polygon in spec["polygons"]:
        draw.polygon([tuple(p) for p in polygon], fill=255)
    layer_data = np.array(source)
    layer_data[:, :, 3] = np.minimum(layer_data[:, :, 3], np.array(mask))
    if spec.get("protect_parent"):
        # The earlier weapon is in front of the rear reinforcement. Retain its
        # exact pixels by excluding it from the generated addition selection.
        layer_data[np.array(parent)[:, :, 3] > 0, 3] = 0
    layer = Image.fromarray(layer_data)
    (ROOT / "layers").mkdir(exist_ok=True)
    layer.save(ROOT / f"layers/{name}-addition.png")
    mask.save(ROOT / f"layers/{name}-selection-mask.png")
    assembled = Image.alpha_composite(parent, layer)
    final = enforce(assembled, indices)
    final.save(ROOT / f"{name}.png")
    print(f"Assembled {name} over locked {spec['parent']}; {np.count_nonzero(layer_data[:,:,3])} addition pixels")


def register_branches():
    parent = np.array(Image.open(ROOT / "top-3.png"), dtype=np.int32)
    yy, xx = np.mgrid[550:930:9, 70:1180:9]
    for name in ["top-4-bolt-battery", "top-4-breacher"]:
        child = np.array(enforce(Image.open(ROOT / f"sources/{name}-generated.png")), dtype=np.int32)
        scores = [(float(np.mean((parent[yy, xx] - child[yy + dy, xx + dx]) ** 2)), dx, dy)
                  for dy in range(130, 211) for dx in range(-4, 5)]
        print(name, sorted(scores)[:3])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["base", "assemble", "review", "register"])
    parser.add_argument("value", nargs="?")
    args = parser.parse_args()
    if args.action == "base":
        base(args.value)
    elif args.action == "assemble":
        assemble(args.value)
    elif args.action == "register":
        register_branches()
    else:
        review(["tier-1", "tier-2", "tier-3", "tier-4-bolt-battery", "tier-4-breacher"])
