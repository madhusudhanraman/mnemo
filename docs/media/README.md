# Behaviour demos

These GIFs render the production model and behaviour curves offline. They are illustrative model renders, not recordings of the native app. Lighting approximates the WebGL studio. Each loop includes a short closing crossfade.

With Node.js on PATH and Python with numpy and Pillow:

```sh
python3 prototype/review/render-demos.py
```

The exporter uses `ghost.mjs`, `behaviours.mjs` and its CPU reference for the spiral deformation. The app uses the equivalent GPU deformation. GIFs show gestures on demand; autonomous desktop gestures are spaced further apart.
