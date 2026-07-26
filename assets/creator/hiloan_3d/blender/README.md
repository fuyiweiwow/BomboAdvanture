# Hiloan Blender refinement draft

Open `hiloan_character_creator_fitting_v2.blend`.

The original `hiloan_character_creator_draft.blend` is preserved as the first
alignment draft.

For manual modeling, open `hiloan_character_creator_source_edit.blend`. It
restores quad-oriented topology where possible and is not intended for direct
Godot export.

For the untouched original quad meshes, open
`hiloan_character_creator_raw_source.blend`. This version bypasses GLB
triangulation entirely and is the recommended file for manual reshaping.

- `STANDARD` is the visible reference body.
- `LEAN` contains the second fitted body and is hidden by default.
- Each hair, eyebrow, outfit, shoe, and extra is isolated in its own collection.
  Expand the collection and click the closed eye beside the mesh object to show it.
- `BASE_BODY` preserves the creator face Shape Keys.
- `FITTING_GUIDES` contains a hidden, non-rendering face surface.
- `STANDARD_Lips` already has a `Lip_Surface_Fit` Shrinkwrap modifier targeting
  that surface, so Edit Mode shape changes remain fitted to the skin.
- `STUDIO_REFERENCE_NOT_FOR_EXPORT` contains only preview helpers.
- The Blender Text Editor contains `README_EDITING_GUIDE`.

Keep the shared origin, scale, facing direction, and modular object separation
when refining the assets. Leave one polished standard character visible when
returning the file. An armature will be added after the proportions and fitting
are approved.
