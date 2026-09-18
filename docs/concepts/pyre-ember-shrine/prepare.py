"""Assemble generated additions over locked pixels; enforce the family palette.

Run with the bundled Python (Pillow and numpy). No generated shape is redrawn
or resized. Review sheets alone use scaled copies. Sources remain untouched.
"""
from pathlib import Path
import json
import sys

import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PALETTE = np.array([tuple(bytes.fromhex(h[1:])) for h, _ in json.loads(
    (ROOT / 'palette.json').read_text())], dtype=np.int32)


def retain_asset(image):
    """Mask faint isolated extraction residue, retaining silhouette edge alpha."""
    rgba = np.array(image.convert('RGBA'))
    support = Image.fromarray(np.uint8(rgba[:, :, 3] >= 8) * 255)
    support = np.array(support.filter(ImageFilter.MaxFilter(5))) > 0
    rgba[~support] = 0
    return Image.fromarray(rgba)


def palette_sweep(image):
    rgba = np.array(image.convert('RGBA'))
    alpha = rgba[:, :, 3].copy()
    rgb = rgba[:, :, :3].reshape(-1, 3)
    for start in range(0, len(rgb), 65536):
        block = rgb[start:start + 65536].astype(np.int32)
        distance = ((block[:, None, :] - PALETTE[None, :, :]) ** 2).sum(2)
        rgb[start:start + len(block)] = PALETTE[distance.argmin(1)]
    assert np.array_equal(rgba[:, :, 3], alpha), 'Palette pass changed alpha'
    return Image.fromarray(rgba)


def finish_base():
    image = retain_asset(Image.open(ROOT / 'source/tier-1.png'))
    finished = palette_sweep(image)
    finished.save(ROOT / 'tier-1.png')
    finished.save(ROOT / 'layers/locked-tier-1.png')
    print('tier-1:', finished.size, finished.getbbox())


STAGES = {
    'tier-4-ember-censers': ('tier-3', [
        [(200, 390), (440, 390), (440, 685), (200, 685)],
        [(814, 390), (1045, 390), (1045, 685), (814, 685)],
    ]),
    'tier-4-flame-seal': ('tier-3', [
        [(300, 0), (950, 0), (950, 130), (300, 130)],
        [(300, 100), (555, 100), (555, 128), (431, 263),
         (431, 333), (489, 357), (489, 410), (452, 490), (300, 490)],
        [(700, 100), (950, 100), (950, 490), (803, 490),
         (765, 410), (765, 357), (821, 333), (821, 263), (700, 128)],
    ]),
    'tier-3': ('tier-2', [[(425, 140), (825, 140), (825, 415), (425, 415)]]),
    'tier-2': ('tier-1', [
        [(395, 330), (600, 330), (600, 455), (535, 455), (535, 750), (395, 750)],
        [(655, 330), (850, 330), (850, 750), (720, 750), (720, 455), (655, 455)],
    ]),
}


def assemble(name):
    parent_name, polygons = STAGES[name]
    parent = Image.open(ROOT / f'{parent_name}.png').convert('RGBA')
    source = retain_asset(Image.open(ROOT / f'source/{name}.png'))
    assert source.size == parent.size, 'Generation changed canvas dimensions'
    mask = Image.new('L', parent.size)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        draw.polygon(polygon, fill=255)
    addition = np.array(source)
    locked = np.array(parent)
    keep = (np.array(mask) > 0) & (locked[:, :, 3] == 0)
    addition[~keep] = 0
    addition = np.array(palette_sweep(Image.fromarray(addition)))
    addition[addition[:, :, 3] == 0] = 0
    Image.fromarray(addition).save(ROOT / f'layers/{name}-addition.png')
    Image.fromarray(np.uint8(keep & (addition[:, :, 3] > 0)) * 255).save(
        ROOT / f'layers/{name}-mask.png')
    result = locked.copy()
    result[keep] = addition[keep]
    assert np.array_equal(result[locked[:, :, 3] > 0], locked[locked[:, :, 3] > 0])
    Image.fromarray(result).save(ROOT / f'{name}.png')
    print(name, parent.size, Image.fromarray(result).getbbox())


NAMES = ['tier-1', 'tier-2', 'tier-3', 'tier-4-ember-censers', 'tier-4-flame-seal']
LABELS = ['TIER 1', 'TIER 2', 'TIER 3', 'TIER 4 / EMBER CENSERS', 'TIER 4 / FLAME SEAL']


