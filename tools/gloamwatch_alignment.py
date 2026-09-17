"""Measure the shared front-step anchor; optionally align by integer translation.

Run against the fixed-palette PNGs. No scaling, interpolation or palette changes.
The anchor is the center of the lowest step at its bottom ink stroke's top edge.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

from gloamwatch_palette import NAMES, PALETTE

TARGET = (512, 1457)


def measure(a, probe_x):
    solid = (a[..., 3] > 240) & (a[..., :3].max(axis=2) > 25)
    rows = np.flatnonzero(solid[1380:1480, probe_x]) + 1380
    baseline = int(rows[-1]) + 1
    row = baseline - 2
    left = right = probe_x
    while solid[row, left - 1]:
        left -= 1
    while solid[row, right + 1]:
        right += 1
    center = (left + right + 1) / 2
    return {'anchor': [int(round(center)), baseline],
            'step_center_x': center, 'step_edges': [left, right + 1]}


def run(source, destination):
    report = {'canvas': [1024, 1536], 'target_anchor': list(TARGET),
              'method': 'integer translation only; no resizing or interpolation',
              'files': {}}
    if destination:
        destination.mkdir(parents=True, exist_ok=True)
    allowed = {tuple(c) for c in PALETTE}
    for name in NAMES:
        a = np.array(Image.open(source / (name + '.png')).convert('RGBA'))
        assert a.shape == (1536, 1024, 4)
        before = measure(a, 450)
        dx, dy = (TARGET[i] - before['anchor'][i] for i in range(2))
        item = {'before': before, 'translation': [dx, dy]}
        if destination:
            out = np.zeros_like(a)
            sx0, sx1 = max(0, -dx), min(1024, 1024 - dx)
            sy0, sy1 = max(0, -dy), min(1536, 1536 - dy)
            retained = np.zeros(a.shape[:2], dtype=bool)
            retained[sy0:sy1, sx0:sx1] = True
            assert not np.any((a[..., 3] >= 128) & ~retained), 'Visible artwork would be clipped'
            out[sy0+dy:sy1+dy, sx0+dx:sx1+dx] = a[sy0:sy1, sx0:sx1]
            after = measure(out, TARGET[0])
            assert after['anchor'] == list(TARGET)
            assert abs(after['step_center_x'] - TARGET[0]) <= 0.5
            colors = {tuple(c) for c in out[..., :3][out[..., 3] > 0]}
            assert colors <= allowed
            assert np.array_equal(out[sy0+dy:sy1+dy, sx0+dx:sx1+dx], a[sy0:sy1, sx0:sx1])
            Image.fromarray(out).save(destination / (name + '.png'))
            item.update(after=after, palette_preserved=True, retained_pixels_identical=True,
                        clipped_alpha_at_least_128=0,
                        clipped_low_alpha_pixels=int(np.count_nonzero((a[..., 3] > 0) & ~retained)))
        report['files'][name] = item
    if destination:
        (destination / 'alignment-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path, help='Omit for measurement only')
    args = parser.parse_args()
    run(args.source, args.output)
