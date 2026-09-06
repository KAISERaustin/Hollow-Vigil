"""Validate original PCM assets and the circular soundtrack boundary."""
import array
import hashlib
import json
from pathlib import Path
import sys
import wave

root = Path(__file__).resolve().parents[1] / 'assets/audio'
catalog = json.loads((root / 'catalog.json').read_text())
hashes = set()
for name in catalog:
    with wave.open(str(root / (name + '.wav'))) as stream:
        assert stream.getnchannels() == 1 and stream.getsampwidth() == 2, name
        pcm = stream.readframes(stream.getnframes())
        samples = array.array('h', pcm)
        if sys.byteorder != 'little':
            samples.byteswap()
        assert max(abs(v) for v in samples) <= 7210, name
        digest = hashlib.sha256(pcm).hexdigest()
        assert digest not in hashes, f'Duplicate audio: {name}'
        hashes.add(digest)
        if name == 'lantern_watch':
            assert stream.getnframes() == 64 * stream.getframerate()
            # A periodic waveform need not have identical adjacent samples.
            # Its seam must continue the local slope without a discontinuity.
            seam = samples[0] - samples[-1]
            assert abs(seam - (samples[-1] - samples[-2])) <= 8
            assert abs(seam - (samples[1] - samples[0])) <= 8
        else:
            assert samples[0] == 0 and abs(samples[-1]) < 2, name
print(f'PASS: {len(hashes)} distinct assets; bounded peaks, smooth endpoints and music seam')
