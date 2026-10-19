from pathlib import Path
import subprocess,sys,shutil
from PIL import Image
root=Path(__file__).parent
node=shutil.which('node') or 'node'
python=sys.executable
frames=[]
for i in range(14):
    subprocess.run([node,str(root/'export-model.mjs'),str(i*.25)],check=True,capture_output=True)
    subprocess.run([python,str(root/'render.py'),'motion-frame.png'],check=True,capture_output=True)
    image=Image.open(root/'motion-frame.png').crop((600,48,1200,648)).resize((420,420),Image.Resampling.LANCZOS)
    frames.append(image)
    print('Rendered motion pose',i+1,'of 14',flush=True)
frames+=frames[-2:0:-1]
frames[0].save(root/(sys.argv[1] if len(sys.argv)>1 else 'ghost-motion.gif'),save_all=True,append_images=frames[1:],duration=250,loop=0,optimize=False)
(root/'motion-frame.png').unlink()
print(root/(sys.argv[1] if len(sys.argv)>1 else 'ghost-motion.gif'))
