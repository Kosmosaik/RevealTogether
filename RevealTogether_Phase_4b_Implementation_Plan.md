# RevealTogether — Phase 4b Implementation Plan

**Branch:** `phase-4b-qol`  
**Purpose:** Stabilize, clean up, and improve the current Phase 4 foundation before continuing into Phase 5.  
**Source of truth:** Latest audited project zip only. Older zips and memory are not trusted for implementation decisions.

---

## 1. Phase 4b Goals

Phase 4b is a quality, stability, maintainability, and presentation pass. It should not introduce major new gameplay systems unless they directly support stability, clarity, or visual polish.

The main goals are:

1. Improve project stability before Phase 5.
2. Remove or fix config drift where config values exist but are not used.
3. Improve visual presentation, especially lighting, shadows, sky/background, and overly dark tile states.
4. Add stronger validation around authored visual content.
5. Clean up file organization where it is safe and useful.
6. Update documentation so it reflects the actual current project state.
7. Keep the project data-driven, modular, and future-proof.

---

## 2. Non-Goals

Phase 4b should avoid:

- Adding major Phase 5 gameplay features.
- Adding crafting, monetization, or other deferred systems.
- Reworking the whole architecture without a direct stability benefit.
- Moving all scripts into one giant `/scripts` folder just for tidiness.
- Hardcoding gameplay tuning or visual values that should live in config/resources.
- Building temporary placeholder systems that will need immediate refactoring later.
- Prioritizing save migration or backward compatibility during this hardening phase.

---

## 3. Implementation Rules

All Phase 4b work should follow these rules:

1. Use only the current project files as source of truth.
2. Do not infer missing names, methods, properties, signals, paths, dictionary keys, or resource fields.
3. Before touching a script, check its dependent scripts and scenes.
4. Prefer explicit config/resource-driven values over hardcoded tuning.
5. Keep runtime truth separate from presentation/debug UI.
6. Prefer reusable helpers for repeated calculations.
7. Avoid shortcuts that conflict with the existing docs or architecture.
8. Keep changes small enough to test and commit cleanly.
9. After each completed step, run the relevant validation/test checklist.

---

## 4. Recommended Work Order

Phase 4b should be completed in this order:

1. Documentation and repo baseline cleanup.
2. Config correctness fixes.
3. Visual and lighting improvement pass.
4. Startup/content validation hardening.
5. Asset and file-structure cleanup.
6. Optional geometry/helper refactor.
7. Final docs update and wrap-up commit.

---

# Phase 4b.1 — Baseline Cleanup

## Objective

Make sure the branch starts from a clean, understandable, and reproducible state.

## Tasks

### 4b.1.1 Confirm branch and git state

Confirm the active branch is:

```text
phase-4b-qol
```

Check whether there are existing uncommitted documentation changes.

Expected currently modified files from audit:

```text
RevealTogether_Consolidated_Godot_Implementation_Spec.md
docs/RevealTogether_Design.md
docs/RevealTogether_Implementation_Plan.md
docs/RevealTogether_Technical_Architecture.md
```

Decide whether to keep, update, or revert those changes before starting code work.

### 4b.1.2 Normalize line endings

Several `.tres`, `.tscn`, and `.md` files may have CRLF working-tree line endings even though `.gitattributes` expects LF.

This matters because `ContentRegistry._build_manifest_hash_from_resource_paths()` hashes raw file bytes. Different line endings across client/server machines could theoretically cause content hash mismatch.

Normalize tracked project files to LF, especially:

- `.gd`
- `.tscn`
- `.tres`
- `.cfg`
- `.md`

Then verify with git EOL status.

### 4b.1.3 Update stale documentation claims

The docs currently mention old `MapPresetDef` placeholder ID fields that no longer exist.

Actual current `MapPresetDef.gd` fields from audit:

```text
board_width
board_height
chunk_width
chunk_height
start_unlock_outer_edge_ratio
start_unlock_outer_edge_depth
start_unlock_outer_edge_randomness
final_rush_remaining_tiles_threshold
reveal_image
reveal_mapping_mode
family_region_warp_frequency
family_region_warp_strength
rare_tile_chance
spawn_layout_id
```

Docs should be updated to reflect that the old placeholder fields were already removed.

## Acceptance Criteria

- Branch is confirmed.
- Git state is understood before code changes.
- Line endings are normalized.
- Docs no longer describe removed `MapPresetDef` fields as current work.

---

# Phase 4b.2 — Config Correctness and Data-Driven Cleanup

## Objective

Fix cases where config values exist but are ignored or where hardcoded values should come from config/resources.

## Tasks

### 4b.2.1 Make default tile HP configurable

Current issue:

`config/defaults/app.cfg` contains:

```ini
[board_actions]
default_tile_hp = 1
```

