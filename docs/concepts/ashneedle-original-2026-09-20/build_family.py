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
from PIL import Image, ImageDraw, ImageFilter

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
    layer = palette_sweep(Image.fromarray(addition), branch=name.startswith('tier-4'))
    layer.save(ROOT / 'layers' / (name + '.png'))
    Image.fromarray((keep * 255).astype('uint8')).save(ROOT / 'masks' / (name + '.png'))
    result = np.array(layer)
    result[old[:, :, 3] > 0] = old[old[:, :, 3] > 0]
    Image.fromarray(result).save(ROOT / (name + '.png'))
    print(name, 'added visible pixels', int((np.array(layer)[:, :, 3] >= 128).sum()))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['base', 'add'])
    parser.add_argument('source')
    parser.add_argument('--parent')
    parser.add_argument('--name')
    parser.add_argument('--rects', help='JSON list of allowed addition rectangles')
    parser.add_argument('--offset', default='[0,0]')
    args = parser.parse_args()
    if args.action == 'base':
        prepare_base(args.source)
    else:
        add_layer(args.source, args.parent, args.name, json.loads(args.rects), *json.loads(args.offset))
