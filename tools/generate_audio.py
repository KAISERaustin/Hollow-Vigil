"""Rebuild Hollow Vigil's original synthesis-only audio (Python 3, no dependencies).
All waveforms, envelopes and the 64-second score are authored here; no samples.
"""
import array
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 22050
TAU = math.tau
CATALOG = {}


def write(name, samples, category, cooldown=0.12, description=''):
    peak = max(abs(v) for v in samples) or 1
    scale = 0.22 / peak
    pcm = array.array('h', (round(v * scale * 32767) for v in samples))
    import sys
    if sys.byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
        out.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes(pcm.tobytes())
    CATALOG[name] = dict(category=category, cooldown=cooldown, description=description)


def cue(name, category, freq, duration, texture='chime', sweep=0, cooldown=0.12):
    rng = random.Random(int.from_bytes(hashlib.sha256(name.encode()).digest()[:8], 'little'))
    samples = []
    low = 0
    phase = 0
    for i in range(int(RATE * duration)):
        t = i / RATE
        x = t / duration
        phase += TAU * freq * max(0.1, 1 + sweep * x) / RATE
        low += 0.12 * (rng.uniform(-1, 1) - low)
        env = min(1, t / 0.009) * (1 - x) ** 2
        if texture == 'wood':
            v = 0.65 * low + math.sin(phase) * math.exp(-t * 28) + 0.2 * math.sin(phase * 2.71)
        elif texture == 'fire':
            v = 2.0 * low + 0.3 * math.sin(phase) + 0.2 * math.sin(phase * 1.013)
        elif texture == 'arc':
            v = (math.sin(phase + 2.8 * math.sin(phase * 0.53)) + low) * (0.65 + 0.35 * math.cos(TAU * 37 * t))
        elif texture == 'orb':
            v = math.sin(phase + 1.1 * math.sin(phase * 0.25)) + 0.3 * math.sin(phase * 1.5) + low * 0.25
        elif texture == 'air':
            v = low * 2.5 + 0.16 * math.sin(phase)
        elif texture == 'bow':
            # Damped string and wooden limb release under a brief arrow air rush.
            # Noise leads the sound; no sustained high harmonic or whistle.
            string = (math.sin(phase) + 0.18 * math.sin(phase * 2.03)) * math.exp(-t * 48)
            limb = 0.32 * math.sin(phase * 0.57) * math.exp(-t * 65)
            rush = low * 4.5 * math.exp(-t * 15)
            v = 0.42 * string + limb + rush
        elif texture == 'wood_lock':
            # A padded wooden knock followed by a quieter seating clunk.
            # Low resonances decay quickly; no rising whistle or bell partials.
            v = 0.0
            for onset, strength in ((0.0, 1.0), (0.13, 0.65)):
                age = t - onset
                if age >= 0:
                    hit = min(1.0, age / .012) * math.exp(-age * 25)
                    v += strength * hit * (math.sin(TAU * freq * age) + .3 * math.sin(TAU * freq * .67 * age) + .7 * low)
        elif texture == 'arrow_impact':
            v = low * 2.8 * math.exp(-t * 28) + 0.45 * math.sin(phase) * math.exp(-t * 55)
        else:
            v = math.sin(phase) + 0.34 * math.sin(phase * 2.756) * math.exp(-t * 8) + 0.15 * math.sin(phase * 4.07)
        samples.append(v * env)
    write(name, samples, category, cooldown, f'{texture}; {freq} Hz; {duration}s; pitch sweep {sweep}')


def tower_construction():
    """Shared initial placement: masonry, timber braces and a dark iron tail."""
    duration = 1.15
    rng = random.Random(74219)
    samples = []
    rubble = 0.0
    for i in range(round(RATE * duration)):
        t = i / RATE
        rubble += .18 * (rng.uniform(-1, 1) - rubble)
        value = 0.0
        for start, weight in [(0.0, .65), (.105, .8), (.245, 1.0)]:
            age = t - start
            if age < 0:
                continue
            attack = min(1.0, age / .004)
            stone = math.sin(TAU * 72 * age + 1.8 * (1 - math.exp(-age * 35))) * math.exp(-age * 15)
            grit = rubble * 3.2 * math.exp(-age * 22)
            timber = .25 * math.sin(TAU * 137 * age + .8 * math.sin(TAU * 23 * age)) * math.exp(-age * 19)
            iron = .12 * (math.sin(TAU * 196 * age) + .4 * math.sin(TAU * 311 * age)) * math.exp(-age * 5)
            value += weight * attack * (stone + grit + timber + iron)
        samples.append(value * min(1.0, (duration - t) / .22))
    write('menu_build', samples, 'menu', .12,
          'Shared tower construction: heavy masonry impacts, timber braces and low iron resonance; 1.15s')


# Rebuild this shared cue without touching separately authored combat assets.
if __name__ == '__main__' and '--build-only' in sys.argv:
    CATALOG.update(json.loads((ROOT / 'catalog.json').read_text()))
    tower_construction()
    (ROOT / 'catalog.json').write_text(json.dumps(CATALOG, indent=2) + '\n')
    print('Created shared tower construction audio')
    sys.exit(0)


