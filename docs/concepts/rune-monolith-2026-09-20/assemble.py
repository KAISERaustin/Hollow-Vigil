"""Palette-only correction and masked, additive assembly authorized by the art guide.

ImageGen creates all artwork. This script does not draw, rescale or dither it.
Parents remain pixel-identical; only additions in previously empty space survive.
"""
from pathlib import Path
import argparse
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
PALETTE = json.loads((ROOT / 'palette.json').read_text())
RGB = np.array([tuple(bytes.fromhex(c['hex'][1:])) for c in PALETTE['colors']], dtype=np.int32)


def quantize(arr, indices, iron=False):
    result = arr.copy()
    occupied = arr[:, :, 3] > 0
    colors, inverse = np.unique(arr[occupied, :3], axis=0, return_inverse=True)
    c = colors.astype(np.int32)
    violet = (c[:, 2] > c[:, 1] + 12) & (c[:, 0] > c[:, 1] + 4)
    green = (c[:, 1] > c[:, 0] + 13) & (c[:, 1] > c[:, 2] + 7)
    garnet = (c[:, 0] > c[:, 1] + 20) & (c[:, 0] > c[:, 2] + 20)
    mapped = np.zeros_like(colors)
    # Material-aware mapping prevents neutral stone grain becoming purple iron.
    for material, selector in [('stone', np.ones(len(c), dtype=bool)), ('violet', violet), ('green', green), ('garnet', garnet)]:
        selected = {'stone': list(range(7)), 'violet': [0, 1, 10, 11, 12], 'green': [0, 1, 2, 13, 14], 'garnet': [0, 1, 10, 15]}[material]
        if material == 'stone' and iron:
            selected = [0, 1, 7, 8, 9]
        selected = [i for i in selected if i in indices]
        if material == 'green' and 13 not in indices or material == 'garnet' and 15 not in indices:
            continue
        choices = RGB[selected]
        distances = ((c[selector, None, :] - choices[None, :, :]) ** 2).sum(axis=2)
        mapped[selector] = choices[distances.argmin(axis=1)]
    result[occupied, :3] = mapped[inverse]
    assert np.array_equal(arr[:, :, 3], result[:, :, 3])
    return result


def shift_canvas(arr, size, dx, dy):
    """Integer offset only, never resizing or redrawing."""
    canvas = Image.new('RGBA', size)
    canvas.paste(Image.fromarray(arr), (dx, dy))
    return np.array(canvas)


def save_checked(arr, path):
    Image.fromarray(arr).save(path)
    saved = np.array(Image.open(path).convert('RGBA'))
    colors = np.unique(saved[saved[:, :, 3] > 0, :3], axis=0)
    assert all(any(np.array_equal(c, p) for p in RGB) for c in colors)
    assert np.array_equal(saved, arr)
    return len(colors)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('name')
    parser.add_argument('--parent')
    parser.add_argument('--dx', type=int, default=0)
    parser.add_argument('--dy', type=int, default=0)
    parser.add_argument('--region', type=int, nargs=4, action='append')
    parser.add_argument('--mask-polygons')
    parser.add_argument('--branch', choices=['ward', 'strike'])
    args = parser.parse_args()
    source = np.array(Image.open(ROOT / 'sources' / f'{args.name}.png').convert('RGBA'))
    allowed = list(range(13)) + ([13, 14] if args.branch == 'ward' else [15] if args.branch == 'strike' else [])
    layer_dir = ROOT / 'layers'
    layer_dir.mkdir(exist_ok=True)
    if not args.parent:
        final = shift_canvas(quantize(source, allowed), (source.shape[1], source.shape[0]), args.dx, args.dy)
        save_checked(final, layer_dir / 'locked-tier-1.png')
        metadata = {'source_dimensions': [source.shape[1], source.shape[0]], 'source_offset': [args.dx, args.dy], 'parent': None}
    else:
        parent = np.array(Image.open(ROOT / f'{args.parent}.png').convert('RGBA'))
        candidate = shift_canvas(quantize(source, allowed, args.branch == 'strike'), (parent.shape[1], parent.shape[0]), args.dx, args.dy)
        keep = np.zeros(parent.shape[:2], dtype=bool)
        if args.mask_polygons:
            mask = Image.new('L', (parent.shape[1], parent.shape[0]))
            draw = ImageDraw.Draw(mask)
            for polygon in json.loads((ROOT / args.mask_polygons).read_text()):
                draw.polygon([tuple(p) for p in polygon], fill=255)
            keep = np.array(mask) > 0
        else:
            for x0, y0, x1, y1 in args.region or [(0, 0, parent.shape[1], parent.shape[0])]:
                keep[y0:y1, x0:x1] = True
        keep &= parent[:, :, 3] == 0
        addition = candidate.copy()
        addition[~keep] = 0
        final = parent.copy()
        final[keep] = addition[keep]
        assert np.array_equal(final[parent[:, :, 3] > 0], parent[parent[:, :, 3] > 0])
        save_checked(addition, layer_dir / f'{args.name}-addition.png')
        Image.fromarray((keep & (addition[:, :, 3] > 0)).astype(np.uint8) * 255).save(layer_dir / f'{args.name}-mask.png')
        metadata = {'source_dimensions': [source.shape[1], source.shape[0]], 'source_offset': [args.dx, args.dy], 'parent': args.parent, 'regions': args.region, 'mask_polygons': args.mask_polygons, 'added_pixels': int(np.count_nonzero(addition[:, :, 3]))}
    metadata['palette_colors_used'] = save_checked(final, ROOT / f'{args.name}.png')
    metadata['canvas'] = [final.shape[1], final.shape[0]]
    y, x = np.where(final[:, :, 3] > 127)
    metadata['visible_bounds'] = [int(x.min()), int(y.min()), int(x.max()) + 1, int(y.max()) + 1]
    (layer_dir / f'{args.name}.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(metadata))


if __name__ == '__main__':
    main()
