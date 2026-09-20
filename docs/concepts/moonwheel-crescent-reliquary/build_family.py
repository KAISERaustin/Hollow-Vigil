"""Reproduce palette enforcement and locked-layer assembly for Moonwheel.

ImageGen supplies all artwork. This script only selects generated addition layers,
maps RGB to the recorded palette, and preserves earlier layers without repainting.
"""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PALETTE = np.array([tuple(bytes.fromhex(p['hex'][1:])) for p in json.loads((ROOT / 'palette.json').read_text())], dtype=np.int32)
NAMES = ['tier-1', 'tier-2', 'tier-3', 'tier-4-reaping-arc', 'tier-4-oathbound-return']
LABELS = ['Tier 1', 'Tier 2', 'Tier 3', 'Tier 4 / Reaping Arc', 'Tier 4 / Oathbound Return']


def enforce(image):
    original = np.array(image.convert('RGBA'))
    result = original.copy()
    flat = result[:, :, :3].reshape(-1, 3)
    for start in range(0, len(flat), 32768):
        chunk = flat[start:start + 32768].astype(np.int32)
        distances = ((chunk[:, None, :] - PALETTE[None, :, :]) ** 2).sum(axis=2)
        flat[start:start + len(chunk)] = PALETTE[distances.argmin(axis=1)]
    assert np.array_equal(original[:, :, 3], result[:, :, 3])
    return Image.fromarray(result)


def verify(image):
    a = np.array(image.convert('RGBA'))
    colors = {tuple(c) for c in np.unique(a[a[:, :, 3] > 0, :3], axis=0)}
    allowed = {tuple(c) for c in PALETTE}
    assert colors <= allowed, colors - allowed
    return {'size': list(image.size), 'colors': len(colors), 'visible_bounds_alpha_128': list(Image.fromarray((a[:, :, 3] >= 128).astype(np.uint8)).getbbox())}


def map_region(result, source, mask, indices):
    colors = PALETTE[indices]
    pixels = source[:, :, :3][mask].astype(np.int32)
    mapped = np.empty_like(pixels)
    for start in range(0, len(pixels), 32768):
        chunk = pixels[start:start + 32768]
        distance = ((chunk[:, None, :] - colors[None, :, :]) ** 2).sum(axis=2)
        mapped[start:start + len(chunk)] = colors[distance.argmin(axis=1)]
    result[:, :, :3][mask] = mapped


def addition_materials(source, name):
    raw = np.array(source)
    result = np.array(enforce(source))
    r, g, b = (raw[:, :, i].astype(np.int32) for i in range(3))
    violet = (b > g + 8) & (r > g + 5) & (b >= r - 5)
    bronze = (r > g + 7) & (g > b + 12)
    neutral = ~(violet | bronze)
    if name == 'tier-2':
        map_region(result, raw, neutral, [0, 1, 5, 6, 7])
    elif name == 'tier-4-oathbound-return':
        map_region(result, raw, neutral, [0, 1, 2, 3, 4])
    elif name == 'tier-3':
        y = np.indices(raw.shape[:2])[0]
        map_region(result, raw, neutral & ((y < 626) | (y > 668)), [0, 1, 2, 3, 4])
        map_region(result, raw, neutral & (y >= 626) & (y <= 668), [0, 1, 5, 6, 7])
    elif name == 'tier-4-reaping-arc':
        map_region(result, raw, neutral, [0, 1, 5, 6, 7])
    map_region(result, raw, violet, [11, 12])
    map_region(result, raw, bronze, [13, 14, 10] if name == 'tier-4-reaping-arc' else [13, 14])
    assert np.array_equal(result[:, :, 3], raw[:, :, 3])
    return result


def assemble(name, parent_name, rectangles):
    parent = Image.open(ROOT / (parent_name + '.png')).convert('RGBA')
    source = Image.open(ROOT / 'sources' / (name + '.png')).convert('RGBA')
    assert source.size == parent.size, (source.size, parent.size)
    original = np.array(parent)
    generated = addition_materials(source, name)
    selection = np.zeros(original.shape[:2], dtype=bool)
    for left, top, right, bottom in rectangles:
        selection[top:bottom, left:right] = True
    # Keep only new structural silhouettes. Existing visible artwork is locked.
    # The faint (alpha < 16) background residues in generated images are not forms.
    selection &= (original[:, :, 3] < 16) & (generated[:, :, 3] >= 16)
    addition = generated.copy()
    addition[~selection] = 0
    (ROOT / 'layers').mkdir(exist_ok=True)
    (ROOT / 'masks').mkdir(exist_ok=True)
    Image.fromarray(addition).save(ROOT / 'layers' / (name + '.png'))
    Image.fromarray(selection.astype(np.uint8) * 255).save(ROOT / 'masks' / (name + '.png'))
    merged = np.array(enforce(Image.alpha_composite(parent, Image.fromarray(addition))))
    assert np.array_equal(merged[original[:, :, 3] >= 16], original[original[:, :, 3] >= 16])
    Image.fromarray(merged).save(ROOT / (name + '.png'))
    return verify(Image.open(ROOT / (name + '.png')))


