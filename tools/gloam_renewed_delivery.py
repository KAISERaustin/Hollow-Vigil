"""Enforce the new family palette, align without resampling, and install sprites."""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from gloam_renewed_palette import convert, PALETTE

NAMES = ['level-1', 'level-2', 'level-3', 'tier-4-frost', 'tier-4-poison']
TARGETS = ['1.png', '2.png', '3.png', '4/frostneedle.png', '4/thorn_volley.png']
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'docs/concepts/gloam-renewed'

def measure(a):
    # Ground contact: bottom opaque pixel of the central entrance step.
    baseline = int(np.flatnonzero(a[1200:, 512, 3] > 240)[-1]) + 1200
    # Door center: median midpoint of its timber interior, well below the arch.
    centers = []
    for y in range(baseline - 190, baseline - 80):
        row = a[y, 420:605]
        timber = np.all(row[:, :3] == PALETTE[9], axis=1)
        xs = np.flatnonzero(timber)
        if len(xs) > 70:
            centers.append((int(xs[0]) + int(xs[-1])) / 2 + 420)
    assert centers, 'Cannot find doorway center'
    return [int(round(float(np.median(centers)))), baseline]

def main(source):
    report = {'canvas': [1024, 1536], 'ground_anchor': [512, 1352],
              'muzzle_pixel': [512, 702], 'method': 'color-only material mapping, then integer translation', 'stages': {}}
    gallery = Image.new('RGB', (1280, 440), '#293633')
    draw = ImageDraw.Draw(gallery)
    union = set()
    for i, (name, target) in enumerate(zip(NAMES, TARGETS)):
        dest = OUTPUT / (name + '.png')
        item = convert(source / (name + '.png'), dest)
        a = np.array(Image.open(dest))
        assert a.shape == (1536, 1024, 4)
        before = measure(a)
        dx, dy = 512 - before[0], 1352 - before[1]
        out = np.zeros_like(a)
        sx0, sx1 = max(0, -dx), min(1024, 1024-dx)
        sy0, sy1 = max(0, -dy), min(1536, 1536-dy)
        keep = np.zeros(a.shape[:2], bool)
        keep[sy0:sy1, sx0:sx1] = True
        assert not np.any(a[:, :, 3][~keep]), 'Translation would clip nontransparent pixels'
        out[sy0+dy:sy1+dy, sx0+dx:sx1+dx] = a[sy0:sy1, sx0:sx1]
        assert measure(out) == [512, 1352]
        Image.fromarray(out).save(dest)
        installed = ROOT / 'assets/artwork/tower/rapid' / target
        installed.write_bytes(dest.read_bytes())
        saved = np.array(Image.open(dest))
        colors = set(map(tuple, np.unique(saved[:, :, :3][saved[:, :, 3] > 0], axis=0)))
        assert colors <= set(map(tuple, PALETTE))
        assert tuple(saved[702, 512, :3]) == (0, 0, 0) and saved[702, 512, 3] > 240
        assert saved[100, 100, 3] == 0
        union |= colors
        item.update(before_anchor=before, translation=[dx, dy], after_anchor=measure(saved),
                    clipped_pixels=0, black_projectile_outlet=True)
        report['stages'][name] = item
        thumb = Image.fromarray(saved).resize((256, 384), Image.Resampling.LANCZOS)
        gallery.paste(thumb, (i*256, 12), thumb)
        draw.text((i*256+65, 405), name, fill='#DDD0AF')
    report['family_color_count'] = len(union)
    (OUTPUT / 'verification.json').write_text(json.dumps(report, indent=2)+'\n')
    gallery.save(OUTPUT / 'family-preview.png')
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    main(parser.parse_args().source)
