# Mnemo floating sheet ghost

Open `index.html` in a browser. The page is self-contained and works from a local
file URL without network access. The native desktop app is in `../desktop/build/Mnemo.app` (see `../desktop/README.md`).
The previous octopus remains available as
`octopus-prototype.html`.

- Click Mnemo to add a reminder; drag to move; Shift-drag to rotate.
- In the desktop app he gently wanders around his last resting spot.
- Pirouettes and Peekaboo are automatic idle behaviours.
- My reminders opens the saved reminder form and list.
- Peekaboo fades the sheet away, leaves the eyes, then softly returns.
- Pause stops cloth and body motion. Reduced-motion preferences start paused.

`ghost.mjs` is the editable character source. A single parametric sheet has a
rounded crown, soft vertical folds and a loose open hem. Two travelling waves
and delayed sway increase toward the free edge. Eyes follow the fabric's local
surface and normal. The desktop app deforms the cloth on the GPU; the CPU surface remains available for model checks and offline renders.

After changing the model or `src/index.template.html`, run `node prototype/build.mjs`
from the workspace root to rebuild the standalone page.

Verification from the workspace root:

```
node prototype/review/check-ghost.mjs
node prototype/review/check-page.mjs
node prototype/review/export-model.mjs
python3 prototype/review/render-smooth.py ghost-review.png
python3 prototype/review/animate.py ghost-motion.gif
```

Offline review renders use the actual exported scene geometry, smooth normals,
vertex colors and depth testing. Their lighting approximates the WebGL studio;
they are not browser screenshots. Preview GIFs show exported animated poses in a
forward/reverse loop. Live animation proceeds continuously forward.

The archived octopus source is `octopus.mjs`; its geometry check remains
`review/check-model.mjs`. Three.js 0.170.0 is vendored under `vendor/` (MIT license).

Browser reminders are stored in this browser and only alert while the page is
running. The native app stores reminders separately and shows persistent thought bubbles without macOS notification banners.