def final_sweep():
    base = np.array(Image.open(ROOT / 'tier-1.png').convert('RGBA'))
    locked = base[:, :, 3] >= 16
    cap_x = np.flatnonzero(base[800, :, 3] >= 128)
    core_center = float((cap_x.min() + cap_x.max()) / 2)
    report = {'canvas': [1254, 1254], 'core_center_x': core_center, 'ground_anchor': [core_center, 1120],
              'core_measurement': {'cap_scanline_y': 800, 'left_x': int(cap_x.min()), 'right_x': int(cap_x.max())},
              'base_sha256': hashlib.sha256((ROOT / 'tier-1.png').read_bytes()).hexdigest(),
              'sources': 'Built-in ImageGen; only images newly generated for this commission', 'sprites': {}}
    for name in NAMES:
        path = ROOT / (name + '.png')
        before = np.array(Image.open(path).convert('RGBA'))
        corrected = np.array(enforce(Image.fromarray(before)))
        corrected[locked] = base[locked]
        assert np.array_equal(corrected[:, :, 3], before[:, :, 3])
        Image.fromarray(corrected).save(path)
        reopened = Image.open(path).convert('RGBA')
        a = np.array(reopened)
        entry = verify(reopened)
        entry['base_visible_pixels_changed'] = int(np.any(a[locked] != base[locked], axis=1).sum())
        entry['offset_xy'] = [0, 0]
        entry['ground_y'] = int(np.where(a[:, :, 3] >= 128)[0].max())
        assert entry['base_visible_pixels_changed'] == 0
        assert entry['ground_y'] == 1120
        entry['alpha_preserved_by_final_sweep'] = True
        entry['rgba_sha256'] = hashlib.sha256(a.tobytes()).hexdigest()
        if name != 'tier-1':
            parent_name = 'tier-3' if name.startswith('tier-4') else NAMES[NAMES.index(name) - 1]
            parent = np.array(Image.open(ROOT / (parent_name + '.png')).convert('RGBA'))
            parent_mask = parent[:, :, 3] >= 16
            entry['parent'] = parent_name
            entry['parent_visible_pixels_changed'] = int(np.any(a[parent_mask] != parent[parent_mask], axis=1).sum())
            assert entry['parent_visible_pixels_changed'] == 0
        report['sprites'][name] = entry
    (ROOT / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def reviews():
    font_path = 'C:/Windows/Fonts/georgia.ttf'
    title_font = ImageFont.truetype(font_path, 34)
    label_font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 19)
    small_font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 17)
    sheet = Image.new('RGBA', (1700, 710), '#1c2421')
    draw = ImageDraw.Draw(sheet)
    draw.text((35, 22), 'MOONWHEEL  /  THE CRESCENT RELIQUARY', font=title_font, fill='#dedbc2')
    draw.text((36, 70), 'Three tiers, two final branches  -  one locked base  -  sixteen shared colors', font=small_font, fill='#b8beb0')
    frames = []
    for i, (name, label) in enumerate(zip(NAMES, LABELS)):
        original = Image.open(ROOT / (name + '.png')).convert('RGBA')
        sheet.alpha_composite(original.resize((340, 340), Image.Resampling.LANCZOS), (i * 340, 100))
        draw.text((i * 340 + 170, 444), label, anchor='mt', font=label_font, fill='#dedbc2')
        draw.rectangle((i * 340 + 20, 490, i * 340 + 320, 665), fill='#b8beb0')
        sheet.alpha_composite(original.resize((160, 160), Image.Resampling.LANCZOS), (i * 340 + 90, 494))
        frame = Image.new('RGBA', (640, 700), '#b8beb0')
        frame.alpha_composite(original.resize((600, 600), Image.Resampling.LANCZOS), (20, 65))
        fd = ImageDraw.Draw(frame)
        fd.text((320, 20), label, anchor='mt', font=label_font, fill='#141a19')
        # Placement marker is fixed through every frame, outside the sprite.
        fd.line((285, 602, 355, 602), fill='#633d3b', width=1)
        frames.append(frame.convert('RGB'))
    draw.text((35, 679), 'Thumbnail check: 160 px canvases. Artwork remains at its original 1254 x 1254 resolution.', font=small_font, fill='#b8beb0')
    sheet.convert('RGB').save(ROOT / 'family-review.png')
    frames[0].save(ROOT / 'alignment-preview.webp', save_all=True, append_images=frames[1:], duration=900, loop=0, lossless=True)
    with zipfile.ZipFile(ROOT / 'moonwheel-all-tiers.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for filename in [n + '.png' for n in NAMES] + ['palette.json', 'README.md', 'verification.json', 'family-review.png', 'alignment-preview.webp']:
            archive.write(ROOT / filename, filename)
        for path in sorted((ROOT / 'prompts').glob('*.txt')):
            archive.write(path, path.relative_to(ROOT))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['base', 'tier-2', 'tier-3', 'branches', 'finish'])
    args = parser.parse_args()
    if args.command == 'base':
        image = enforce(Image.open(ROOT / 'sources/tier-1.png'))
        image.save(ROOT / 'tier-1.png')
        print(json.dumps(verify(Image.open(ROOT / 'tier-1.png'))))
    elif args.command == 'tier-2':
        print(json.dumps(assemble('tier-2', 'tier-1', [(270, 635, 542, 1090), (720, 635, 990, 1090)])))
    elif args.command == 'tier-3':
        print(json.dumps(assemble('tier-3', 'tier-2', [(335, 295, 515, 798), (765, 350, 925, 798)])))
    elif args.command == 'branches':
        print(json.dumps(assemble('tier-4-reaping-arc', 'tier-3', [(95, 195, 395, 675), (865, 195, 1165, 675)])))
        # Keep the new arch only; exclude the generator's vertically shifted core.
        print(json.dumps(assemble('tier-4-oathbound-return', 'tier-3', [(340, 60, 940, 350), (365, 350, 495, 415), (817, 350, 899, 420)])))
    elif args.command == 'finish':
        print(json.dumps(final_sweep(), indent=2))
        reviews()
