# RimWorld-style campaign map

The active campaign map is a lightweight 2D isometric tile map implemented in
`res://src/main/ring_world_map.gd`. It replaces the previous Terrain3D world.

## Structure

- A deterministic 48 by 30 visual grid defines the continent and biomes.
- Coastlines are varied by deterministic noise rather than a rectangular mask.
- The northern Nether River, Heren industrial coast, Loand woodland, Datt
  transport hub, southern frontier and archipelago, and western floating
  islands are authored as distinct regions.
- Rivers, Datt's crossing canals, landmarks, ships, and terrain details are
  drawn directly by Godot and require no external 3D assets.
- Campaign markers use the positions and travel modes from `map_catalog.gd`.
- The existing progress repository exposes completed levels and only the next
  unlocked level, so the route grows as the player advances.

## Controls

- Mouse wheel: zoom.
- Middle or right mouse drag: pan.
- Single-click or hover a marker: show its level details.
- Double-click a marker: enter the level.
- The Reset View button restores the full-continent view.

## Editing

Biome rules live in `_biome_at()`, the irregular land mask in
`_is_world_tile()`, and landmarks in `_draw_landmarks()`. Level positions and
names remain data-driven in `res://src/map/map_catalog.gd`.
