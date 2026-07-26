# Hiloan 3D creator assets

The meshes in this directory are generated from the MakeHuman HM08 base mesh
and MakeHuman community proxy assets.

- Source: https://github.com/makehumancommunity/makehuman
- Community assets: https://github.com/makehumancommunity/makehuman-assets
- Most source assets: CC0 1.0
- Underwear mesh: `mindfront_male_swimming_trunks_02` by Mindfront,
  from the MakeHuman Pants03 asset pack, CC-BY
  (https://static.makehumancommunity.org/assets/assetpacks/pants03.html)

`source/` keeps the exact source meshes, fitting data, and morph targets used by
the project. Run `src/tools/build_hiloan_3d_assets.py` to rebuild the GLB files.

The current body, muscle, face, eyebrow, hair, and outer-garment sources also
come from the CC0 MakeHuman repositories. Skin maps are rebuilt as one neutral,
seamless surface without baked anatomical lighting; visible muscle definition
comes from body geometry and scene lighting. Eyes, lips, and eyebrows remain
independent creator parts. The underwear is a complete fitted boxer-style
garment proxy with two short leg tubes, a proper waist, leg openings, and
crotch topology rather than faces cut from the body mesh.

The earlier Hiloan textile studies generated with the built-in OpenAI image
generation tool are retained as `textures/concept_*_textile.png` for art
direction reference, but they are no longer tiled directly over garments.

Run `src/tools/build_hiloan_material_maps.py` to rebuild material maps, then run
`src/tools/build_hiloan_3d_assets.py` to rebuild all fitted bodies, eyebrows,
hair, garments, shoes, and curved accessory meshes.
