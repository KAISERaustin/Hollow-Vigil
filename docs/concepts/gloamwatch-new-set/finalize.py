"""Final color-only material normalization, integer alignment and saved-file checks.

Run with the original ImageGen output directory as the sole argument.
The user's IMAGE_GENERATION_INSTRUCTIONS.md explicitly permits these operations.
"""
from pathlib import Path
import sys, json, hashlib
import numpy as np
from PIL import Image, ImageDraw
from prepare import PAL, HEX, ROOT

SOURCES = {
    'tier-1': 'exec-24c5be9d-1b82-4891-acfd-2a0e618c2918.png',
    'tier-2': 'exec-32dfbaca-c3a8-4061-8720-e9fde37f41ab.png',
    'tier-3': 'exec-316119bb-c060-4a5e-beec-86544d4fc97c.png',
    'tier-4-poison': 'exec-4a3e5360-da51-475f-a1e6-a4ea8598c6b0.png',
    'tier-4-ice': 'exec-1ed77524-630a-4c59-b6a1-e45b6a37e39f.png',
}

def anchor(a):
    # Ground point: horizontal midpoint of the bottom doorstep front face,
    # and first pixel below that face. Search only the unchanged central step.
    solid = (a[:,:,3] > 240) & (a[:,:,:3].max(2) > 28)
    # Flood the face, bounded to exclude unrelated foundation stones. Its box
    # stays translation invariant even when the hand-drawn lower edge slopes.
    pending=[(620,1070)]; seen=set()
    while pending:
        px,py=pending.pop()
        if (px,py) in seen or not (480<px<770 and 1042<py<1105) or not solid[py,px]: continue
        seen.add((px,py))
        pending.extend(((px-1,py),(px+1,py),(px,py-1),(px,py+1)))
    assert len(seen)>500
    left=min(p[0] for p in seen); right=max(p[0] for p in seen)
    bottom=max(p[1] for p in seen)
    return [(left+right)//2,bottom+1], [left,right,bottom]

def normalize(a, name):
    rgb = a[:,:,:3].astype(float)
    r,g,b = rgb.transpose(2,0,1)
    light = rgb.mean(2)
    y,x = np.indices(light.shape)
    # Piecewise exposure calibration from unchanged front/side wall surfaces.
    # This restores the tier-one assignments rather than trusting later exposure.
    front = np.median(light[800:820,530:550])
    side = np.median(light[800:820,695:710])
    idx = np.select([light<18,light<35,light<(front*.78),light<(front+side)*.5],
                    [0,1,4,4], default=5)
    idx[light > side*1.25] = 6
    # Cool dark rocks keep the same shadow and main planes throughout.
    rock = (y>865) & ((x<560)|(x>695))
    idx[rock & (light>=35)] = np.where(light[rock & (light>=35)] < front*.85, 2, 4)
    # Roof and finial have two fixed dark planes. Recolor only, keep contours.
    roof = (y<445) & ~((x>710)&(y<342)) & (light>28)
    idx[roof] = np.where(x[roof]<627,2,3)
    # Existing warm timber must not drift into red cloth palette entries.
    wood = (r>g*1.12)&(g>b*1.12)&(light>25)
    idx[wood] = np.where(light[wood]<45,7,8)
    cloth_area = ((x>735)&(y<330)) | ((x>578)&(x<675)&(y>640)&(y<807))
    cloth = cloth_area & (r>g*1.20)&(r>b*1.20)&(light>30)
    idx[cloth] = np.where(light[cloth]<45,9,10)
    insignia = (x>597)&(x<655)&(y>677)&(y<764)&(light>125)&(r<g*1.3)
    if name not in ('tier-1','tier-2'): idx[insignia] = 11
    # Restore the two unchanged stair faces separately from wall exposure.
    step = (y>990)&(y<1098)&(x>490)&(x<748)&(light>32)
    idx[step] = np.where(light[step] < np.median(light[1004:1020,580:680])*.72, 2,4)
    if name == 'tier-4-poison':
        accent = (x<545)&(y>473)&(y<614)&(g>b*1.35)&(g>r*.95)&(light>30)
        idx[accent] = np.where(light[accent]<65,14,15)
    if name == 'tier-4-ice':
        accent = (x<490)&(y>426)&(y<590)&(b>r*1.15)&(b>g*1.025)&(light>30)
        idx[accent] = np.where(light[accent]<100,12,13)
    idx[light<18] = 0
    out = np.dstack((PAL[idx],a[:,:,3]))
    out[a[:,:,3]==0,:3] = 0
    assert np.array_equal(a[:,:,3],out[:,:,3])
    return out

def main(source):
    report = {'canvas':[1254,1254], 'palette':['#'+h for h in HEX],
              'anchor_definition':'bottom-step front face midpoint; y immediately below face',
              'files':{}, 'runtime_integration':False}
    originals = {n:np.array(Image.open(source/f).convert('RGBA')) for n,f in SOURCES.items()}
    target,_ = anchor(normalize(originals['tier-1'],'tier-1'))
    report['shared_anchor'] = target
    final = {}
    for name,a in originals.items():
        assert a.shape == (1254,1254,4)
        out = normalize(a,name)
        before,edges = anchor(out)
        dx,dy = target[0]-before[0],target[1]-before[1]
        sx0,sx1=max(0,-dx),min(1254,1254-dx)
        sy0,sy1=max(0,-dy),min(1254,1254-dy)
        aligned = np.zeros_like(out)
        assert np.count_nonzero(out[sy0:sy1,sx0:sx1,3]) == np.count_nonzero(out[:,:,3]), 'Translation would clip pixels'
        aligned[sy0+dy:sy1+dy,sx0+dx:sx1+dx] = out[sy0:sy1,sx0:sx1]
        assert anchor(aligned)[0] == target, (name,before,[dx,dy],anchor(aligned)[0],target)
        path = ROOT/(name+'.png')
        Image.fromarray(aligned).save(path)
        reopened = np.array(Image.open(path))
        assert np.array_equal(reopened,aligned)
        colors = np.unique(reopened[:,:,:3][reopened[:,:,3]>0],axis=0)
        assert all(tuple(c) in set(map(tuple,PAL)) for c in colors)
        final[name] = reopened
        report['files'][name] = {'source':SOURCES[name], 'source_anchor':before,
            'step_edges':edges,'translation':[dx,dy], 'final_anchor':anchor(reopened)[0],
            'visible_colors':len(colors), 'palette_pass':True, 'alpha_preserved':True,
            'resized':False, 'clipped_pixels':0, 'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    samples = {'wall_front':[540,810], 'wall_side':[700,810], 'roof_left':[550,380],
               'roof_right':[690,380], 'wood':[700,550], 'upper_step':[620,1010], 'lower_step':[600,1060]}
    sampled = {name:{key:list(map(int,a[p[1],p[0],:3])) for key,p in samples.items()} for name,a in final.items()}
    assert all(v == sampled['tier-1'] for v in sampled.values()), sampled
    report['shared_material_samples'] = {'coordinates':samples,'rgb':sampled,'match_tier_one':True}
    (ROOT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    board=Image.new('RGB',(1500,570),'#899087')
    draw=ImageDraw.Draw(board)
    frames=[]
    for i,(name,a) in enumerate(final.items()):
        im=Image.fromarray(a)
        large=im.resize((300,300),Image.Resampling.NEAREST)
        board.paste(large,(i*300,20),large)
        draw.text((i*300+100,330),name,fill='#000000')
        small=im.resize((145,145),Image.Resampling.NEAREST)
        board.paste(small,(i*300+78,370),small)
        frame=Image.new('RGBA',im.size,'#899087'); frame.alpha_composite(im)
        frames.append(frame)
    draw.text((20,550),'Review only: native sprites retain 1254 x 1254 canvas and original alpha.',fill='#000000')
    board.save(ROOT/'family-review.png')
    frames[0].save(ROOT/'alignment-preview.webp',save_all=True,append_images=frames[1:],duration=900,loop=0,lossless=True)
    print(json.dumps(report,indent=2))

if __name__ == '__main__': main(Path(sys.argv[1]))
