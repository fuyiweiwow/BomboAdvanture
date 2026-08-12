# RimWorld-style campaign map

The active campaign map is a lightweight 2D isometric tile map implemented in
`res://src/main/ring_world_map.gd`. It replaces the previous Terrain3D world.

## Structure

- A deterministic 48 by 30 visual grid defines the continent and biomes.
- Layered value noise controls coastline shape, terrain tint and elevation, so
  the map remains reproducible without looking like a flat board.
- Coast tiles add shallow-water foam and cliff shading; floating islands add
  deeper escarpments and occasional waterfalls.
- The northern Nether River, Heren industrial coast, Loand woodland, Datt
  transport hub, southern frontier and archipelago, and western floating
  islands are authored as distinct regions.
- Rivers and roads use smoothed paths. Datt's crossing canals, future rail,
  regional landmarks, forests, fields, mountains, ships and airships are drawn
  directly by Godot and require no external 3D assets.
- The active map viewport renders at 1920 by 1080 with 2x MSAA. Terrain,
  buildings and infrastructure are vector-drawn CanvasItem geometry rather
  than a single low-resolution background image.
- Datt and the modern port are multi-tile districts. Their towers, warehouses,
  exchange, terminals, cargo piers, cranes and vessels are separate draw
  elements, so the districts can be expanded without replacing the continent.
- Rendering is ordered as terrain, carved waterways and roads, bridges,
  vegetation, then buildings. Rivers use variable-width bank and water ribbons
  sampled against terrain elevation; roads reserve clear verges and crossings
  use separate bridge decks instead of drawing one line over another.
- The campaign marker and route layer is currently disabled so landmarks stay
  readable while the world art is being developed. Set
  `show_campaign_overlay` on the map scene when that layer is ready to return.
- When enabled, campaign markers use positions and travel modes from
  `map_catalog.gd`, while the progress repository exposes completed levels and
  only the next unlocked level.

## Controls

- Mouse wheel: zoom from the full-continent view into landmark detail.
- Middle or right mouse drag: pan.
- Single-click or hover a marker: show its level details.
- Double-click a marker: enter the level.
- The Reset View button restores the full-continent view.

## Editing

Biome rules live in `_biome_at()`, the irregular land mask in
`_is_world_tile()`, relief in `_elevation_at()`, and landmarks in
`_draw_landmarks()`. Ground roads are authored in `_draw_ground_roads()`.
Level positions and names remain data-driven in `res://src/map/map_catalog.gd`.
