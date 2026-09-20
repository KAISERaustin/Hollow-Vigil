"""Palette enforcement, addition-mask assembly, and saved-file verification.

ImageGen supplies every drawn pixel. No artwork is redrawn or resized here.
Only previews are downscaled. Raw generation sources remain unchanged.
"""
from pathlib import Path
import argparse
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PALETTE = np.array([tuple(bytes.fromhex(row[0][1:])) for row in json.loads((ROOT / 'palette.json').read_text())], dtype=np.int32)


def quantize(rgba, indices):
    """Color-only conversion: preserve all coordinates and alpha exactly."""
    out = rgba.copy()
    visible = out[:, :, 3] > 0
    colors, inverse = np.unique(out[:, :, :3][visible], axis=0, return_inverse=True)
    palette = PALETTE[indices]
    selected = []
    for start in range(0, len(colors), 8192):
        delta = colors[start:start+8192].astype(np.int32)[:, None, :] - palette[None, :, :]
        distance = (delta * delta * np.array([2, 4, 3])).sum(axis=2)
        selected.append(palette[distance.argmin(axis=1)])
    if selected:
        out[:, :, :3][visible] = np.concatenate(selected)[inverse]
    assert np.array_equal(out[:, :, 3], rgba[:, :, 3])
    return out


def save(a, path):
    Image.fromarray(a.astype(np.uint8)).save(path)


def base(source):
    (ROOT / 'sources').mkdir(exist_ok=True)
    shutil.copy2(source, ROOT / 'sources/tier-1-generated.png')
    rgba = np.array(Image.open(source).convert('RGBA'))
    # Separate silhouette mask cleanup: remove only almost invisible background
    # residue (alpha <= 8). Preserve alpha of every remaining source pixel.
    residue = rgba[:, :, 3] <= 8
    rgba[residue] = 0
    (ROOT / 'layers').mkdir(exist_ok=True)
    result = quantize(rgba, list(range(14)))
    # Material-specific assignments prevent brown or magic shades on masonry.
    result[590:] = quantize(rgba[590:], list(range(6)))
    result[488:547] = quantize(rgba[488:547], list(range(6)))
    save(result, ROOT / 'tier-1.png')
    save(result, ROOT / 'layers/locked-tier-1.png')
    mask = result[:, :, 3] > 0
    ys, xs = np.where(mask)
    metadata = {'canvas': list(Image.open(source).size), 'core_axis_x': 627,
                'ground_anchor': [627, int(ys.max())],
                'tier_1_bounds': [int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1],
                'cleanup': 'Only alpha <= 8 residue removed before color-only palette enforcement.',
                'source': str(source)}
    (ROOT / 'placement.json').write_text(json.dumps(metadata, indent=2)+'\n')
    print(json.dumps(metadata))


def upgrade(source, name, parent, boxes, indices):
    raw = np.array(Image.open(source).convert('RGBA'))
    previous = np.array(Image.open(ROOT / (parent+'.png')).convert('RGBA'))
    assert raw.shape == previous.shape, (raw.shape, previous.shape)
    shutil.copy2(source, ROOT / ('sources/'+name+'-generated.png'))
    region = np.zeros(raw.shape[:2], dtype=bool)
    for x0, y0, x1, y1 in boxes:
        region[y0:y1, x0:x1] = True
    # Extract only new generated pixels in deliberately selected addition areas.
    # The complete parent stays locked, including its antialiased contour.
    mask = region & (previous[:, :, 3] == 0) & (raw[:, :, 3] > 8)
    layer = np.zeros_like(raw)
    layer[mask] = raw[mask]
    layer = quantize(layer, indices)
    result = previous.copy()
    result[mask] = layer[mask]
    save(layer, ROOT / ('layers/'+name+'-addition.png'))
    Image.fromarray(mask.astype(np.uint8)*255).save(ROOT / ('layers/'+name+'-mask.png'))
    save(result, ROOT / (name+'.png'))
    assert np.array_equal(result[previous[:, :, 3] > 0], previous[previous[:, :, 3] > 0])
    spec = {'parent': parent, 'addition_boxes': boxes, 'allowed_palette_indices': indices,
            'addition_pixels': int(mask.sum()), 'source': str(source)}
    (ROOT / ('layers/'+name+'.json')).write_text(json.dumps(spec, indent=2)+'\n')
    print(json.dumps(spec))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['base', 'upgrade'])
    parser.add_argument('source')
    parser.add_argument('--name')
    parser.add_argument('--parent')
    parser.add_argument('--boxes', type=json.loads)
    parser.add_argument('--indices', type=json.loads, default=list(range(14)))
    args = parser.parse_args()
    if args.operation == 'base':
        base(args.source)
    else:
        upgrade(args.source, args.name, args.parent, args.boxes, args.indices)
