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


def assemble(name, parent_name, rectangles):
    parent = Image.open(ROOT / (parent_name + '.png')).convert('RGBA')
    source = Image.open(ROOT / 'sources' / (name + '.png')).convert('RGBA')
    assert source.size == parent.size, (source.size, parent.size)
    original = np.array(parent)
    generated = np.array(enforce(source))
    selection = np.zeros(original.shape[:2], dtype=bool)
    for left, top, right, bottom in rectangles:
        selection[top:bottom, left:right] = True
    # Keep only new structural silhouettes. Existing visible artwork is locked.
    # The faint (alpha < 16) background residues in generated images are not forms.
    selection &= (original[:, :, 3] < 16) & (generated[:, :, 3] >= 16)
    addition = generated.copy()
    addition[~selection] = 0
    (ROOT / 'layers').mkdir(exist_ok=True)
    (ROOT / 'masks').mkdir(exist_ok=True)
    Image.fromarray(addition).save(ROOT / 'layers' / (name + '.png'))
    Image.fromarray(selection.astype(np.uint8) * 255).save(ROOT / 'masks' / (name + '.png'))
    merged = np.array(enforce(Image.alpha_composite(parent, Image.fromarray(addition))))
    assert np.array_equal(merged[original[:, :, 3] >= 16], original[original[:, :, 3] >= 16])
    Image.fromarray(merged).save(ROOT / (name + '.png'))
    return verify(Image.open(ROOT / (name + '.png')))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['base', 'tier-2', 'tier-3', 'branches'])
    args = parser.parse_args()
    if args.command == 'base':
        image = enforce(Image.open(ROOT / 'sources/tier-1.png'))
        image.save(ROOT / 'tier-1.png')
        print(json.dumps(verify(Image.open(ROOT / 'tier-1.png'))))
    elif args.command == 'tier-2':
        print(json.dumps(assemble('tier-2', 'tier-1', [(270, 635, 542, 1090), (720, 635, 990, 1090)])))
    elif args.command == 'tier-3':
        print(json.dumps(assemble('tier-3', 'tier-2', [(335, 295, 515, 798), (765, 350, 925, 798)])))
    elif args.command == 'branches':
        print(json.dumps(assemble('tier-4-reaping-arc', 'tier-3', [(95, 195, 395, 675), (865, 195, 1165, 675)])))
        # Keep the new arch only; exclude the generator's vertically shifted core.
        print(json.dumps(assemble('tier-4-oathbound-return', 'tier-3', [(340, 60, 940, 350), (365, 350, 495, 415), (817, 350, 899, 420)])))