# Dry UI gestures and a different confirmation motif for each transaction.
for name, f, d, tex, sweep in [
    ('click', 720, .055, 'wood', -.25), ('open', 420, .13, 'chime', .5),
    ('close', 480, .11, 'wood', -.45), ('select', 640, .09, 'chime', .15),
    ('slider', 860, .04, 'wood', 0), ('collect', 880, .32, 'chime', .7),
    ('upgrade', 520, .4, 'chime', .8),
    ('sell', 690, .24, 'chime', -.5), ('move', 190, .27, 'wood', .3),
    ('ready', 610, .3, 'chime', .5),
    ('notice', 390, .12, 'wood', -.15)]:
    cue('menu_' + name, 'menu', f, d, tex, sweep)

tower_construction()

weapons = {
    'rapid': (260, .16, 'bow', -.18), 'splash': (140, .32, 'fire', -.5),
    'heavy': (180, .38, 'orb', -.35), 'electric': (760, .12, 'arc', -.6),
    'frostneedle': (380, .15, 'bow', -.2), 'thorn_volley': (920, .19, 'wood', -.6),
    'cinderfield': (110, .44, 'fire', -.4), 'rupture_pyre': (78, .42, 'fire', -.7),
    'grave_echo': (290, .44, 'orb', .4), 'doomstone': (85, .48, 'orb', -.3),
    'tempest_web': (1100, .22, 'arc', -.4), 'thunderseal': (530, .18, 'arc', .7),
}
impact_overrides = {'rapid': (170, .10, 'arrow_impact', -.12)}
cue('upgrade_rapid', 'menu', 145, .36, 'wood_lock')
for name, (f, d, tex, sweep) in weapons.items():
    cue('shot_' + name, 'towers', f, d, tex, sweep, .11)
    if name not in ('electric', 'tempest_web', 'thunderseal'):
        impact = impact_overrides.get(name, (f * .63, min(.35, d * 1.3), tex, -sweep))
        cue('impact_' + name, 'towers', *impact, cooldown=.16)
    if name not in ('rapid', 'splash', 'heavy', 'electric'):
        cue('upgrade_' + name, 'menu', 2160.0 if name == 'frostneedle' else f * 1.2, .55, 'chime' if name == 'frostneedle' else tex, .8)
for name, f, d, tex in [('seal', 120, .45, 'arc'), ('fragments', 980, .25, 'chime'), ('ignite', 95, .5, 'fire')]:
    cue('power_' + name, 'towers', f, d, tex, -.3, .3)
for name, f, tex in [('basic', 240, 'wood'), ('fast', 620, 'air'), ('heavy', 100, 'wood'), ('lantern', 960, 'chime'), ('shade', 380, 'air'), ('sentinel', 150, 'orb'), ('ruin_knight', 125, 'chime'), ('sepulcher', 58, 'wood'), ('briarling', 460, 'wood'), ('veil_widow', 510, 'air'), ('coffinbound', 72, 'wood')]:
    cue('death_' + name, 'enemies', f, .13, tex, -.5, .28)
cue('escape', 'enemies', 170, .19, 'orb', -.5, .45)
for kind, f, tex in [('warden', 85, 'wood'), ('cindermaw', 65, 'fire'), ('bell', 210, 'chime'), ('prior', 145, 'orb')]:
    for event, pitch, duration, sweep, cooldown in [
        ('step', 1, .3, -.2, .9), ('awaken', 1.5, 1.2, .5, 1.5),
        ('death', .8, 1.5, -.7, .8), ('ability', 2, .8, .3, .7),
        ('break', 2.8, .4, -.6, .4), ('escape', .7, .65, -.4, .7)]:
        if event == 'break' and kind not in ('warden', 'prior'):
            continue
        cue('boss_' + kind + '_' + event, 'bosses', f * pitch, duration, tex, sweep, cooldown)

# "The Lantern Watch": D minor / Bb / F / C, suspended fifths and sparse bells.
# Circular overlap-add includes every reverb tail at the loop boundary.
length = 64
music = [0.0] * (RATE * length)

def note(start, duration, midi, amp, bell=False):
    freq = 440 * 2 ** ((midi - 69) / 12)
    for i in range(int(duration * RATE)):
        t = i / RATE
        env = math.sin(math.pi * t / duration) ** 2
        if bell:
            env = min(1, t / .02) * math.exp(-t * 1.4) * min(1, (duration - t) / .3)
        value = (math.sin(TAU * freq * t) + .16 * math.sin(TAU * freq * 2 * t)) * env * amp
        index = (int(start * RATE) + i) % len(music)
        music[index] += value
        music[(index + int(.375 * RATE)) % len(music)] += value * .22
        music[(index + int(.75 * RATE)) % len(music)] += value * .1

for bar, chord in enumerate([(38, 57, 65), (34, 53, 62), (41, 57, 60), (36, 55, 62)] * 2):
    for pitch in chord:
        note(bar * 8 - 1, 11, pitch, .11)
    for beat, pitch in enumerate([chord[1] + 12, chord[2] + 12, chord[1] + 19]):
        note(bar * 8 + beat * 2.5, 3.8, pitch, .048, True)
write('lantern_watch', music, 'music', 0, 'The Lantern Watch — original 64-second circular ambient score')
(ROOT / 'catalog.json').write_text(json.dumps(CATALOG, indent=2) + '\n')
print(f'Created {len(CATALOG)} original audio assets in {ROOT}')
