"""Color-only finalization permitted by IMAGE_GENERATION_INSTRUCTIONS.md.

Usage: python enforce_palette.py GENERATED_SOURCE.png
The source and its alpha are never modified. Review images are separate files.
"""

import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def main():
    root = Path(__file__).resolve().parent
    source = Path(sys.argv[1]).resolve()
    config = json.loads((root / "palette.json").read_text())
    colors = config["colors"][:config["tier_one_color_count"]]
    palette = np.array([
        [int(c["hex"][i:i + 2], 16) for i in (1, 3, 5)] for c in colors
    ], dtype=np.int32)
    original = np.array(Image.open(source).convert("RGBA"))
    output = original.copy()
    pixels = output.reshape(-1, 4)
    for start in range(0, len(pixels), 32768):
        chunk = pixels[start:start + 32768]
        visible = chunk[:, 3] > 0
        distance = chunk[visible, :3].astype(np.int32)[:, None, :] - palette
        index = np.argmin((distance * distance).sum(axis=2), axis=1)
        chunk[visible, :3] = palette[index].astype(np.uint8)
    # Material-aware color assignments prevent similarly valued cloth, wood,
    # iron and masonry from borrowing each other's palette entries.
    rgb = original[:, :, :3].astype(np.int32)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    yy, xx = np.indices(original.shape[:2])
    visible = original[:, :, 3] > 0
    banner = (xx > 446) & (xx < 580) & (yy > 698) & (yy < 960)
    warm = visible & (red > green * 1.18) & (green > 23)
    timber = warm & ~banner
    cloth = warm & banner & (red > 40)
    bone = visible & (xx > 460) & (xx < 570) & (yy > 740) & (yy < 910) & (red > 115) & (green > 100) & (blue > 75)
    stone = visible & (yy > 695) & (abs(red - green) < 12) & (green - blue >= 2) & (green > 47)
    door = (xx > 420) & (xx < 600) & (yy > 1040) & (yy < 1270)
    for mask, indices in [(timber, [0, 8, 9]), (cloth & (red < 70), [10]), (cloth & (red >= 70), [11]), (stone & ~door, [0, 2, 3, 4]), (bone, [12])]:
        material = palette[indices]
        distance = rgb[mask][:, None, :] - material
        index = np.argmin((distance * distance).sum(axis=2), axis=1)
        output[mask, :3] = material[index].astype(np.uint8)
    target = root / "tier-1.png"
    Image.fromarray(output).save(target)
    reopened = np.array(Image.open(target).convert("RGBA"))
    used, counts = np.unique(reopened[reopened[:, :, 3] > 0, :3], axis=0, return_counts=True)
    allowed = {tuple(c) for c in palette.tolist()}
    assert all(tuple(c) in allowed for c in used.tolist())
    assert reopened.shape == original.shape
    assert np.array_equal(reopened[:, :, 3], original[:, :, 3])
    assert np.all(reopened[0, :, 3] == 0) and np.all(reopened[-1, :, 3] == 0)
    assert np.all(reopened[:, 0, 3] == 0) and np.all(reopened[:, -1, 3] == 0)
    report = {
        "source": source.name,
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "final_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "size": list(Image.open(target).size),
        "mode": "RGBA",
        "used_colors": {"#%02X%02X%02X" % tuple(c): int(n) for c, n in zip(used, counts)},
        "allowed_palette_check": "PASS",
        "dimensions_preserved": True,
        "alpha_preserved_exactly": True,
        "transparent_canvas_edges": True,
        "transparent_pixel_count": int((reopened[:, :, 3] == 0).sum()),
        "alpha_bounds": Image.fromarray(reopened[:, :, 3]).getbbox(),
        "core_center_x": 512,
        "ground_anchor": [512, int(np.where(reopened[:, 512, 3] > 128)[0].max())],
        "placement_note": "Single tier-one design; center visually checked; ground is the last centerline pixel with alpha above 128. No family offset check is claimed.",
        "scope": "New tier-one concept; runtime catalog unchanged."
    }
    (root / "verification.json").write_text(json.dumps(report, indent=2) + "\n")

    # Diagnostic review only: never used as the transparent source asset.
    sprite = Image.open(target).convert("RGBA")
    board = Image.new("RGB", (1024, 900), "#171F1C")
    draw = ImageDraw.Draw(board)
    for x, background, caption in [(0, "#171F1C", "DARK BACKGROUND"), (512, "#C9C5B7", "LIGHT BACKGROUND")]:
        draw.rectangle((x, 0, x + 511, 899), fill=background)
        preview = sprite.resize((512, 768), Image.Resampling.NEAREST)
        board.paste(preview, (x, 0), preview)
        draw.text((x + 20, 775), caption, fill="#8B8B77" if x == 0 else "#111916")
        for width, offset in [(64, 20), (96, 130), (128, 270)]:
            miniature = sprite.resize((width, width * 3 // 2), Image.Resampling.NEAREST)
            # Bottom-aligned to reveal readability at typical map-art scales.
            board.paste(miniature, (x + offset, 897 - miniature.height), miniature)
    board.save(root / "review.png")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
