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
    if spec.get("accent_polygons"):
        muted = np.array(enforce(source))
        accented = np.array(enforce(source, indices))
        accent_mask = Image.new("L", source.size)
        accent_draw = ImageDraw.Draw(accent_mask)
        for polygon in spec["accent_polygons"]:
            accent_draw.polygon([tuple(p) for p in polygon], fill=255)
        selected = np.array(accent_mask) > 0
        muted[selected] = accented[selected]
        source = Image.fromarray(muted)
    else:
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


NAMES = ["tier-1", "tier-2", "tier-3", "tier-4-bolt-battery", "tier-4-breacher"]
LABELS = ["Tier 1", "Tier 2 / Draw Winch", "Tier 3 / Siege Limbs", "Tier 4 / Bolt Battery", "Tier 4 / Breacher"]
PIVOT = (1024, 1024)
TOP_OFFSET = (397, 344)
BASE_OFFSET = (394, 316)


def pad(image, offset):
    result = Image.new("RGBA", (2048, 2048))
    result.paste(image, offset)
    return result


def export_parts():
    # Transparent padding and integer placement only; never resample artwork.
    base_image = pad(enforce(Image.open(ROOT / "base-1.png")), BASE_OFFSET)
    entries = {}
    for i, name in enumerate(NAMES):
        output = ROOT / "sprites" / name
        output.mkdir(parents=True, exist_ok=True)
        raw = Image.open(ROOT / f'top-{name.removeprefix("tier-")}.png').convert("RGBA")
        top = pad(raw, TOP_OFFSET) if raw.size == (1254, 1254) else raw
        indices = list(range(13)) + ([15] if i == 3 else [13, 14] if i == 4 else [])
        # Required last color pass uses the original base assignments, and
        # cannot repaint inherited materials because the layers retain them.
        enforce(base_image).save(output / "base.png")
        enforce(top, indices).save(output / "top.png")
        entries[name] = {"base": f"sprites/{name}/base.png", "top": f"sprites/{name}/top.png",
                         "accent_palette_indices": indices[13:]}
    metadata = {"canvas": [2048, 2048], "pivot": list(PIVOT), "core_center_x": 1024,
                "ground_anchor": [1024, 1442], "default_aim": [0, 1],
                "muzzle": [1024, 1183], "base_source_socket": [630, 708],
                "top_source_pivot": [627, 680], "base_translation": list(BASE_OFFSET),
                "top_translation": list(TOP_OFFSET), "parts": entries,
                "rotation": "Draw base fixed. Rotate top about pivot. For a target bearing measured from +X, use bearing - PI/2.",
                "scope": "Artwork package and offline previews; not wired into the runtime catalog."}
    (ROOT / "placement.json").write_text(json.dumps(metadata, indent=2) + "\n")


def final_reviews():
    fonts = Path("C:/Windows/Fonts")
    title = ImageFont.truetype(str(fonts / "georgiab.ttf"), 35)
    label = ImageFont.truetype(str(fonts / "arial.ttf"), 20)
    small = ImageFont.truetype(str(fonts / "arial.ttf"), 17)
    sheet = Image.new("RGB", (1700, 1080), "#1C2321")
    draw = ImageDraw.Draw(sheet)
    draw.text((32, 23), "IRONSPIKE - THE SIEGE BALLISTA", font=title, fill="#C2B99F")
    draw.text((32, 78), "Five stages / independent stationary base and rotating crossbow / original commission", font=label, fill="#929687")
    loaded = []
    crop = (350, 180, 1700, 1540)
    for i, name in enumerate(NAMES):
        folder = ROOT / "sprites" / name
        base_image = Image.open(folder / "base.png").convert("RGBA")
        top = Image.open(folder / "top.png").convert("RGBA")
        loaded.append((base_image, top))
        combined = Image.alpha_composite(base_image, top)
        large = combined.crop(crop).resize((330, 332), Image.Resampling.LANCZOS)
        sheet.paste(large, (25 + i * 330, 140), large)
        draw.text((190 + i * 330, 505), LABELS[i], font=label, anchor="mm", fill="#C2B99F")
        for source, y, caption in [(top, 540, "Rotating top"), (base_image, 720, "Fixed base")]:
            piece = source.crop(crop).resize((180, 181), Image.Resampling.LANCZOS)
            sheet.paste(piece, (100 + i * 330, y), piece)
            draw.text((190 + i * 330, y + 181), caption, font=small, anchor="mm", fill="#929687")
        tiny = combined.crop(crop).resize((96, 97), Image.Resampling.LANCZOS)
        sheet.paste(tiny, (142 + i * 330, 935), tiny)
    draw.text((32, 1050), "All delivered parts: 2048 x 2048 RGBA. Shared pivot: (1024, 1024). Bottom row: 96px review.", font=small, fill="#929687")
    sheet.save(ROOT / "family-review.png")

    grid = Image.new("RGB", (1600, 1110), "#1C2321")
    d = ImageDraw.Draw(grid)
    d.text((25, 18), "ROTATION CHECK - BASE FIXED", font=title, fill="#C2B99F")
    angles = [0, 45, 90, 135, 180, 225, 270, 315]
    for row, ((base_image, top), name) in enumerate(zip(loaded, NAMES)):
        for col, angle in enumerate(angles):
            rotating = top.rotate(-angle, Image.Resampling.BICUBIC, center=PIVOT)
            composite = Image.alpha_composite(base_image, rotating).resize((200, 200), Image.Resampling.LANCZOS)
            grid.paste(composite, (col * 200, 70 + row * 205), composite)
    grid.save(ROOT / "rotation-review.png")
    frames = []
    mini = [(b.resize((280, 280), Image.Resampling.LANCZOS), t.resize((280, 280), Image.Resampling.LANCZOS)) for b, t in loaded]
    for angle in range(0, 360, 10):
        frame = Image.new("RGB", (1400, 345), "#1C2321")
        d = ImageDraw.Draw(frame)
        for i, (base_image, top) in enumerate(mini):
            rotated = top.rotate(-angle, Image.Resampling.BICUBIC, center=(140, 140))
            combined = Image.alpha_composite(base_image, rotated)
            frame.paste(combined, (i * 280, 30), combined)
            d.text((140 + i * 280, 328), LABELS[i], font=small, anchor="mm", fill="#C2B99F")
        frames.append(frame)
    frames[0].save(ROOT / "rotation-preview.webp", save_all=True, append_images=frames[1:], duration=90, loop=0, lossless=True)


