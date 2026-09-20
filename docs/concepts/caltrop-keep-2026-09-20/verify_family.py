"""Final saved-file palette, locked-layer, anchor and transparency checks."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from build_family import ROOT, COLORS, palette_sweep

NAMES = ['tier-1', 'tier-2', 'tier-3', 'tier-4-broadscatter', 'tier-4-ironthorn']
PARENTS = [None, 'tier-1', 'tier-2', 'tier-3', 'tier-3']
LABELS = ['Tier 1', 'Tier 2', 'Tier 3', 'Tier 4A', 'Tier 4B']
DESCRIPTIONS = ['Sapper\u2019s Hold', 'Loading bins', 'Resupply hoist', 'Broadscatter Arsenal', 'Ironthorn Hold']
base = np.array(Image.open(ROOT / 'layers/tier-1-locked-base.png').convert('RGBA'))
base_mask = base[:, :, 3] > 0
base_bounds = Image.fromarray(base[:, :, 3]).getbbox()
anchor = [(base_bounds[0] + base_bounds[2]) // 2, base_bounds[3] - 1]
allowed = {tuple(c) for c in COLORS}
report = {'canvas': [1254, 1254], 'core_center_x': anchor[0], 'ground_anchor': anchor, 'locked_base_bounds': base_bounds, 'files': []}
frames = []
for name, parent in zip(NAMES, PARENTS):
    path = ROOT / (name + '.png')
    previous = np.array(Image.open(path).convert('RGBA'))
    pixels = palette_sweep(previous)
    # Tier-one material assignments are authoritative across the complete set.
    pixels[base_mask] = base[base_mask]
    assert np.array_equal(previous, pixels), f'Unexpected palette/base drift in {name}'
    Image.fromarray(pixels).save(path)
    # Reopen the actual saved file, not an in-memory proxy.
    saved = np.array(Image.open(path).convert('RGBA'))
    unique = {tuple(c) for c in np.unique(saved[saved[:, :, 3] > 0, :3], axis=0)}
    assert unique <= allowed
    assert saved.shape == base.shape
    assert np.array_equal(saved[base_mask], base[base_mask])
    assert np.array_equal(saved[:, :, 3], previous[:, :, 3])
    assert not saved[:8, :, 3].any() and not saved[-8:, :, 3].any()
    assert not saved[:, :8, 3].any() and not saved[:, -8:, 3].any()
    # The unchanged lower core directly measures alignment and the ground line.
    assert np.array_equal(saved[840:], base[840:])
    parent_preserved = True
    if parent:
        prior = np.array(Image.open(ROOT / (parent + '.png')).convert('RGBA'))
        mask = prior[:, :, 3] > 0
        parent_preserved = np.array_equal(saved[mask], prior[mask])
        assert parent_preserved
        layer = np.array(Image.open(ROOT / 'layers' / (name + '-addition.png')))
        addition = layer[:, :, 3] > 0
        assert not (addition & mask).any()
        recomposed = prior.copy()
        recomposed[addition] = layer[addition]
        assert np.array_equal(recomposed, saved)
        Image.fromarray((addition * 255).astype('uint8')).save(ROOT / 'layers' / (name + '-mask.png'))
    if name == 'tier-4-broadscatter':
        assert tuple(COLORS[13]) in unique and tuple(COLORS[15]) not in unique
    elif name == 'tier-4-ironthorn':
        assert tuple(COLORS[15]) in unique and tuple(COLORS[13]) not in unique
    else:
        assert unique <= {tuple(c) for c in COLORS[:12]}
    report['files'].append({'file': path.name, 'palette_colors': len(unique), 'palette_pass': True, 'base_pixel_mismatches': 0, 'parent_pixels_preserved': bool(parent_preserved), 'core_offset': [0, 0], 'ground_anchor': anchor, 'alpha_preserved_during_final_sweep': True, 'clean_canvas_edges': True, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    frames.append(Image.fromarray(saved))

# Inspection only: final sprite files above are never resized.
background = '#202823'
sheet = Image.new('RGB', (1900, 680), background)
draw = ImageDraw.Draw(sheet)
font_path = 'C:/Windows/Fonts/georgia.ttf'
sans_path = 'C:/Windows/Fonts/arial.ttf'
title_font = ImageFont.truetype(font_path, 37)
label_font = ImageFont.truetype(sans_path, 21)
small_font = ImageFont.truetype(sans_path, 17)
draw.text((36, 22), 'CALTROP KEEP  /  THE SAPPER\u2019S HOLD', fill='#D1CCB5', font=title_font)
draw.text((38, 78), 'Original five-sprite family  \u2022  Shared 16-color palette  \u2022  Fixed core and ground anchor', fill='#929D92', font=small_font)
for i, (frame, label, desc) in enumerate(zip(frames, LABELS, DESCRIPTIONS)):
    x = i * 376 + 12
    preview = frame.resize((365, 365), Image.Resampling.NEAREST)
    sheet.paste(preview, (x, 115), preview)
    draw.text((x + 12, 480), label, fill='#D1CCB5', font=label_font)
    draw.text((x + 12, 510), desc, fill='#B0B6A6', font=small_font)
    miniature = frame.resize((147, 147), Image.Resampling.NEAREST)
    sheet.paste(miniature, (x + 107, 529), miniature)
sheet.save(ROOT / 'family-review.png')
switch_frames = []
for frame, label, desc in zip(frames, LABELS, DESCRIPTIONS):
    canvas = Image.new('RGBA', frame.size, background)
    canvas.alpha_composite(frame)
    ImageDraw.Draw(canvas).text((40, 40), f'{label} \u2014 {desc}', fill='#D1CCB5', font=title_font)
    switch_frames.append(canvas)
switch_frames[0].save(ROOT / 'alignment-preview.webp', save_all=True, append_images=switch_frames[1:], duration=1000, loop=0, lossless=True)
report['status'] = 'pass'
(ROOT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
