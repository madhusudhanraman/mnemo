"""Offline rasterizer for the actual model; interpolated normals, depth buffer.
Lighting approximates the browser studio, but geometry is identical.
"""
from pathlib import Path
import json,sys
import numpy as np
from PIL import Image,ImageDraw
root=Path(__file__).parent
meshes=json.loads((root/'mesh.json').read_text())
size=480
views=[('FRONT',0),('THREE-QUARTER',.7),('BACK',np.pi)]
strip=Image.new('RGB',(size*3,size+48),'#151521')
light1=np.array([-.5,.8,1]);light1/=np.linalg.norm(light1)
light2=np.array([.7,.3,.4]);light2/=np.linalg.norm(light2)
half=np.array([-.3,.45,1.7]);half/=np.linalg.norm(half)
for vi,(label,yaw) in enumerate(views):
    output=np.zeros((size,size,3))+np.array([36,33,52])/255
    depth=np.full((size,size),-np.inf)
    c,s=np.cos(yaw),np.sin(yaw);tilt=.105
    rot=np.array([[1,0,0],[0,np.cos(tilt),-np.sin(tilt)],[0,np.sin(tilt),np.cos(tilt)]])@np.array([[c,0,s],[0,1,0],[-s,0,c]])
    for m in meshes:
        v=np.array(m['vertices']).reshape(-1,3)@rot.T
        normals=np.array(m['normals']).reshape(-1,3)@rot.T
        normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-8)
        idx=np.array(m['indices']).reshape(-1,3)
        base=np.array(m['color']);colors=np.ones_like(v)*base
        if m.get('colors'):colors*=np.array(m['colors']).reshape(-1,3)
        scale=(size/2)/np.tan(np.deg2rad(35/2))/(10-v[:,2])
        screen=np.stack([size/2+v[:,0]*scale,size/2-(v[:,1]-.05)*scale],axis=-1)
        for indices in idx:
            n=normals[indices]
            if n[:,2].mean()<-.05:continue
            points=screen[indices];x0,y0=points[0];x1,y1=points[1];x2,y2=points[2]
            den=(y1-y2)*(x0-x2)+(x2-x1)*(y0-y2)
            if abs(den)<1e-9:continue
            xmin=max(0,int(np.ceil(points[:,0].min()-.5)));xmax=min(size-1,int(np.floor(points[:,0].max()-.5)))
            ymin=max(0,int(np.ceil(points[:,1].min()-.5)));ymax=min(size-1,int(np.floor(points[:,1].max()-.5)))
            if xmin>xmax or ymin>ymax:continue
            yy,xx=np.mgrid[ymin:ymax+1,xmin:xmax+1];xx=xx+.5;yy=yy+.5
            w0=((y1-y2)*(xx-x2)+(x2-x1)*(yy-y2))/den
            w1=((y2-y0)*(xx-x2)+(x0-x2)*(yy-y2))/den;w2=1-w0-w1
            z=w0*v[indices[0],2]+w1*v[indices[1],2]+w2*v[indices[2],2]
            patchDepth=depth[ymin:ymax+1,xmin:xmax+1]
            mask=(w0>=-1e-6)&(w1>=-1e-6)&(w2>=-1e-6)&(z>patchDepth)
            if not mask.any():continue
            weights=np.stack([w0[mask],w1[mask],w2[mask]],axis=1)
            nn=weights@n;nn/=np.maximum(np.linalg.norm(nn,axis=1)[:,None],1e-8)
            rgb=weights@colors[indices]
            if not m['unlit']:
                illum=.40+np.maximum(nn@light1,0)*.52+np.maximum(nn@light2,0)*.17
                rgb*=illum[:,None]
                spec=np.maximum(nn@half,0)**(30 if m['roughness']>.3 else 65)
                rgb+=spec[:,None]*(.12 if m['roughness']>.3 else .50)
            rgb=np.clip(np.where(rgb<=.0031308,rgb*12.92,1.055*np.maximum(rgb,0)**(1/2.4)-.055),0,1)
            patch=output[ymin:ymax+1,xmin:xmax+1];patch[mask]=rgb;patchDepth[mask]=z[mask]
    strip.paste(Image.fromarray(np.uint8(output*255)),(vi*size,40))
    ImageDraw.Draw(strip).text((vi*size+20,14),label,fill='#d8c9ef')
    print('Rendered',label,flush=True)
path=root/(sys.argv[1] if len(sys.argv)>1 else 'review-smooth.png');strip.save(path);print(path)
