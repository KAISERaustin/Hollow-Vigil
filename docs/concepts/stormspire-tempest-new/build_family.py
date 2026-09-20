"""Palette enforcement, addition-mask assembly, and saved-file verification.

ImageGen supplies every drawn pixel. No artwork is redrawn or resized here.
Only previews are downscaled. Raw generation sources remain unchanged.
"""
from pathlib import Path
import argparse
import json
import shutil
import hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PALETTE = np.array([tuple(bytes.fromhex(row[0][1:])) for row in json.loads((ROOT / 'palette.json').read_text())], dtype=np.int32)
FAMILY = [
    ('tier-1', None, 'Tier 1', 'The Tempest Spire'),
    ('tier-2', 'tier-1', 'Tier 2', 'Conductor arms'),
    ('tier-3', 'tier-2', 'Tier 3', 'Three-fork crown'),
    ('tier-4-skyfork', 'tier-3', 'Tier 4 / Skyfork', 'Branching storm crown'),
    ('tier-4-thunderward', 'tier-3', 'Tier 4 / Thunderward', 'Enclosing ward ribs'),
]


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


def finish():
    """Required final tier-one-authoritative color sweep and file readback."""
    locked = np.array(Image.open(ROOT / 'layers/locked-tier-1.png').convert('RGBA'))
    base_mask = locked[:, :, 3] > 0
    placement = json.loads((ROOT / 'placement.json').read_text())
    report = {'canvas': placement['canvas'], 'ground_anchor': placement['ground_anchor'],
              'palette': [row.tolist() for row in PALETTE], 'files': {}}
    allowed = set(map(tuple, PALETTE.tolist()))
    for name, parent, _, _ in FAMILY:
        original = np.array(Image.open(ROOT / (name+'.png')).convert('RGBA'))
        result = quantize(original, list(range(16)))
        if parent:
            previous = np.array(Image.open(ROOT / (parent+'.png')).convert('RGBA'))
            keep = previous[:, :, 3] > 0
            result[keep] = previous[keep]
        result[base_mask] = locked[base_mask]
        assert np.array_equal(original[:, :, 3], result[:, :, 3]), name
        save(result, ROOT / (name+'.png'))
        reopened = np.array(Image.open(ROOT / (name+'.png')).convert('RGBA'))
        mask = reopened[:, :, 3] > 0
        unique = set(map(tuple, np.unique(reopened[:, :, :3][mask], axis=0).tolist()))
        assert unique <= allowed, name
        assert np.array_equal(reopened[base_mask], locked[base_mask]), name
        assert np.array_equal(reopened[590:], locked[590:]), name
        assert tuple(Image.open(ROOT / (name+'.png')).size) == tuple(placement['canvas'])
        assert int(np.where(mask)[0].max()) == placement['ground_anchor'][1]
        # Measure the unchanged central shaft and foundation; exact base equality
        # checks their position against the whole locked source, not just a bbox.
        xs = np.where(reopened[330, 600:655, 3] > 128)[0] + 600
        measured_center = float((xs.min()+xs.max())/2)
        base_xs = np.where(locked[330, 600:655, 3] > 128)[0] + 600
        reference_center = float((base_xs.min()+base_xs.max())/2)
        assert measured_center == reference_center
        if parent:
            assert np.array_equal(reopened[keep], previous[keep]), name
            addition = np.array(Image.open(ROOT / ('layers/'+name+'-addition.png')).convert('RGBA'))
            addition_mask = addition[:, :, 3] > 0
            assert not np.any(addition_mask & keep), name
            assert np.array_equal(reopened[addition_mask], addition[addition_mask]), name
        report['files'][name+'.png'] = {
            'colors': len(unique), 'off_palette_pixels': 0, 'changed_base_pixels': 0,
            'changed_parent_pixels': 0, 'core_offset': [0, 0],
            'measured_shaft_center_x': measured_center,
            'ground_anchor': placement['ground_anchor'], 'bounds': list(Image.fromarray(reopened).getbbox()),
            'transparent_pixels': int((reopened[:, :, 3] == 0).sum()),
            'alpha_preserved_during_final_sweep': True,
            'sha256': hashlib.sha256((ROOT / (name+'.png')).read_bytes()).hexdigest()}
    report['status'] = 'PASS'
    (ROOT / 'validation.json').write_text(json.dumps(report, indent=2)+'\n')
    preview()
    print(json.dumps(report, indent=2))


def font(size):
    return ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', size)


def preview():
    # Review-only canvases: delivered sprites/layers remain at original scale.
    board = Image.new('RGB', (1900, 910), '#1B2428')
    d = ImageDraw.Draw(board)
    d.text((52, 28), 'STORMSPIRE', fill='#D8DDDA', font=font(44))
    d.text((54, 88), 'The Tempest Spire  /  Complete tower family', fill='#96A7AD', font=font(22))
    crop = (270, 50, 985, 1190)
    for i, (name, _, title, subtitle) in enumerate(FAMILY):
        x = 40 + i*370
        d.text((x+175, 144), title, fill='#D8DDDA', font=font(23), anchor='mm')
        im = Image.open(ROOT / (name+'.png')).convert('RGBA')
        large = im.crop(crop).resize((310, 494), Image.Resampling.LANCZOS)
        board.paste(large, (x+20, 183), large)
        d.text((x+175, 704), subtitle, fill='#96A7AD', font=font(19), anchor='mm')
        small = im.resize((96,96), Image.Resampling.LANCZOS)
        board.paste(small, (x+127, 731), small)
    d.text((54, 853), '16 shared colors', fill='#96A7AD', font=font(18))
    for i, rgb in enumerate(PALETTE):
        x = 225+i*32
        d.rectangle((x, 850, x+24, 874), fill=tuple(rgb.tolist()))
    d.text((1842, 864), '1254 x 1254  /  Anchor (627, 1164)  /  Same scale throughout',
           fill='#96A7AD', font=font(18), anchor='rm')
    board.save(ROOT / 'family-review.png')
    frames = []
    for name, _, title, _ in FAMILY:
        frame = Image.new('RGB', (620, 720), '#1B2428')
        im = Image.open(ROOT / (name+'.png')).convert('RGBA').resize((600,600), Image.Resampling.LANCZOS)
        frame.paste(im, (10, 60), im)
        draw = ImageDraw.Draw(frame)
        draw.text((310, 28), title, fill='#D8DDDA', font=font(25), anchor='mm')
        y = 60+round(1164*600/1254)
        draw.line((130,y,490,y), fill='#63767D', width=1)
        draw.text((310, 689), 'Fixed center and ground anchor', fill='#96A7AD', font=font(18), anchor='mm')
        frames.append(frame)
    frames[0].save(ROOT / 'alignment-preview.webp', save_all=True, append_images=frames[1:], duration=900, loop=0, lossless=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['base', 'upgrade', 'finish'])
    parser.add_argument('source', nargs='?')
    parser.add_argument('--name')
    parser.add_argument('--parent')
    parser.add_argument('--boxes', type=json.loads)
    parser.add_argument('--indices', type=json.loads, default=list(range(14)))
    args = parser.parse_args()
    if args.operation == 'base':
        base(args.source)
    elif args.operation == 'upgrade':
        upgrade(args.source, args.name, args.parent, args.boxes, args.indices)
    else:
        finish()
