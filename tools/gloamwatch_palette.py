"""Apply the user-approved fixed palette without resampling tower geometry.

Input must be the pre-palette cumulative concepts, not already processed files.
Uses material masks to keep architectural highlights out of the bone role.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

HEX = ['000000', '151E1D', '222A29', '293633', '41423C', '56564E',
       '3D3025', '624B35', '392724', '613B34', 'BFB295', '435862',
       '758F9E', '39442B', '566333', '788346']
PALETTE = np.array([[int(h[i:i+2], 16) for i in (0, 2, 4)] for h in HEX], dtype=np.uint8)
NAMES = ['level-1', 'level-2', 'level-3', 'tier-4-frost', 'tier-4-poison']


def convert(source, destination):
    report = {}
    union = set()
    destination.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        src = np.array(Image.open(source / f'{name}.png').convert('RGBA'))
        rgb = src[..., :3].astype(float)
        r, g, b = rgb.transpose(2, 0, 1)
        value = rgb.max(axis=2)
        yy, xx = np.indices(value.shape)
        # Normalize structure through the same dark value mapping for every tier.
        light = rgb @ np.array([0.2126, 0.7152, 0.0722])
        indices = np.select([light < 24, light < 57, light < 100,
                             light < 150, light < 205], [0, 1, 3, 4, 5], default=5)
        roof = (yy < 520) & (yy > 240)
        indices[roof & (light >= 24) & (light < 105)] = 2
        indices[roof & (light >= 105) & (light < 170)] = 3
        indices[roof & (light >= 170)] = 4
        # Timber occurs in the doorway and under the gallery, not stone frames.
        timber_zone = ((yy > 1100) & (xx > 395) & (xx < 515)) | ((yy > 700) & (yy < 850))
        timber = timber_zone & (r > g * 1.09) & (g > b * 1.08) & (value > 32)
        indices[timber] = np.where(light[timber] < 75, 6, 7)
        red = (r > g * 1.3) & (r > b * 1.3) & (value > 30)
        indices[red] = np.where(light[red] < 65, 8, 9)
        if name != 'level-1':
            cloth_zone = ((yy < 315) & (xx > 500) & (xx < 740))
            if name != 'level-2':
                cloth_zone |= (yy > 750) & (yy < 1040) & (xx > 400) & (xx < 510)
            insignia = cloth_zone & (light > 155) & (r >= g) & (g > b * 1.04)
            indices[insignia] = 10
        if name == 'tier-4-frost':
            ice = (b > r * 1.10) & (b > g * 1.015) & (light > 45)
            indices[ice] = np.where(light[ice] < 150, 11, 12)
        if name == 'tier-4-poison':
            poison = (g > b * 1.30) & (g > r * 0.85) & (r < g * 1.15) & (value > 30)
            indices[poison] = np.select([light[poison] < 85, light[poison] < 140], [13, 14], default=15)
        indices[light < 20] = 0
        out = np.dstack((PALETTE[indices], src[..., 3]))
        out[src[..., 3] == 0, :3] = 0
        Image.fromarray(out.astype(np.uint8)).save(destination / f'{name}.png')
        colors = {tuple(c) for c in out[..., :3][out[..., 3] > 0]}
        assert colors <= {tuple(c) for c in PALETTE}
        assert np.array_equal(src[..., 3], out[..., 3])
        union |= colors
        report[name] = {'size': [src.shape[1], src.shape[0]], 'visible_rgb_colors': len(colors),
                        'alpha_unchanged': True, 'resampled': False,
                        'colors': sorted('#' + ''.join(f'{int(v):02X}' for v in c) for c in colors)}
    report['family_color_count'] = len(union)
    report['allowed_color_count'] = len(PALETTE)
    (destination / 'palette-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    convert(args.source, args.destination)
