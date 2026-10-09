# Free realistic character pipeline

## Selected pipeline

1. Use private still frames extracted from the owner's videos as likeness, clothing, and body-reference material only.
2. Build the human base with MPFB 2.0.17 (MakeHuman Plugin for Blender) using bundled MakeHuman assets. Standalone MakeHuman 1.3.0 is the fallback if MPFB is incompatible with the installed Blender version.
3. Use Mixamo's humanoid auto-rigger and royalty-free game animations.
4. Use Blender to clean the mesh, retarget and combine animations, reduce textures/geometry, and export GLB.
5. Use Godot AnimationTree for idle/walk/run/turn/lift/carry blending and add foot/hand IK where interactions require it.

## Why video frames are references, not the rig

A normal video provides changing 2D projections, not a clean 3D mesh, skeleton, skin weights, or complete hidden surfaces. Frames can guide likeness and clothing, but the game still needs a modeled body, rig, animation clips, and collision representation. Accurate reconstruction would require controlled multi-angle capture or photogrammetry; the available clips are useful face references but mostly close, low-angle views rather than neutral full-body coverage.

## License evidence

- MakeHuman's official repository states that bundled graphical assets are CC0 and that exported output is the user's data with no MakeHuman limitation. Third-party MakeHuman repository assets remain excluded unless separately reviewed: <https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md>
- MPFB is the maintained Blender-integrated MakeHuman workflow and is distributed by the MakeHuman community: <https://github.com/makehumancommunity/mpfb2>
- Official MPFB installation page: <https://extensions.blender.org/add-ons/mpfb/>
- Adobe's official Mixamo FAQ states that Mixamo is free with an Adobe ID and its characters and animations may be used royalty-free in personal, commercial, and nonprofit video games: <https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html>
- Godot recommends glTF 2.0 / GLB for imported 3D scenes: <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html>

## Acquisition and export checklist

1. Install MPFB from Blender's official Extensions page.
2. Create the courier in a neutral T-pose using only core CC0 assets.
3. Export a clean FBX with textures for Mixamo auto-rigging.
4. Sign into Mixamo with an Adobe ID.
5. Download one base FBX with skin, then animation clips without skin.
6. Acquire idle, walk, run, backward, strafe, starts, stops, 90/180-degree turns, bend, lift, carry, set-down, door interaction, scanning/phone use, vehicle entry, seated driving, and vehicle exit.
7. Clean, retarget, and combine the clips in Blender.
8. Export the optimized character and animations as GLB for Godot.

## Intel UHD 620 performance budget

- Player mesh: 20,000-35,000 triangles.
- Deforming skeleton: 60-80 bones, no more than four bone weights per vertex.
- Materials: 2-4 slots, primarily 1K textures.
- LOD targets: approximately 50% and 25% of the primary mesh.
- Bake materials and compress animations; do not ship MPFB's heavier procedural materials directly.
- Integrate Mixamo content into the packaged game; do not distribute raw FBX files or animation files separately.

## Privacy and distribution

- Extracted likeness frames remain in `references/private-video-frames/`, which is ignored by Git.
- Source video frames are not published or packaged with the game.
- The final exported character is included only after owner review.
- Mixamo source files will not be sold or distributed as a standalone asset pack.

## Additional capture that would improve likeness

- Straight-on neutral face in even light.
- Left or right side profile.
- Full body standing from front, side, and back in ordinary fitted clothing.
- Short neutral walk filmed from the side and front for motion reference.

## Owner reference received 2026-10-09

- A 13.8-second warehouse video provides clear full-body front and back views, a walking approach, black shirt, denim shorts, black shoes, and a black high-visibility utility vest with fluorescent reflective trim.
- A private clothing photo adds two distinct vest references: a neon-yellow zippered mesh safety vest with horizontal reflective bands and utility pockets, and a red courier utility vest with broader reflective panels and a heavier pocketed silhouette. Use fictionalized, unbranded versions as visible customization options.
- This materially improves body proportion, clothing, vest, and gait reference.
- It still does not replace the clean mesh, skeleton, skin weights, or animation clips required for gameplay.
