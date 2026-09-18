"""Color-only palette correction and lossless integer placement for this concept set.
Usage: python prepare.py SOURCE_DIRECTORY
Source images are preserved by ImageGen; no resizing or redrawing of deliverables.
"""
from pathlib import Path
import sys, json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
HEX = ['000000','151E1D','222A29','293633','56564E','6D6B60','3D3025','624B35','392724','613B34','BFB295','435862','758F9E','39442B','566333','788346']
PAL = np.array([[int(h[i:i+2],16) for i in (0,2,4)] for h in HEX], dtype=np.uint8)
FILES = dict(zip(['level-1','level-2','level-3','ice','poison'], ['exec-1ea43f83-8e56-4eb3-ad94-6bed2afc7a77.png','exec-47a94d5c-1f5d-4b5b-beca-3af921060531.png','exec-bd056c59-de7f-4555-9d61-e11177faeeba.png','exec-b5ad57f3-a9d7-4900-8019-5292cccf8c7d.png','exec-c7470c89-798e-4a19-8673-f1b9b3e3ad13.png']))

def anchor(a):
    solid = (a[:,:,3] > 240) & (a[:,:,:3].max(2) > 25)
    bottom = int(np.flatnonzero(solid[1040:1130,610])[-1])+1040
    left=right=610
    while solid[bottom-2,left-1]: left-=1
    while solid[bottom-2,right+1]: right+=1
    return [int((left+right+1)/2),bottom+1], [left,right+1]

def run(source):
    report={'canvas':[1254,1254],'anchor_definition':'center of front doorstep; y at top of bottom black contour','target_anchor':[627,1094],'palette':['#'+h for h in HEX],'files':{}}
    for name, filename in FILES.items():
        a=np.array(Image.open(source/filename).convert('RGBA'))
        assert a.shape==(1254,1254,4)
        rgb=a[:,:,:3].astype(float); r,g,b=rgb.transpose(2,0,1)
        y,x=np.indices(a.shape[:2]); light=rgb.mean(2)
        # Normalize generator exposure drift against unchanged front stone sample.
        scale=light[800,530]
        norm=light/max(scale,1)
        idx=np.select([norm<.20,norm<.50,norm<.90,norm<1.22],[0,1,3,4],default=5)
        roof=(y>310)&(y<510)&(b>r*1.03)
        idx[roof]=np.where(x[roof]<620,3,2)
        rock=(y>970)&(b>r*1.07)
        idx[rock]=np.where(light[rock]<light[1035,380],3,4)
        wood=(r>g*1.16)&(g>b*1.17)
        idx[wood]=7
        red=(r>g*1.40)&(r>b*1.30)&((y<320)|((x>560)&(x<660)&(y>620)&(y<790)))
        idx[red]=9
        if name not in ('level-1','level-2'):
            insignia=(x>580)&(x<640)&(y>660)&(y<740)&(light>130)&(r<g*1.28)
            idx[insignia]=10
        if name=='ice':
            ice=(b>r*1.17)&(b>g*1.035)&~roof
            idx[ice]=np.where(light[ice]<115,11,12)
        if name=='poison':
            green=(g>b*1.35)&(g>r*.87)&(r<g*1.20)&(light>25)
            idx[green]=np.select([light[green]<70,light[green]<110],[13,14],default=15)
        idx[light<22]=0
        out=np.dstack([PAL[idx],a[:,:,3]])
        out[a[:,:,3]==0,:3]=0
        assert np.array_equal(out[:,:,3],a[:,:,3])
        before,edges=anchor(out); dx=627-before[0]; dy=1094-before[1]
        aligned=np.zeros_like(out)
        sx0,sx1=max(0,-dx),min(1254,1254-dx); sy0,sy1=max(0,-dy),min(1254,1254-dy)
        assert np.count_nonzero(out[sy0:sy1,sx0:sx1,3])==np.count_nonzero(out[:,:,3]), 'Translation clips pixels'
        aligned[sy0+dy:sy1+dy,sx0+dx:sx1+dx]=out[sy0:sy1,sx0:sx1]
        after,_=anchor(aligned)
        assert after==[627,1094]
        colors=np.unique(aligned[:,:,:3][aligned[:,:,3]>0],axis=0)
        assert all(tuple(c) in set(map(tuple,PAL)) for c in colors)
        Image.fromarray(aligned).save(ROOT/(name+'.png'))
        report['files'][name]={'source':filename,'before_anchor':before,'step_edges_before':edges,'translation':[dx,dy],'after_anchor':after,'visible_color_count':len(colors),'alpha_preserved_before_translation':True,'clipped_pixels':0,'resized':False}
    points={'stone_front':(530,790),'stone_lower_face':(680,810),'wood':(600,900),'roof_left':(540,450),'roof_right':(700,450),'black_window':(675,570)}
    samples={n:{k:Image.open(ROOT/(n+'.png')).getpixel(q)[:3] for k,q in points.items()} for n in FILES}
    assert all(v==samples['level-1'] for v in samples.values())
    report['common_material_samples']={'coordinates':points,'rgb_by_tower':samples,'all_match':True}
    (ROOT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    # Review-only contact sheet and fixed-position animation; sprite PNGs stay native size.
    board=Image.new('RGB',(1500,530),'#899087'); draw=ImageDraw.Draw(board)
    frames=[]
    for i,name in enumerate(FILES):
        im=Image.open(ROOT/(name+'.png'))
        large=im.resize((300,300),Image.Resampling.NEAREST)
        board.paste(large,(i*300,20),large)
        small=im.resize((150,150),Image.Resampling.NEAREST)
        board.paste(small,(i*300+75,345),small)
        draw.text((i*300+110,325),name,fill='#000000')
        frame=Image.new('RGBA',im.size,'#899087'); frame.alpha_composite(im)
        frames.append(frame)
    board.save(ROOT/'family-review.png')
    frames[0].save(ROOT/'alignment-preview.webp',save_all=True,append_images=frames[1:],duration=850,loop=0,lossless=True)
    print(json.dumps(report,indent=2))

if __name__=='__main__': run(Path(sys.argv[1]))
