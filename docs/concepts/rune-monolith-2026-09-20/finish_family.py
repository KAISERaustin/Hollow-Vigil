"""Final color sweep, saved-file verification and derivative review layouts."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from assemble import ROOT, RGB, save_checked

STAGES = [
    ('tier-1', None, 'I  /  Rune Monolith'),
    ('tier-2', 'tier-1', 'II  /  Binding Buttresses'),
    ('tier-3', 'tier-2', 'III  /  Binding Arch'),
    ('tier-4-oathbind', 'tier-3', 'IV-A  /  Oathbind'),
    ('tier-4-doomseal', 'tier-3', 'IV-B  /  Doomseal'),
]


def main():
    locked = np.array(Image.open(ROOT / 'layers/locked-tier-1.png').convert('RGBA'))
    base_mask = locked[:, :, 3] > 0
    frames = {}
    report = {'passed': False, 'canvas': [1254, 1254], 'core_center_x': 627,
              'ground_anchor': [627, 1156], 'max_family_colors': 16, 'sprites': []}
    union = set()
    for name, parent_name, _ in STAGES:
        arr = np.array(Image.open(ROOT / f'{name}.png').convert('RGBA'))
        before = arr.copy()
        visible = arr[:, :, 3] > 0
        colors, inverse = np.unique(arr[visible, :3], axis=0, return_inverse=True)
        # Required final palette sweep: no resampling, dithering or alpha changes.
        distances = ((colors[:, None, :].astype(np.int32) - RGB[None, :, :]) ** 2).sum(axis=2)
        arr[visible, :3] = RGB[distances.argmin(axis=1)][inverse]
        arr[base_mask] = locked[base_mask]
        if parent_name:
            parent = frames[parent_name]
            parent_mask = parent[:, :, 3] > 0
            arr[parent_mask] = parent[parent_mask]
            assert np.array_equal(arr[parent_mask], parent[parent_mask])
        assert arr.shape == locked.shape
        assert np.array_equal(arr[:, :, 3], before[:, :, 3])
        assert np.array_equal(arr[base_mask], locked[base_mask])
        count = save_checked(arr, ROOT / f'{name}.png')
        saved = np.array(Image.open(ROOT / f'{name}.png').convert('RGBA'))
        assert np.array_equal(saved[base_mask], locked[base_mask])
        # Two independent landmarks locate the inherited core and ground without
        # using the changing outer silhouette or its center of mass.
        for x0, y0, x1, y1 in [(550, 440, 705, 600), (560, 1080, 745, 1156)]:
            reference = locked[y0:y1, x0:x1]
            landmark = reference[:, :, 3] > 127
            assert np.array_equal(saved[y0:y1, x0:x1][landmark], reference[landmark])
        assert not np.any(saved[0, :, 3]) and not np.any(saved[-1, :, 3])
        assert not np.any(saved[:, 0, 3]) and not np.any(saved[:, -1, 3])
        yy, xx = np.where(saved[:, :, 3] > 127)
        assert yy.max() == 1155
        palette_used = np.unique(saved[saved[:, :, 3] > 0, :3], axis=0)
        union.update(tuple(c) for c in palette_used)
        if name == 'tier-4-oathbind':
            assert any(np.all(saved[:, :, :3] == RGB[13], axis=2).flat)
            assert any(np.all(saved[:, :, :3] == RGB[14], axis=2).flat)
        if name == 'tier-4-doomseal':
            assert any(np.all(saved[:, :, :3] == RGB[15], axis=2).flat)
        frames[name] = saved
        report['sprites'].append({
            'file': f'{name}.png', 'parent': parent_name, 'color_count': count,
            'base_changed_pixels': int(np.count_nonzero(np.any(saved[base_mask] != locked[base_mask], axis=1))),
            'inherited_landmark_offset': [0, 0], 'ground_anchor': [627, 1156],
            'visible_bounds': [int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1],
            'transparent_border': True, 'palette_sweep_changed_pixels': int(np.count_nonzero(np.any(before != saved, axis=2))),
            'sha256': hashlib.sha256((ROOT / f'{name}.png').read_bytes()).hexdigest(),
        })
    assert len(union) <= 16
    report['family_color_count'] = len(union)
    report['passed'] = True
    (ROOT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')

    # Review-only resizing; delivered sprites and layer pixels remain untouched.
    font_path = Path('C:/Windows/Fonts/segoeui.ttf')
    title = ImageFont.truetype(str(font_path), 34)
    label = ImageFont.truetype(str(font_path), 22)
    small = ImageFont.truetype(str(font_path), 17)
    sheet = Image.new('RGB', (2000, 770), '#1c2421')
    draw = ImageDraw.Draw(sheet)
    draw.text((40, 18), 'OBELISK  /  THE RUNE MONOLITH', font=title, fill='#d0c4a9')
    draw.text((40, 62), 'Three cumulative tiers + two independent final branches', font=label, fill='#929b91')
    animation = []
    for i, (name, _, caption) in enumerate(STAGES):
        im = Image.fromarray(frames[name])
        preview = im.resize((390, 390), Image.Resampling.LANCZOS)
        sheet.paste(preview, (i * 400 + 5, 98), preview)
        draw.text((i * 400 + 200, 502), caption, font=label, fill='#d0c4a9', anchor='mm')
        thumb = im.resize((128, 128), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (i * 400 + 136, 536), thumb)
        frame = Image.new('RGBA', (400, 450), '#1c2421')
        frame.alpha_composite(preview, (5, 10))
        ImageDraw.Draw(frame).text((200, 424), caption, font=label, fill='#d0c4a9', anchor='mm')
        animation.append(frame)
    draw.text((40, 675), '128 px canvas previews above  /  Fixed placement: x 627, ground y 1156  /  Full assets: 1254 x 1254 RGBA', font=small, fill='#929b91')
    for i, color in enumerate(RGB):
        x = 40 + i * 120
        draw.rectangle((x, 711, x + 101, 735), fill=tuple(color))
        draw.text((x, 741), '#' + ''.join(f'{c:02X}' for c in color), font=small, fill='#b9bdad')
    sheet.save(ROOT / 'family-review.png')
    animation[0].save(ROOT / 'alignment-preview.webp', save_all=True, append_images=animation[1:], duration=950, loop=0, lossless=True)
    print(json.dumps({'passed': True, 'sprites': len(frames), 'family_colors': len(union), 'base_changed_pixels': 0, 'offset': [0, 0]}))


if __name__ == '__main__':
    main()
