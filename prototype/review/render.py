"""Software-render the actual exported Three.js meshes, without a browser."""
from pathlib import Path
import json,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).parent
meshes=json.loads((root/'mesh.json').read_text())
size=600
views=[('FRONT',0),('THREE-QUARTER',.7),('BACK',np.pi)]
strip=Image.new('RGB',(size*3,size+64),'#151521')
for vi,(label,yaw) in enumerate(views):
    image=Image.new('RGB',(size,size),'#242134'); draw=ImageDraw.Draw(image)
    c,s=np.cos(yaw),np.sin(yaw)
    yawmat=np.array([[c,0,s],[0,1,0],[-s,0,c]])
    tilt=.105
    pitch=np.array([[1,0,0],[0,np.cos(tilt),-np.sin(tilt)],[0,np.sin(tilt),np.cos(tilt)]])
    rot=pitch@yawmat
    triangles=[]; fills=[]; depths=[]
    for m in meshes:
        vertices=np.array(m['vertices']).reshape(-1,3)@rot.T
        normals=np.array(m['normals']).reshape(-1,3)@rot.T
        idx=np.array(m['indices']).reshape(-1,3)
        tri=vertices[idx]; n=normals[idx].mean(axis=1); n/=np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-8)
        keep=n[:,2]>-.08
        tri=tri[keep];n=n[keep]
        illumination=np.ones(len(n))*.40
        for l,power in [(np.array([-.5,.8,1]),.52),(np.array([.7,.3,.4]),.17)]:
            l=l/np.linalg.norm(l);illumination+=np.maximum(n@l,0)*power
        base=np.array(m['color'])
        if m.get('colors'):base=base[None,:]*np.array(m['colors']).reshape(-1,3)[idx].mean(axis=1)[keep]
        rgb=base*illumination[:,None]
        if not m['unlit']:
            h=np.array([-.3,.45,1.7]);h/=np.linalg.norm(h)
            spec=np.maximum(n@h,0)**(30 if m['roughness']>.3 else 65)
            rgb+=spec[:,None]*(.12 if m['roughness']>.3 else .50)
        else:rgb=np.tile(base,(len(n),1))
        rgb=np.clip(np.where(rgb<=.0031308,rgb*12.92,1.055*np.maximum(rgb,0)**(1/2.4)-.055)*255,0,255).astype('uint8')
        # Perspective with the same 35-degree vertical field of view.
        scale=(size/2)/np.tan(np.deg2rad(35/2))/(10-tri[:,:,2])
        screen=np.stack([size/2+tri[:,:,0]*scale,size/2-(tri[:,:,1]-.05)*scale],axis=-1)
        triangles.extend(screen.tolist());fills.extend(map(tuple,rgb.tolist()));depths.extend(tri[:,:,2].mean(axis=1).tolist())
    for i in np.argsort(depths):draw.polygon([tuple(v) for v in triangles[i]],fill=fills[i])
    strip.paste(image,(vi*size,48))
    ImageDraw.Draw(strip).text((vi*size+20,16),label,fill='#d8c9ef')
path=root/(sys.argv[1] if len(sys.argv)>1 else 'review.png');strip.save(path);print(path)
