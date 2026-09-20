"""Palette, explicit addition masks, locked layers, and saved-file verification.

ImageGen draws all artwork. This script only performs the mask/composite,
translation, and palette operations required by IMAGE_GENERATION_INSTRUCTIONS.md.
"""
from pathlib import Path
import argparse
import json
import shutil
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
PALETTE = json.loads((ROOT / 'palette.json').read_text())
RGB = np.array([tuple(bytes.fromhex(c['hex'][1:])) for c in PALETTE['colors']], dtype=np.int32)


def palette_sweep(image, branch=False):
    pixels = np.array(image.convert('RGBA'))
    alpha = pixels[:, :, 3].copy()
    colors = RGB if branch else RGB[:-1]
    flat = pixels[:, :, :3].reshape(-1, 3)
    for offset in range(0, len(flat), 65536):
        chunk = flat[offset:offset + 65536].astype(np.int32)
        indices = ((chunk[:, None, :] - colors[None, :, :]) ** 2).sum(2).argmin(1)
        flat[offset:offset + len(chunk)] = colors[indices]
    assert np.array_equal(alpha, pixels[:, :, 3])
    return Image.fromarray(pixels)


def isolate(image):
    """Retain the structural component plus original soft boundary alpha."""
    alpha = np.array(image.getchannel('A'))
    occupied = alpha > 16
    ys, xs = np.where(occupied)
    seed = (int(ys[len(ys) // 2]), int(xs[len(xs) // 2]))
    h, w = occupied.shape
    visited = np.zeros_like(occupied)
    pending = deque([seed])
    visited[seed] = True
    while pending:
        y, x = pending.popleft()
        for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= yy < h and 0 <= xx < w and occupied[yy, xx] and not visited[yy, xx]:
                visited[yy, xx] = True
                pending.append((yy, xx))
    support = Image.fromarray((visited * 255).astype('uint8')).filter(ImageFilter.MaxFilter(9))
    out = np.array(image)
    out[np.array(support) == 0] = 0
    return Image.fromarray(out)


def translate(image, dx, dy, size=None):
    target = Image.new('RGBA', size or image.size)
    target.paste(image, (dx, dy))
    return target


def prepare_base(source):
    (ROOT / 'sources').mkdir(exist_ok=True)
    if Path(source).resolve() != ROOT / 'sources/tier-1.png':
        shutil.copy2(source, ROOT / 'sources/tier-1.png')
    original = Image.open(source).convert('RGBA')
    clean = isolate(original)
    alpha = np.array(clean.getchannel('A'))
    ys, xs = np.where(alpha >= 128)
    # Core center measured on the front-facing timber perch, not asymmetrical rubble.
    row = np.flatnonzero(alpha[650] >= 128)
    center = int(round((int(row[0]) + int(row[-1])) / 2))
    anchor = (original.width // 2, original.height - 126)
    dx, dy = anchor[0] - center, anchor[1] - int(ys.max())
    image = palette_sweep(translate(clean, dx, dy))
    image.save(ROOT / 'tier-1.png')
    (ROOT / 'placement.json').write_text(json.dumps({
        'canvas': list(image.size), 'core_center_x': anchor[0], 'ground_y': anchor[1],
        'base_translation': [dx, dy], 'base_visible_bbox': list(Image.fromarray((np.array(image.getchannel('A')) >= 128).astype('uint8') * 255).getbbox()),
        'locked_base': 'tier-1.png', 'method': 'Same exact locked pixels in all five sprites; additions have explicit masks.'
    }, indent=2) + '\n')
    print((ROOT / 'placement.json').read_text())


def add_layer(source, parent_name, name, rectangles, dx=0, dy=0):
    (ROOT / 'sources').mkdir(exist_ok=True)
    (ROOT / 'layers').mkdir(exist_ok=True)
    (ROOT / 'masks').mkdir(exist_ok=True)
    if Path(source).resolve() != ROOT / 'sources' / (name + '.png'):
        shutil.copy2(source, ROOT / 'sources' / (name + '.png'))
    parent = Image.open(ROOT / (parent_name + '.png')).convert('RGBA')
    generated = Image.open(source).convert('RGBA')
    generated = translate(generated, dx, dy, parent.size)
    mask = Image.new('L', parent.size)
    draw = ImageDraw.Draw(mask)
    for rect in rectangles:
        draw.rectangle(rect, fill=255)
    old = np.array(parent)
    addition = np.array(generated)
    keep = (np.array(mask) > 0) & (old[:, :, 3] == 0)
    addition[~keep] = 0
    layer = palette_sweep(Image.fromarray(addition), branch=name == 'tier-4-arrowstorm')
    layer.save(ROOT / 'layers' / (name + '.png'))
    Image.fromarray((keep * 255).astype('uint8')).save(ROOT / 'masks' / (name + '.png'))
    result = np.array(layer)
    result[old[:, :, 3] > 0] = old[old[:, :, 3] > 0]
    Image.fromarray(result).save(ROOT / (name + '.png'))
    print(name, 'added visible pixels', int((np.array(layer)[:, :, 3] >= 128).sum()))


def finish():
    specs = json.loads((ROOT / 'assembly.json').read_text())
    names = ['tier-1'] + [s['name'] for s in specs]
    placement = json.loads((ROOT / 'placement.json').read_text())
    base = np.array(Image.open(ROOT / 'tier-1.png').convert('RGBA'))
    base_mask = base[:, :, 3] > 0
    allowed = {tuple(c) for c in RGB.tolist()}
    images, records = [], []
    for index, name in enumerate(names):
        path = ROOT / (name + '.png')
        before = np.array(Image.open(path).convert('RGBA'))
        # Required final color-only sweep, followed by exact restoration of tier 1.
        final = np.array(palette_sweep(Image.fromarray(before), branch=name == 'tier-4-arrowstorm'))
        final[base_mask] = base[base_mask]
        assert np.array_equal(before[:, :, 3], final[:, :, 3]), name
        Image.fromarray(final).save(path)
        reopened = np.array(Image.open(path).convert('RGBA'))
        visible = reopened[:, :, 3] > 0
        colors = {tuple(c) for c in np.unique(reopened[:, :, :3][visible], axis=0).tolist()}
        assert colors <= allowed, (name, colors - allowed)
        assert np.array_equal(reopened[base_mask], base[base_mask]), name
        assert tuple(Image.open(path).size) == tuple(placement['canvas'])
        yy, xx = np.where(reopened[:, :, 3] >= 128)
        assert int(yy.max()) == placement['ground_y']
        if index:
            spec = specs[index - 1]
            parent = np.array(Image.open(ROOT / (spec['parent'] + '.png')).convert('RGBA'))
            prior = parent[:, :, 3] > 0
            assert np.array_equal(reopened[prior], parent[prior]), name
            addition = np.array(Image.open(ROOT / 'layers' / (name + '.png')).convert('RGBA'))
            restored = addition.copy()
            restored[prior] = parent[prior]
            assert np.array_equal(reopened, restored), name
        # Protected lower structure gives a measured offset check independent of silhouettes.
        offsets = []
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if np.array_equal(reopened[900+dy:1050+dy, 470+dx:780+dx], base[900:1050, 470:780]):
                    offsets.append([dx, dy])
        assert offsets == [[0, 0]], (name, offsets)
        images.append(Image.fromarray(reopened))
        records.append({'file': path.name, 'size': list(images[-1].size), 'used_colors': len(colors),
                        'palette_valid': True, 'core_anchor': [placement['core_center_x'], placement['ground_y']],
                        'measured_offset_from_base': offsets[0], 'locked_base_pixels_unchanged': int(base_mask.sum()),
                        'all_previous_layers_unchanged': True, 'alpha_preserved_by_final_sweep': True,
                        'visible_bbox': [int(xx.min()), int(yy.min()), int(xx.max()+1), int(yy.max()+1)]})
    # Review derivatives only. The five master sprites are never resized.
    sheet = Image.new('RGB', (2000, 710), '#18201D')
    draw = ImageDraw.Draw(sheet)
    def font(size):
        return ImageFont.truetype('C:/Windows/Fonts/georgia.ttf', size)
    draw.text((48, 25), 'ASHNEEDLE  /  THE ARROW WATCHTOWER', font=font(34), fill='#B9B294')
    draw.text((48, 76), 'Original family  |  Tier 1 > Tier 2 > Tier 3 > two independent Tier 4 branches', font=font(19), fill='#889184')
    labels = ['I  /  WATCHPOST', 'II  /  FIRING GALLERIES', 'III  /  FORTIFIED WATCH', 'IV-A  /  ARROWSTORM', 'IV-B  /  LASTWATCH']
    for i, (item, label) in enumerate(zip(images, labels)):
        draw.text((i * 400 + 28, 120), label, font=font(18), fill='#B9B294')
        thumbnail = item.resize((400, 400), Image.Resampling.NEAREST)
        sheet.paste(thumbnail, (i * 400, 146), thumbnail)
        small = item.resize((112, 112), Image.Resampling.NEAREST)
        sheet.paste(small, (i * 400 + 144, 548), small)
    draw.text((48, 679), '1254 x 1254 transparent masters  |  Shared anchor (627, 1128)  |  16 selected colors  |  Fixed placement thumbnails below', font=font(17), fill='#889184')
    sheet.save(ROOT / 'family-review.png')
    images[0].save(ROOT / 'alignment-preview.webp', save_all=True, append_images=images[1:], duration=850, loop=0, lossless=True)
    report = {'result': 'PASS', 'sprites': records, 'notes': 'Art asset verification only; no runtime installation or gameplay tests.'}
    (ROOT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['base', 'add', 'finish', 'rebuild'])
    parser.add_argument('source', nargs='?')
    parser.add_argument('--parent')
    parser.add_argument('--name')
    parser.add_argument('--rects', help='JSON list of allowed addition rectangles')
    parser.add_argument('--offset', default='[0,0]')
    args = parser.parse_args()
    if args.action == 'base':
        prepare_base(args.source)
    elif args.action == 'add':
        add_layer(args.source, args.parent, args.name, json.loads(args.rects), *json.loads(args.offset))
    elif args.action == 'rebuild':
        prepare_base(ROOT / 'sources/tier-1.png')
        for spec in json.loads((ROOT / 'assembly.json').read_text()):
            add_layer(ROOT / 'sources' / (spec['name'] + '.png'), spec['parent'], spec['name'], spec['rectangles'])
        finish()
    else:
        finish()
