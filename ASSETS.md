# Package Peddler asset register

This register covers assets currently present in the project. Private user
photos and videos are reference-only and are not runtime assets.

## Existing runtime assets

| Asset | Creator/source | License | Use | Provenance |
|---|---|---|---|---|
| `assets/characters/courier.glb` | Package Peddler project; MPFB/MakeHuman core data | CC0 graphical source/output; MPFB is an authoring tool under GPL-3.0-or-later | Playable courier rig | Full license record and source URLs: `docs/ASSET-LICENSES.md`; hash recorded there |
| `assets/cover/*.png` | OpenAI image generation | Generated project artwork; no third-party source frame embedded | Cover/storefront art only, not gameplay | `assets/cover/PROVENANCE.md` |

## Phase 1 rendering

Phase 1 adds no external 3D models, textures, audio, or licensed gameplay
assets. Procedural sky, lighting, fog, reflection probe, and environment
settings are authored in `src/main.gd`.

## Acquisition rule

Every future imported asset must record its title, creator, source URL,
acquisition date, license, commercial redistribution rights, modification
rights, attribution requirement, and archive SHA-256 before entering the
repository. Approved sources include CC0 or permissively licensed assets from
Kenney, Quaternius, Poly Haven, and ambientCG after individual verification.