def verify_parts():
    report = {"passed": True, "parts": [], "rotation_angles_degrees": list(range(0, 360, 45))}
    base_reference = np.array(Image.open(ROOT / "sprites/tier-1/base.png"))
    top_reference = np.array(Image.open(ROOT / "sprites/tier-1/top.png"))
    for i, name in enumerate(NAMES):
        for kind in ["base", "top"]:
            path = ROOT / "sprites" / name / f"{kind}.png"
            image = Image.open(path).convert("RGBA")
            data = np.array(image)
            allowed = {tuple(row) for row in RGB[:13]}
            if kind == "top":
                allowed |= {tuple(RGB[j]) for j in ([15] if i == 3 else [13, 14] if i == 4 else [])}
            colors = {tuple(row) for row in np.unique(data[data[:, :, 3] > 0, :3], axis=0)}
            assert image.size == (2048, 2048)
            assert colors <= allowed, (name, kind, colors - allowed)
            assert not data[0, :, 3].any() and not data[-1, :, 3].any()
            assert not data[:, 0, 3].any() and not data[:, -1, 3].any()
            if kind == "base":
                assert np.array_equal(data, base_reference), "The stationary base must be identical at every tier."
                solid = Image.fromarray((data[:, :, 3] > 128).astype(np.uint8)).getbbox()
                assert solid[3] - 1 == 1442, solid
                inherited = "entire base is pixel-identical to tier 1"
                radius = None
            else:
                # This covers the complete lower bow/stock and its loaded bolt.
                assert np.array_equal(data[879:1304, 397:1651], top_reference[879:1304, 397:1651])
                yy, xx = np.where(data[:, :, 3] > 0)
                radius = float(np.sqrt((xx - 1024) ** 2 + (yy - 1024) ** 2).max())
                assert radius < 1023, (name, "rotation would clip", radius)
                inherited = "original lower bow, stock and loaded bolt are pixel-identical"
            report["parts"].append({"file": path.relative_to(ROOT).as_posix(), "color_count": len(colors),
                                    "unexpected_colors": 0, "canvas": list(image.size), "pivot": list(PIVOT),
                                    "ground_anchor": [1024, 1442], "inherited_pixels": inherited,
                                    "max_rotation_radius": radius, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    # Reconstruct each layer stack and compare its saved result, including alpha.
    specs = json.loads((ROOT / "layers.json").read_text())
    for name, spec in specs.items():
        parent = Image.open(ROOT / f'{spec["parent"]}.png').convert("RGBA")
        if "canvas" in spec:
            parent = pad(parent, tuple(spec["parent_offset"]))
        layer = Image.open(ROOT / f"layers/{name}-addition.png").convert("RGBA")
        expected = enforce(Image.alpha_composite(parent, layer), list(range(13)) + spec.get("accents", []))
        actual = Image.open(ROOT / f"{name}.png").convert("RGBA")
        assert np.array_equal(np.array(expected), np.array(actual)), name
    report["layer_reconstruction"] = "all four cumulative addition stacks match exactly"
    (ROOT / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print("PASS: 10 saved RGBA parts, exact palette, locked layers, shared core/ground alignment, full-circle canvas clearance")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["base", "assemble", "review", "register", "export", "verify", "final-reviews"])
    parser.add_argument("value", nargs="?")
    args = parser.parse_args()
    if args.action == "base":
        base(args.value)
    elif args.action == "assemble":
        assemble(args.value)
    elif args.action == "register":
        register_branches()
    elif args.action == "export":
        export_parts()
    elif args.action == "verify":
        verify_parts()
    elif args.action == "final-reviews":
        final_reviews()
    else:
        review(["tier-1", "tier-2", "tier-3", "tier-4-bolt-battery", "tier-4-breacher"])