def verify():
    """Final saved-file sweep, followed by a fresh reopen of every sprite."""
    base = np.array(Image.open(ROOT / 'layers/locked-tier-1.png').convert('RGBA'))
    visible_base = base[:, :, 3] > 0
    allowed = set(map(tuple, PALETTE))
    reports = []
    for name in NAMES:
        path = ROOT / f'{name}.png'
        before = np.array(Image.open(path).convert('RGBA'))
        final = np.array(palette_sweep(Image.fromarray(before)))
        # Tier one's corresponding material assignments are the final authority.
        final[visible_base] = base[visible_base]
        assert np.array_equal(final[:, :, 3], before[:, :, 3])
        Image.fromarray(final).save(path)
        saved = np.array(Image.open(path).convert('RGBA'))
        active = saved[:, :, 3] > 0
        colors = set(map(tuple, np.unique(saved[:, :, :3][active], axis=0)))
        assert colors <= allowed, name
        assert np.array_equal(saved[visible_base], base[visible_base]), name
        if name != 'tier-1':
            parent = np.array(Image.open(ROOT / f'{STAGES[name][0]}.png').convert('RGBA'))
            keep = parent[:, :, 3] > 0
            assert np.array_equal(saved[keep], parent[keep]), name
        threshold_bbox = Image.fromarray(np.uint8(saved[:, :, 3] >= 8)).getbbox()
        assert threshold_bbox[3] == 1130, (name, threshold_bbox)
        assert not saved[0, :, 3].any() and not saved[-1, :, 3].any()
        assert not saved[:, 0, 3].any() and not saved[:, -1, 3].any()
        reports.append({
            'file': path.name, 'dimensions': [saved.shape[1], saved.shape[0]],
            'nontransparent_rgb_count': len(colors), 'palette_valid': True,
            'tier_one_pixels_changed': 0, 'preceding_tier_pixels_changed': 0,
            'core_offset_from_tier_one_px': [0, 0],
            'ground_anchor_px': [627, 1130], 'visible_alpha_bbox': threshold_bbox,
            'alpha_unchanged_by_final_palette_sweep': True,
        })
    (ROOT / 'verification.json').write_text(json.dumps({
        'scope': 'Generated art only; no game renderer or gameplay changes.',
        'canvas': [1254, 1254], 'core_center_px': [627, 901],
        'ground_anchor_px': [627, 1130], 'palette': json.loads(
            (ROOT / 'palette.json').read_text()), 'files': reports,
    }, indent=2) + '\n')
    print(json.dumps(reports, indent=2))


def reviews():
    sheet = Image.new('RGB', (1800, 790), '#1C2320')
    draw = ImageDraw.Draw(sheet)
    font_path = 'C:/Windows/Fonts/arial.ttf'
    title_font = ImageFont.truetype(font_path, 32)
    label_font = ImageFont.truetype(font_path, 18)
    small_font = ImageFont.truetype(font_path, 15)
    draw.text((32, 20), 'PYRE / THE EMBER SHRINE', font=title_font, fill='#E0D8BC')
    draw.text((32, 64), 'Three cumulative tiers. Two independent final branches.',
              font=label_font, fill='#B7BBAE')
    frames = []
    for index, (name, label) in enumerate(zip(NAMES, LABELS)):
        source = Image.open(ROOT / f'{name}.png').convert('RGBA')
        x = 22 + index * 355
        draw.rounded_rectangle((x, 110, x + 335, 578), radius=4, fill='#94998C')
        # Identical view window and scale for all five review images.
        display = source.crop((160, 0, 1094, 1160)).resize((320, 397), Image.Resampling.LANCZOS)
        sheet.paste(display, (x + 8, 122), display)
        draw.text((x + 167, 546), label, anchor='mm', font=label_font, fill='#151A17')
        thumb = source.resize((128, 128), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x + 102, 602), thumb)
        frame = Image.new('RGBA', source.size, '#94998C')
        frame.alpha_composite(source)
        frames.append(frame.resize((627, 627), Image.Resampling.LANCZOS))
    draw.text((32, 602), 'SMALL SIZE', font=small_font, fill='#B7BBAE')
    draw.text((32, 756), '16 shared colors / fixed core and ground anchor / locked original base',
              font=label_font, fill='#B7BBAE')
    sheet.save(ROOT / 'family-review.png')
    frames[0].save(ROOT / 'alignment-preview.webp', save_all=True, append_images=frames[1:],
                   duration=900, loop=0, lossless=True)
    light = Image.new('RGB', (1800, 420), '#E6E4D8')
    for index, name in enumerate(NAMES):
        sprite = Image.open(ROOT / f'{name}.png').convert('RGBA')
        sprite = sprite.resize((400, 400), Image.Resampling.LANCZOS)
        light.paste(sprite, (index * 350 - 15, 0), sprite)
    light.save(ROOT / 'transparency-review.png')


if __name__ == '__main__':
    if sys.argv[1:] == ['base']:
        finish_base()
    elif len(sys.argv) == 2 and sys.argv[1] in STAGES:
        assemble(sys.argv[1])
    elif sys.argv[1:] == ['finish']:
        verify()
        reviews()
