# Hiloan campaign map

The active campaign map is a lightweight 2D isometric tile map implemented in
`res://src/main/campaign_map_canvas.gd`.

## Structure

- An 80 by 50 runtime grid provides 4,000 addressable world cells. A separate
  48 by 30 design coordinate system preserves the authored geography while
  adding roughly 2.8 times as many cells for future levels and landmarks. The
  current continent mask contains 2,291 land and island cells.
- Layered value noise controls coastline shape, terrain tint and elevation, so
  the map remains reproducible without looking like a flat board.
- Coast tiles add shallow-water foam and cliff shading; floating islands add
  deeper escarpments and occasional waterfalls.
- The northern Nether River, Heren industrial coast, Loand woodland, Datt
  transport hub, southern frontier and archipelago, and western floating
  islands are authored as distinct regions.
- Datt's crossing canals, future rail, regional landmarks, forests, fields,
  mountains, ships and airships are drawn directly by Godot and require no
  external 3D assets.
- The active map viewport renders at 1920 by 1080 with 2x MSAA. Terrain,
  buildings and infrastructure are vector-drawn CanvasItem geometry rather
  than a single low-resolution background image.
- Datt and the modern port are multi-tile districts. Their towers, warehouses,
  exchange, terminals, cargo piers, cranes and vessels are separate draw
  elements, so the districts can be expanded without replacing the continent.
- The eastern river reaches the coastal bay west of the modern port. Warehouses
  and container berths remain on the eastern shore instead of blocking the
  river mouth.
- Port water is never painted over land. Cargo piers are anchored in ocean
  cells south of the district, with visible pilings, crane feet and rail bases
  connecting the gantries to their decks.
- Rivers that reach the coastline use a dedicated elevation transition from
  the final land cell to the first ocean cell, so their mouths remain visibly
  connected to sea level instead of stopping at the coastal cliff.
- The Nether landmark and eastern river source sit on a connected polar
  peninsula rather than offshore. Infrastructure paths stop at their first
  coastline, preventing detached river or railway fragments from reappearing
  on islands across open water.
- River valleys use continuous downhill profiles through biome boundaries.
  Roads stay on connected land, randomized buildings reserve clear railway,
  road and waterway cells, and every remaining transport crossing has an
  explicit bridge.
- Rendering is ordered as terrain, embedded waterways and roads, bridges,
  vegetation, then buildings. Infrastructure tiles sample terrain elevation,
  roads reserve clear verges, and crossings use separate bridge decks instead
  of drawing one line over another.
- Runtime tiles are 52 by 26 units. Combined with the 80 by 50 grid, this makes
  the projected continent about 35 percent wider and taller than the previous
  48 by 30 version while increasing placement density. The default camera is a
  regional view; zoom out for the continent overview or drag the camera to
  inspect each country at model scale.
- Roads, railways, rivers and canals are assembled from projected tile modules.
  Every entrance, exit, turn, shoulder and surface texture shares the same 2:1
  axes as the ground diamond, so infrastructure cannot drift into screen-space
  angles that disagree with the terrain.
- Loand's castle is a multi-part isometric model made from a raised bailey,
  outer walls, four corner towers, a central keep, gatehouse, chapel and flag.
- Psetia's southern islands contain compact Southeast Asian-inspired stilt
  houses, steep roofs, tiered temples and timber piers. Ocean vessels are
  anchored to validated water cells and use wakes to keep them visually in the
  water rather than on top of island tiles.
- Western floating islands contain cyan rune sanctuaries, standing portals,
  crystals and a magical observatory alongside the existing air traffic.
- Heren's mountain mines use rock-backed mine mouths, timber portals,
  conveyors, processing sheds, ore carts and spoil piles, distinct from the
  factories along the eastern coast.
- Secondary regional props follow the base 52 by 26 tile scale: villages,
  island settlements, mines, vessels and magical structures stay within one
  or two local cells, while only capital districts use a larger footprint.
- Campaign flow is configured in `assets/config/hiloan_campaign.json`. The
  JSON owns region bounds and biomes, stage order, candidate level IDs, travel
  modes, the deterministic placement seed, and marker clearances.
- The map shows completed choices, the selected unfinished point, and all
  candidates in the next unselected stage. Entering one candidate persists the
  choice and removes its siblings; completing it reveals the following stage.
  Multiple stages can use the same region.
- Candidate points are placed on matching land biomes and avoid waterways,
  roads, railways, and landmark footprints. Procedural details are skipped in
  a small radius around visible points to preserve a readable clearing.
- Candidate route lines stay disabled because points in one active set are
  alternatives, not sequential destinations. The first active point is focused
  automatically when the map opens.

## Controls

- Mouse wheel: zoom between the continent overview and landmark detail.
- Middle or right mouse drag: pan.
- Single-click or hover a marker: show its level details.
- Double-click a marker: enter the level.
- The Reset View button restores the regional development view.

## Editing

Biome rules live in `_biome_at()`, the irregular land mask in
`_is_world_tile()`, relief in `_elevation_at()`, and landmarks in
`_draw_landmarks()`. Ground roads are authored in `_draw_ground_roads()`.
Level positions and names remain data-driven in `res://src/map/map_catalog.gd`.
