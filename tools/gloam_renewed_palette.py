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
    # Match colors without dithering, resampling, or changing alpha.
    for start in range(0, len(out), 64):
        rgb = original[start:start+64, :, :3].astype(np.int32)
        distances = ((rgb[:, :, None, :] - PALETTE.astype(np.int32)) ** 2).sum(axis=3)
        out[start:start+64, :, :3] = PALETTE[distances.argmin(axis=2)]
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
