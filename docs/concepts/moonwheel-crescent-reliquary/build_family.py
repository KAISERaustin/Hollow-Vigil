"""Reproduce palette enforcement and locked-layer assembly for Moonwheel.

ImageGen supplies all artwork. This script only selects generated addition layers,
maps RGB to the recorded palette, and preserves earlier layers without repainting.
"""
from pathlib import Path
import argparse
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
PALETTE = np.array([tuple(bytes.fromhex(p['hex'][1:])) for p in json.loads((ROOT / 'palette.json').read_text())], dtype=np.int32)


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


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['base'])
    args = parser.parse_args()
    if args.command == 'base':
        image = enforce(Image.open(ROOT / 'sources/tier-1.png'))
        image.save(ROOT / 'tier-1.png')
        print(json.dumps(verify(Image.open(ROOT / 'tier-1.png'))))
