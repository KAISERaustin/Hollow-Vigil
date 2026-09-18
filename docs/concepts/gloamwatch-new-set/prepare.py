"""Palette-only correction; preserves native geometry and alpha. No dithering."""
from pathlib import Path
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
HEX = ['000000','151E1D','293633','414A44','41423C','56564E','6D6B60','3D3025','624B35','392724','613B34','BFB295','435862','758F9E','39442B','788346']
PAL = np.array([[int(h[i:i+2], 16) for i in (0,2,4)] for h in HEX], dtype=np.uint8)

def convert(source, name):
    a = np.array(Image.open(source).convert('RGBA'))
    rgb = a[:,:,:3].astype(np.int32)
    # Reserve elemental colors for elemental sprites, cloth for later tiers.
    allowed = list(range(9)) + ([] if name == 'tier-1' else [9,10,11])
    if 'ice' in name: allowed += [12,13]
    if 'poison' in name: allowed += [14,15]
    choices = PAL[allowed].astype(np.int32)
    idx = np.argmin(((rgb[:,:,None,:]-choices)**2).sum(3), axis=2)
    out = np.dstack((choices[idx].astype(np.uint8), a[:,:,3]))
    out[a[:,:,3] == 0,:3] = 0
    assert np.array_equal(a[:,:,3], out[:,:,3])
    target = ROOT / (name + '.png')
    Image.fromarray(out).save(target)
    saved = np.array(Image.open(target))
    colors = np.unique(saved[:,:,:3][saved[:,:,3]>0], axis=0)
    assert all(tuple(c) in set(map(tuple,PAL)) for c in colors)
    print(name, 'size', list(Image.open(target).size), 'colors', len(colors), 'alpha preserved')

if __name__ == '__main__': convert(Path(sys.argv[1]), sys.argv[2])
