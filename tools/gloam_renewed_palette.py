"""Color-only enforcement for the original Gloam redesign; alpha is preserved."""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image

HEX = ['000000', '18221F', '303C35', '50584D', '747669', '92917E',
       '252D2C', '46514B', '352A24', '66503B', '452A2B', '77463E',
       'B7AA89', '587885', 'A1BAC0', '70844A']
PALETTE = np.array([[int(h[i:i+2], 16) for i in (0, 2, 4)] for h in HEX], dtype=np.uint8)

def convert(source, destination):
    original = np.array(Image.open(source).convert('RGBA'))
    out = original.copy()
    # Classify material hue, then quantize only within that material's roles.
    # The same thresholds restore tier-one material assignments in every stage.
    for start in range(0, len(out), 64):
        rgb = original[start:start+64, :, :3].astype(np.int32)
        distances = ((rgb[:, :, None, :] - PALETTE.astype(np.int32)) ** 2).sum(axis=3)
        r, g, b = rgb.transpose(2, 0, 1)
        yy = np.arange(start, start + len(rgb))[:, None]
        xx = np.arange(rgb.shape[1])[None, :]
        roles = np.zeros_like(distances, dtype=bool)
        roles[:, :, [0, 1, 2, 3, 4, 5]] = True
        roof = np.broadcast_to(yy < 650, r.shape)
        roles[roof] = False
        roles[roof, 0] = True
        roles[roof, 6] = True
        roles[roof, 7] = True
        wood = (r > g * 1.12) & (g > b * 1.10)
        roles[wood] = False
        for index in [0, 8, 9]:
            roles[wood, index] = True
        if 'level-1' not in destination.name:
            cloth_zone = (yy < 480) | ((xx > 420) & (xx < 610) & (yy > 745) & (yy < 1030))
            cloth = cloth_zone & (r > g * 1.4) & (r > b * 1.3)
            roles[cloth] = False
            for index in [0, 10, 11]:
                roles[cloth, index] = True
            bone = cloth_zone & (r > 150) & (r > g) & (g > b * 1.08)
            roles[bone] = False
            roles[bone, 12] = True
        if 'frost' in destination.name:
            frost = (b > r * 1.12) & (b > g * 1.02)
            roles[frost] = False
            for index in [0, 13, 14]:
                roles[frost, index] = True
        if 'poison' in destination.name:
            poison = (g > r * 1.08) & (g > b * 1.30)
            roles[poison] = False
            for index in [0, 1, 15]:
                roles[poison, index] = True
        distances[~roles] = 1000000
        out[start:start+64, :, :3] = PALETTE[distances.argmin(axis=2)]
    out[original[:, :, 3] == 0, :3] = 0
    destination.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out).save(destination)
    saved = np.array(Image.open(destination))
    colors = np.unique(saved[:, :, :3][saved[:, :, 3] > 0], axis=0)
    assert all(tuple(c) in set(map(tuple, PALETTE)) for c in colors)
    assert np.array_equal(saved[:, :, 3], original[:, :, 3])
    assert saved.shape == original.shape
    return {'file': str(destination), 'size': list(Image.open(destination).size),
            'colors': len(colors), 'alpha_preserved': True, 'resampled': False}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    print(json.dumps(convert(args.source, args.destination)))