But `BoardBuilder.gd` currently hardcodes default tile HP as `1` inside:

```text
build_board_state_from_map_preset(map_preset_def: MapPresetDef)
```

Change `BoardBuilder.gd` so it reads the value from config instead of hardcoding it.

Likely dependency to check before implementation:

- `AppConfig.gd`
- `BoardBuilder.gd`
- `BoardState.gd`
- `TileState.gd`
- any scripts that consume tile HP snapshots

Acceptance criteria:

- Changing `board_actions.default_tile_hp` in config affects newly built board tile HP.
- Runtime snapshots still contain expected HP fields.
- Existing tile reveal/damage flow still works.

---

### 4b.2.2 Wire unused visual config values

Current issue:

These config values exist but are not fully used:

```ini
[client_world]
ground_color = ...

[board_view]
base_color = ...
hidden_tile_color = ...
revealed_tile_color = ...
claimed_tile_color = ...
chunk_line_color = ...
```

Relevant scripts from audit:

```text
ClientSandboxWorld.gd
BoardGridView3D.gd
```

Relevant existing functions:

```text
ClientSandboxWorld._configure_ground()
ClientSandboxWorld._configure_environment()
BoardGridView3D._rebuild_board_base()
BoardGridView3D._rebuild_chunk_lines()
BoardGridView3D._build_material(albedo_color: Color)
```

Implementation direction:

- Add or use a safe config color-read helper.
- Read colors from config instead of hardcoding them.
- Keep default fallbacks so missing config does not crash the project.
- Avoid spreading color parsing logic across many scripts.

Acceptance criteria:

- Ground color changes when `client_world.ground_color` changes.
- Board base color changes when `board_view.base_color` changes.
- Chunk line color changes when `board_view.chunk_line_color` changes.
- No crashes if a color config value is missing or malformed.

---

### 4b.2.3 Decide what to do with currently unused `MapPresetDef` fields

Current questionable fields:

```text
reveal_mapping_mode
rare_tile_chance
```

Options:

1. Remove them if they are not needed soon.
2. Keep them but document them as reserved/future fields.
3. Implement them properly if they are required for upcoming planned work.

Recommendation:

For Phase 4b, prefer either removing them or explicitly documenting them as future fields. Do not leave them looking active if they do nothing.

Acceptance criteria:

- Docs and implementation agree.
- No active-looking config/resource field silently does nothing unless explicitly documented as reserved.

---

# Phase 4b.3 — Visual and Lighting Improvement Pass

## Objective

Improve the current look of the project, especially the high-contrast shadows, overly dark locked tile areas, and lack of pleasant sky/background color.

## Current Problems Found

### Environment

`ClientSandboxWorld._configure_environment()` currently hardcodes a very dark background:

```gdscript
Color(0.07, 0.09, 0.11, 1.0)
```

Ambient color is also hardcoded:

```gdscript
Color(0.82, 0.85, 0.90, 1.0)
```

Only some lighting values are configurable:

- `ambient_light_energy`
- `sun_light_energy`
- sun rotation

### Shadows

The sun light currently has shadows enabled directly:

```gdscript
_sun_light.shadow_enabled = true
```

There is no obvious config toggle for shadow intensity, softness, or disabling shadows for testing.

### Tile locked overlays

Current locked overlay colors are very dark:

`OvergrowthPatchTileVisual.tscn`:

```text
Color(0.07, 0.09, 0.07, 1)
```

`ScrapPlateTileVisual.tscn`:

```text
Color(0.08, 0.10, 0.12, 1)
```

These likely contribute to overly dark locked regions.

## Tasks

### 4b.3.1 Add configurable world/environment colors

Add config values for:

```ini
[client_world]
background_color = ...
ambient_light_color = ...
```

Optional later values:

```ini
sky_top_color = ...
sky_horizon_color = ...
```

Implementation direction:

- First pass can use a simple background color.
- If Godot environment setup supports it cleanly, add procedural/sky setup later.
- Keep sky/background settings centralized in `ClientSandboxWorld._configure_environment()`.

Acceptance criteria:

- Background is no longer hardcoded to a near-black color.
- Background/sky color can be tuned from config.
- Ambient color can be tuned from config.

---

### 4b.3.2 Add shadow configuration

Add config values such as:

```ini
[client_world]
sun_shadow_enabled = true
```

Possible additional values if supported cleanly by the current Godot light type:

```ini
sun_shadow_opacity = ...
sun_shadow_bias = ...
sun_shadow_normal_bias = ...
```

Implementation direction:

- Start with a simple `sun_shadow_enabled` toggle.
- Tune default light/ambient values so shadows are readable but not harsh.
- Avoid visual settings hidden in scene files when they should be tunable.

Acceptance criteria:

- Shadows can be disabled through config for testing.
- Default shadows are softer/less oppressive than before.
- Dark areas are still readable.

