# RevealTogether - Consolidated Godot Implementation Spec

## Purpose

This document is the condensed technical/design handoff for the current repo state. It combines the most important implementation truths, phase status, and extension rules into one place.

## Current implementation snapshot (2026-04-24)

### Already implemented

- dedicated server runtime and client bootstrap flow
- authoritative board generation and reveal loop
- board snapshot/join replication
- 3D player controller and orbit camera
- replicated player avatars
- authored map presets
- authored tile families and tile variants
- authored roles
- authored spawn layouts
- authored tile behaviors
- content registry and startup validation
- content inspection overlay
- outside-the-map spawning through authored layout data
- percentage-based outer-edge initial tile unlocks
- organic/distorted family region assignment for the current board

### Not implemented yet

- authoritative inventory/equipment state
- authored item definitions
- results/map-complete flow
- richer progression systems
- more varied behavior-specific tile gameplay

## 1. Current repo structure

Important current areas:

- `autoload/app/`
- `core/validation/`
- `data/map_presets/`
- `data/roles/`
- `data/tile_behaviors/`
- `data/tile_families/`
- `data/tile_variants/`
- `data/tuning/spawn_layouts/`
- `game/runtime/board/`
- `game/runtime/match/`
- `game/runtime/roles/`
- `net/session/`
- `scenes/debug/`
- `scenes/world/`

## 2. Current runtime ownership model

## 2.1 Bootstrap and content

`AppBootstrap`, `RuntimeConfig`, `ContentRegistry`, and `StartupValidator` own the startup/content-validation path.

## 2.2 Multiplayer/session ownership

`MatchSessionService` owns the session/match networking boundary.

## 2.3 Match runtime ownership

`MatchState`, `MatchPlayerState`, and `MatchSpawnPlanner` own running-match state and spawn planning.

## 2.4 Board runtime ownership

`BoardState`, `TileRecord`, `ChunkState`, `BoardBuilder`, and `BoardActionService` own board truth.

## 2.5 Client presentation ownership

`ClientSandboxWorld`, `BoardGridView3D`, `BoardTileVisual`, player/camera scenes, and the content overlay own presentation/debug observation only.

## 3. Current supported content model

## 3.1 Supported resource types today

- `MapPresetDef`
- `TileFamilyDef`
- `TileVariantDef`
- `RoleDef`
- `SpawnLayoutDef`
- `TileBehaviorDef`

## 3.2 Current authored content slice

- 1 map preset
- 2 tile families
- 2 tile variants
- 4 roles
- 2 spawn layouts
- 1 tile behavior

## 3.3 Current visual-content link

Map presets drive board/image/tuning. Tile variants point to visual scenes and behavior ids. Runtime state carries those ids. Scene visuals remain presentation and can be replaced later.

## 4. Current playable loop

1. Start dedicated server.
2. Connect client.
3. Join match and receive authoritative snapshot.
4. Spawn outside the board through authored spawn layout data.
5. Move around the world with the 3D controller and orbit camera.
6. Approach available edge tiles.
7. Click to request reveal.
8. Let the server validate and apply reveal.
9. Continue clearing inward on the shared board.

## 5. Current implementation-phase truth

## Phase 0 - Project skeleton

Complete.

## Phase 1 - Dedicated server loop

Complete.

## Phase 2 - Board and reveal core

Complete.

## Phase 3 - 3D player controller and camera

Complete.

## Phase 4 - Data-driven content framework

Functionally complete in practice.

What exists now:

- authored content defs/resources for the current prototype slice
- registry loading
- startup validation
- tile-family/variant/behavior links
- authored role assignment
- authored spawn layout selection
- content inspection/debug visibility

Small remaining cleanup:

- remove or implement the unused placeholder ids still present on `MapPresetDef.gd`

## Phase 5 - Tool/charm/inventory scaffolding

Not started. This is the clean next phase.

## Phase 6 - Results/map-complete flow

Not started.

## Phase 7 - Hardening and internal-test preparation

Not started.

## 6. Recommended next milestone

Start Phase 5 with the smallest useful authoritative item/equipment backbone:

- inventory runtime state
- Tool slot
- Charm slot
- first authored item defs needed to support those systems
- clean server-authoritative replication path for those additions

## 7. Locked architecture rules

## 7.1 Server authority remains non-negotiable

Gameplay truth stays server-owned.

## 7.2 Presentation must not become gameplay truth

Tile scenes, board visuals, and debug overlays must not own board logic.

## 7.3 Content should be added through defs/resources

Continue extending through authored resources, registry loading, validation, and runtime services.

## 7.4 Placeholder visuals are replaceable, not structural

The current scene-based placeholder visuals are fine for prototype iteration and can be swapped later.

## 7.5 Debug systems should observe truth, not own it

The content inspection overlay is for visibility only.

## 8. Known deliberate gaps

- no item/inventory implementation yet
- no results/completion layer yet
- only one baseline tile behavior asset exists today
- role content is still light by design
- `MapPresetDef.gd` still exposes a few future-facing placeholder ids that are not active content domains yet

## 9. Summary

The project is now beyond foundation work. The server-authoritative board loop, 3D world interaction, and authored content framework are already real. The clean next step is no longer more framework invention; it is Phase 5 gameplay-extension scaffolding.
