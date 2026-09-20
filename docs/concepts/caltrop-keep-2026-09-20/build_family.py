"""Palette enforcement and lossless masked layer assembly for Caltrop Keep.

ImageGen creates all artwork. This script only isolates, translates, masks,
composites, enforces the selected palette, and builds inspection artifacts.
"""
from pathlib import Path
import argparse
import json
import shutil
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
SPEC = json.loads((ROOT / 'palette.json').read_text(encoding='utf-8'))
COLORS = np.array([tuple(bytes.fromhex(c['hex'][1:])) for c in SPEC['colors']], dtype=np.int32)

def palette_sweep(pixels, count=16, exclude_bronze=False):
    result = pixels.copy()
    selected = COLORS[:count]
    if exclude_bronze:
        selected = COLORS[[*range(12), 14, 15]]
    flat = result[:, :, :3].reshape(-1, 3)
    for start in range(0, len(flat), 65536):
        section = flat[start:start + 65536].astype(np.int32)
        distance = ((section[:, None, :] - selected[None, :, :]) ** 2).sum(axis=2)
        flat[start:start + 65536] = selected[distance.argmin(axis=1)]
    result[:, :, :3] = flat.reshape(result.shape[0], result.shape[1], 3)
    assert np.array_equal(result[:, :, 3], pixels[:, :, 3])
    return result

def prepare(args):
    source = Path(args.source)
    (ROOT / 'sources').mkdir(exist_ok=True)
    destination = ROOT / 'sources' / (args.name + '.png')
    if source.resolve() != destination.resolve():
        shutil.copy2(source, destination)
    pixels = np.array(Image.open(source).convert('RGBA'))
    # Generated cutouts contain isolated 1/255 background residue. This mask
    # removes only near-invisible background; the color sweep preserves alpha.
    pixels[pixels[:, :, 3] <= 4] = 0
    pixels = palette_sweep(pixels, args.colors, args.exclude_bronze)
    if args.dx or args.dy:
        translated = Image.new('RGBA', (pixels.shape[1], pixels.shape[0]))
        translated.paste(Image.fromarray(pixels), (args.dx, args.dy))
        pixels = np.array(translated)
    if args.parent:
        parent = np.array(Image.open(ROOT / (args.parent + '.png')).convert('RGBA'))
        assert pixels.shape == parent.shape, (pixels.shape, parent.shape)
        mask = np.zeros(pixels.shape[:2], dtype=bool)
        for box in args.box:
            x0, y0, x1, y1 = map(int, box.split(','))
            mask[y0:y1, x0:x1] = True
        # Retain every existing pixel. New material can occupy only clear space.
        mask &= parent[:, :, 3] == 0
        mask &= pixels[:, :, 3] > 0
        layer = np.zeros_like(parent)
        layer[mask] = pixels[mask]
        (ROOT / 'layers').mkdir(exist_ok=True)
        Image.fromarray(layer).save(ROOT / 'layers' / (args.name + '-addition.png'))
        result = parent.copy()
        result[mask] = layer[mask]
        assert np.array_equal(result[parent[:, :, 3] > 0], parent[parent[:, :, 3] > 0])
    else:
        result = pixels
        (ROOT / 'layers').mkdir(exist_ok=True)
        Image.fromarray(result).save(ROOT / 'layers' / 'tier-1-locked-base.png')
    Image.fromarray(result).save(ROOT / (args.name + '.png'))
    print(json.dumps({'file': args.name + '.png', 'size': list(Image.fromarray(result).size), 'bounds': Image.fromarray(result[:, :, 3]).getbbox(), 'colors': len(np.unique(result[result[:, :, 3] > 0, :3], axis=0))}))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source')
    parser.add_argument('name')
    parser.add_argument('--parent')
    parser.add_argument('--box', action='append', default=[])
    parser.add_argument('--colors', type=int, default=16)
    parser.add_argument('--exclude-bronze', action='store_true')
    parser.add_argument('--dx', type=int, default=0)
    parser.add_argument('--dy', type=int, default=0)
    prepare(parser.parse_args())
