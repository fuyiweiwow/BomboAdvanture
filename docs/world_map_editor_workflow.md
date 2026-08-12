# World map editor workflow

The project includes four complementary Godot editor plugins:

- Terrain3D 1.3.0-alpha1: terrain sculpting and texture painting.
- Godot Asset Placer 1.5.4: thumbnail library and surface-aware placement.
- ProtonScatter 4.0: non-destructive vegetation and prop scattering.
- Road Generator 0.9.3: spline roads, intersections, and Terrain3D projection.

ProtonScatter includes a one-line Godot 4.7 compatibility fix in
`src/scatter.gd`: its dynamic property getter now returns `null` for unknown
properties, as required by the stricter 4.7 parser.

The shared Asset Placer library is stored at
`res://assets/world_map_asset_library.json`. Existing environment models are
automatically indexed into Nature, Medieval, Future, Industry, Roads,
Maritime, and Urban collections. The JSON file is intentionally committed so
the folder setup and collection assignments are shared across machines.

## First editor launch

1. Open the project and wait until Godot finishes importing resources.
2. Confirm all four entries are enabled under Project > Project Settings >
   Plugins.
3. Open the 3D map scene, then open the Asset Placer dock at the bottom.
4. In Asset Placer, press Sync if thumbnails do not appear immediately.
5. Select Terrain3D placement mode and choose the scene's Terrain3D node.

## Recommended order of work

1. Sculpt and paint the large landforms with Terrain3D.
2. Draw only major roads with Road Generator and project them onto Terrain3D.
3. Place landmarks, ports, castles, and city blocks with Asset Placer.
4. Use ProtonScatter for trees, rocks, shrubs, and other repeated details.
5. Add level nodes and travel routes only after the geography is stable.

For clean scene trees, enable Asset Placer auto-grouping and set a primary
collection when batch-managing assets. Placed nodes will then be grouped under
collection-named Node3D parents.

## Plugin sources

- Godot Asset Placer: https://github.com/levinzonr/godot-asset-placer
- ProtonScatter: https://github.com/HungryProton/scatter
- Road Generator: https://github.com/TheDuckCow/godot-road-generator

All three added plugins are distributed under the MIT license. Their license
files are included inside their respective addon directories.