---

### 4b.3.3 Improve locked and claimed overlay readability

Current tile overlay visuals are too dark and high contrast.

Implementation direction:

- Lighten locked overlay materials.
- Consider lowering alpha if the visual composition supports transparency cleanly.
- Keep locked/claimed states readable from a top-down camera.
- Avoid making locked, claimed, and cleared states visually ambiguous.

Potential future config direction:

```ini
[board_view]
locked_overlay_color = ...
claimed_overlay_color = ...
```

Acceptance criteria:

- Locked areas are visually clear but not black/dark blotches.
- Claimed tiles remain easy to identify.
- Tile family visual identity is still visible.

---

### 4b.3.4 Improve world palette consistency

The visual style should feel cohesive across:

- ground plane
- board base
- chunk lines
- locked overlays
- claimed overlays
- sun/ambient/background color

Implementation direction:

- Use soft, readable default colors.
- Avoid extreme contrast in the default lighting setup.
- Keep colors configurable where they are likely to be tuned often.

Acceptance criteria:

- The scene feels less harsh and less empty.
- There is some sky/background color instead of a dark void.
- Board readability is improved.

---

# Phase 4b.4 — Startup and Content Validation Hardening

## Objective

Catch broken authored resources and scene references earlier, especially visual-scene problems that currently fail silently or late.

## Tasks

### 4b.4.1 Validate `TileVariantDef.visual_scene`

Current validator checks IDs and weights, but not enough visual scene details.

Add validation that each tile variant:

- has a `visual_scene` assigned.
- can instantiate the scene.
- instantiates a root compatible with `BoardTileVisual`.
- has valid configured node paths for:
  - `content_root_path`
  - `locked_overlay_path`
  - `claimed_overlay_path`

Relevant scripts:

```text
StartupValidator.gd
TileVariantDef.gd
BoardTileVisual.gd
```

Relevant existing `BoardTileVisual.gd` exported fields:

```text
content_root_path
locked_overlay_path
claimed_overlay_path
```

Acceptance criteria:

- Missing visual scenes are reported at startup validation.
- Wrong visual scene types are reported at startup validation.
- Missing required visual nodes are reported at startup validation.
- Valid current tile visual scenes pass validation.

---

### 4b.4.2 Improve error messages for visual content failures

Current `BoardGridView3D` paths can fail quietly when visual scenes are invalid.

Implementation direction:

- Keep startup validation as the main protection.
- Add useful warnings/errors where runtime visual instantiation still fails.
- Include enough context in the error to identify the tile variant/resource.

Acceptance criteria:

- Broken content produces actionable messages.
- The game does not fail silently when a tile visual cannot be created.

---

# Phase 4b.5 — Asset and File Organization Cleanup

## Objective

Clean the project structure where it improves long-term maintainability without causing unnecessary churn.

## Tasks

### 4b.5.1 Move root reveal images into an asset folder

Current root images from audit:

```text
64_64_lighthouse.png
64_64_steve.png
64_64_sunset.png
```

Only this one is currently referenced by the sandbox map preset:

```text
64_64_lighthouse.png
```

Recommended destination:

```text
assets/reveal_images/
```

Implementation direction:

- Move images into `assets/reveal_images/`.
- Update any `.tres` references.
- Decide whether unused images should be kept as test images or removed.

Acceptance criteria:

- No reveal images are loose in the project root.
- `map_preset_sandbox_64.tres` still loads its reveal image.
- No missing resource paths are introduced.

---

### 4b.5.2 Decide script organization policy

Current structure is not random. Scripts are grouped by ownership:

```text
autoload/app/
core/
data/
game/client/
game/runtime/
net/
scenes/
```

Scene-attached scripts currently live beside their scenes, for example:

```text
scenes/world/ClientSandboxWorld.gd
scenes/world/board/BoardGridView3D.gd
scenes/world/board/BoardTileVisual.gd
scenes/world/replicas/PlayerReplicaAvatar.gd
scenes/debug/ContentInspectionOverlay.gd
```

Recommendation:

Do not move all scripts into one giant `/scripts` folder. That would reduce contextual ownership.

Preferred options:

1. Keep scene scripts beside scenes.
2. Or move client presentation scripts into:

```text
game/client/presentation/
```

while keeping `.tscn` files under `scenes/`.

For Phase 4b, prefer documenting the policy instead of doing a large move immediately.

Acceptance criteria:

- Project structure rules are documented.
- No unnecessary path churn is introduced.
- Any script move, if performed, updates all scene script references safely.

---

### 4b.5.3 Normalize inconsistent content ID naming

Current inconsistent ID from audit:

```text
tile_variant_scrap_plate
```

Most other IDs use dot-style, for example:

