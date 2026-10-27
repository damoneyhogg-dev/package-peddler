# Free realistic character pipeline

## Selected pipeline

1. Use private still frames extracted from the owner's videos as likeness, clothing, and body-reference material only.
2. Build the human base with the installed and verified MPFB 2.0.17 (MakeHuman Plugin for Blender) using bundled MakeHuman assets. Standalone MakeHuman 1.3.0 is the fallback if MPFB becomes incompatible with Blender.
3. For the strict open-source path, rig in Blender with native armatures/Rigify where appropriate and use self-authored or separately verified CC0 animation data. Mixamo remains an optional proprietary exception only if the owner later approves it.
4. Use Blender to clean the mesh, retarget and combine animations, reduce textures/geometry, and export GLB.
5. Use Godot AnimationTree for idle/walk/run/turn/lift/carry blending and add foot/hand IK where interactions require it.

## Implemented character milestone (2026-10-09)

- MPFB creates the courier from bundled CC0 MakeHuman data in Blender 5.2.2.
- The `game_engine` rig exports with 53 deforming bones and no proprietary source files.
- Hidden authoring/helper geometry is removed, producing a 26,756-triangle runtime mesh within the Intel UHD 620 budget.
- Four flat-color materials provide visible skin, a high-visibility safety top, pants, and shoes without heavy procedural shaders or texture memory.
- Idle, walk, and run cycles are authored in the local build script and embedded in the GLB.
- Godot imports all three clips and the live controller switches among them based on movement speed.
- This is a functional rigged vertical-slice character, not final likeness art. Hair, refined clothing geometry, three rendered vest variants, richer facial detail, interaction clips, IK, and an AnimationTree blend graph remain later work.

## Why video frames are references, not the rig

A normal video provides changing 2D projections, not a clean 3D mesh, skeleton, skin weights, or complete hidden surfaces. Frames can guide likeness and clothing, but the game still needs a modeled body, rig, animation clips, and collision representation. Accurate reconstruction would require controlled multi-angle capture or photogrammetry; the available clips are useful face references but mostly close, low-angle views rather than neutral full-body coverage.

## License evidence

- MakeHuman's official repository states that bundled graphical assets are CC0 and that exported output is the user's data with no MakeHuman limitation. Third-party MakeHuman repository assets remain excluded unless separately reviewed: <https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md>
- MPFB is the maintained Blender-integrated MakeHuman workflow and is distributed by the MakeHuman community under GPL-3.0-or-later; its bundled MakeHuman assets are CC0: <https://github.com/makehumancommunity/mpfb2>
- Official MPFB installation page: <https://extensions.blender.org/add-ons/mpfb/>
- Adobe's official Mixamo FAQ states that Mixamo is free with an Adobe ID and its characters and animations may be used royalty-free in personal, commercial, and nonprofit video games: <https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html>
- Godot recommends glTF 2.0 / GLB for imported 3D scenes: <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html>

## Acquisition and export checklist

1. MPFB 2.0.17 is installed from Blender's official Extensions release and verified with SHA-256 `4f0a879d64a39bf646fbf5f53601ac678855da329d650617dca5737548239a87`.
2. Create the courier in a neutral T-pose using only core CC0 assets. **Complete for the vertical-slice base.**
3. Build and test the humanoid rig in Blender; use Rigify only where its generated rig fits the production skeleton and export requirements. **Complete using MPFB's 53-bone game-engine rig.**
4. Author or acquire separately verified CC0 clips for idle, walk, run, backward, strafe, starts, stops, 90/180-degree turns, bend, lift, carry, set-down, door interaction, scanning/phone use, vehicle entry, seated driving, and vehicle exit.
5. If the open-source animation route cannot meet the milestone, record Mixamo as an explicit proprietary exception before downloading anything.
6. Clean, retarget, and combine the clips in Blender. **Complete for locally authored idle/walk/run; interaction coverage remains.**
7. Export the optimized character and animations as GLB for Godot. **Complete and contract-tested.**

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
- A later private clothing photo adds a long neon mesh vest with orange/silver reflective bands and a blue/gray zip-front courier vest with broad silver panels. Both are approved only as fictionalized, unbranded silhouette/material references.
- Driver art must support ages 21-65 and slim, average, athletic, dad-bod, and plus-size builds across a respectful mix of fictional Asian, Caribbean, American, European, and other backgrounds. These are presentation choices with identical gameplay capability.
- This materially improves body proportion, clothing, vest, and gait reference.
- It still does not replace the clean mesh, skeleton, skin weights, or animation clips required for gameplay.