```text
tile_variant.overgrowth_patch
tile_family.scrap
spawn_layout.sandbox_outer_perimeter
```

Recommended rename:

```text
tile_variant.scrap_plate
```

Because saves are disposable during this hardening phase, this is a good time to normalize IDs.

Acceptance criteria:

- ID style is consistent.
- All references are updated.
- Startup validation passes.
- Content manifest remains deterministic.

---

# Phase 4b.6 — Optional Board Geometry Helper

## Objective

Reduce duplicated board-size and tile-spacing calculations.

## Current Issue

Board/tile geometry calculations are duplicated across:

```text
BoardGridView3D.gd
MatchSpawnPlanner.gd
MatchSessionService._get_match_ground_half_extents()
```

These scripts independently read or calculate tile size, tile gap, stride, and board extents.

## Recommendation

Create one shared helper for board geometry calculations.

Possible location:

```text
core/board/BoardGeometry.gd
```

or another existing shared/core location that matches the current structure.

Potential responsibilities:

- read tile size and gap from config.
- calculate tile stride.
- calculate board world size.
- convert board coordinates to local/world positions.
- calculate board half extents.

## Acceptance Criteria

- Existing board visuals still line up correctly.
- Spawn positions still align with the board/world extents.
- Ground extents still cover the playable area.
- Duplicate geometry calculations are reduced.

## Priority

This is useful but optional. It should happen after the simpler Phase 4b stability and visual fixes unless duplication starts blocking other work.

---

# Phase 4b.7 — Documentation Update

## Objective

Make sure the docs describe the actual project after Phase 4b changes.

## Docs to Update

```text
RevealTogether_Consolidated_Godot_Implementation_Spec.md
docs/RevealTogether_Design.md
docs/RevealTogether_Implementation_Plan.md
docs/RevealTogether_Technical_Architecture.md
```

## Required Documentation Changes

Document:

- Phase 4 is complete.
- Phase 4b exists as a hardening/QOL/visual pass before Phase 5.
- Config-driven visual settings.
- Startup validation additions.
- File organization policy.
- Any normalized content IDs.
- Any moved asset folders.
- Any new board geometry helper if implemented.

## Acceptance Criteria

- Docs do not mention stale work as still pending.
- Docs match actual scripts/resources.
- Phase 5 plan starts from the new Phase 4b baseline.

---

# Suggested Commit Breakdown

Use small commits so each change is easy to review and revert.

Suggested commits:

1. `docs: add phase 4b implementation plan`
2. `chore: normalize line endings`
3. `docs: update phase 4 state and map preset notes`
4. `fix: read default tile hp from config`
5. `feat: make board and world colors config driven`
6. `feat: improve world lighting and shadow configuration`
7. `feat: harden tile visual startup validation`
8. `chore: organize reveal image assets`
9. `chore: normalize tile variant ids`
10. `refactor: centralize board geometry calculations` if completed
11. `docs: wrap up phase 4b changes`

---

# Phase 4b Completion Checklist

Phase 4b can be considered complete when:

- [ ] Git branch is clean and all work is committed.
- [ ] Line endings are normalized.
- [ ] Config values in `app.cfg` are either used or documented as reserved.
- [ ] `board_actions.default_tile_hp` affects runtime board construction.
- [ ] World/background/ambient/ground colors are configurable.
- [ ] Shadows are less harsh and can be configured at least with an enabled/disabled setting.
- [ ] Locked tile overlays are no longer overly dark.
- [ ] Tile visual scenes are validated at startup.
- [ ] Broken visual content gives actionable error messages.
- [ ] Root reveal images are moved or intentionally documented.
- [ ] Content ID naming is consistent or intentionally documented.
- [ ] Docs match the actual project state.
- [ ] Manual playtest confirms the board loads, tiles display correctly, claiming/damaging still works, and visuals are improved.

---

# Manual Test Checklist

After each meaningful code step, test:

1. Project launches without startup validation errors.
2. Sandbox world loads.
3. Board appears with expected dimensions.
4. Tile visuals instantiate correctly.
5. Locked/unlocked/claimed/cleared states remain readable.
6. Player movement still works.
7. Camera movement, rotation, pitch, and zoom still work.
8. Tile interaction/damage/reveal flow still works.
9. Multiplayer/session startup still reaches the same state as before.
10. Content hash validation does not fail unexpectedly.

---

# Recommended First Implementation Step

Start with this small sequence:

1. Normalize docs to match current `MapPresetDef` state.
2. Fix `BoardBuilder.gd` so `default_tile_hp` is config-driven.
3. Wire `client_world.ground_color`, `board_view.base_color`, and `board_view.chunk_line_color`.
4. Add `client_world.background_color`, `ambient_light_color`, and `sun_shadow_enabled`.
5. Tune default visual values.

This gives quick wins without risky architecture changes.

