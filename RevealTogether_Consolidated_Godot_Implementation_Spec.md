# RevealTogether - Consolidated Godot Implementation Spec

## Purpose

This is the condensed handoff/spec for the current RevealTogether repo state. It combines the important implementation truth, phase status, architecture rules, and next-step direction.

## Current implementation snapshot (2026-04-28)

### Already implemented

- Dedicated server, client, and local debug bootstrap flow.
- Protocol/content-hash hello handshake.
- Server-authoritative match/session service.
- Authoritative board generation and reveal loop.
- Board snapshot/join replication.
- Streamed initial board snapshots for large boards.
- Compact streamed board snapshot payloads.
- Board delta replication.
- 3D player controller and orbit camera.
- Replicated player avatars.
- Authored map preset, tile families, tile variants, tile behavior, roles, and spawn layouts.
- Content registry and startup validation.
- Client-side tile visual scene validation.
- Content inspection overlay.
- Outside-the-map spawning through authored layout data.
- Percentage-based outer-edge initial tile unlocks.
- Organic/distorted family region assignment.
- Local chunk-seed search for large-board generation performance.
- Populated chunk state during board generation.
- MultiMesh full-board renderer path for large boards.
- Incremental MultiMesh board delta updates.
- Hybrid capped detail overlay for large boards.
- Progressive client-side board visual build.
- Loading/progress UI for board snapshot receive and visual build.
- Configurable environment/lighting/rendering values.
- Reveal image assets under `assets/reveal_images/`.

### Not implemented yet

- Authoritative inventory/equipment state.
- Tool and Charm slots.
- Authored item definitions.
- Results/map-complete flow.
- Rich progression systems.
- More varied behavior-specific tile gameplay.
- Final visual polish/art direction.

## 1. Current repo structure

Important current areas:

- `autoload/app/`
- `assets/reveal_images/`
- `config/defaults/`
- `core/content/`
- `core/validation/`
- `data/map_presets/`
- `data/roles/`
- `data/tile_behaviors/`
- `data/tile_families/`
- `data/tile_variants/`
- `data/tuning/spawn_layouts/`
- `game/client/camera/`
- `game/runtime/board/`
- `game/runtime/match/`
- `game/runtime/roles/`
- `net/protocol/`
- `net/session/`
- `scenes/bootstrap/`
- `scenes/debug/`
- `scenes/ui/`
- `scenes/world/`

## 2. Current runtime ownership model

### Bootstrap and content

`AppBootstrap`, `RuntimeConfig`, `LogService`, `ContentRegistry`, and `StartupValidator` own startup/config/content loading and validation.

### Multiplayer/session ownership

`MatchSessionService` owns the networking/session boundary, including handshake, join, snapshot streaming, compact snapshot transport, player replication, and board delta replication.

### Match runtime ownership

`MatchState`, `MatchPlayerState`, and `MatchSpawnPlanner` own running match/player/spawn state.

### Board runtime ownership

`BoardState`, `TileRecord`, `ChunkState`, `BoardBuilder`, and `BoardActionService` own authoritative board truth.

### Client presentation ownership

`ClientSandboxWorld`, `BoardGridView3D`, `BoardTileVisual`, `LoadingProgressOverlay`, player/camera scenes, and debug overlays own presentation/observation only.

## 3. Current supported content model

### Supported resource types today

- `MapPresetDef`
- `TileFamilyDef`
- `TileVariantDef`
- `TileBehaviorDef`
- `RoleDef`
- `SpawnLayoutDef`

### Current authored content slice

- `map_preset.sandbox_64`
- `tile_family.overgrowth`
- `tile_family.scrap`
- `tile_variant.overgrowth_patch`
- `tile_variant.scrap_plate`
- `tile_behavior.standard_reveal_clear`
- `role.archaeologist`
- `role.groundkeeper`
- `role.hacker`
- `role.scavenger`
- `spawn_layout.sandbox_outer_perimeter`
- `spawn_layout.sandbox_ring_8`

## 4. Current playable loop

1. Start dedicated server.
2. Connect client.
3. Join match and receive authoritative snapshot.
4. For large boards, receive streamed/compact board snapshot chunks and build visuals progressively.
5. Spawn outside the board through authored spawn layout data.
6. Move around the world with the 3D controller and orbit camera.
7. Approach available edge tiles.
8. Click to request reveal.
9. Let the server validate and apply reveal.
10. Continue clearing inward on the shared board.

## 5. Current implementation-phase truth

### Phase 0 - Project skeleton

Complete.

### Phase 1 - Dedicated server loop

Complete.

### Phase 2 - Board and reveal core

Complete.

### Phase 3 - 3D player controller and camera

Complete.

### Phase 4 - Data-driven content framework

Complete in practice.

### Phase 4b - Quality/stability/large-board support

In progress, with the major large-board foundation implemented.

Implemented Phase 4b work includes:

- config cleanup/use for tile HP and view settings,
- reveal asset relocation,
- stronger visual content validation,
- chunk state population,
- faster board generation through local chunk seed search,
- large-board MultiMesh rendering,
- incremental tile delta updates,
- streamed snapshots,
- compact streamed snapshots,
- progressive visual build,
- loading/progress UI,
- capped detailed visual overlay.

Remaining Phase 4b work should focus on large-board visual richness/readability and final tuning.

### Phase 5 - Tool/charm/inventory scaffolding

Not started. This is the next gameplay phase after Phase 4b is wrapped or intentionally paused.

### Phase 6 - Results/map-complete flow

Not started.

### Phase 7 - Hardening and internal-test preparation

Not started as a formal phase.

## 6. Recommended next milestone

Finish the remaining Phase 4b large-board presentation work, then commit/push. After that, start Phase 5 with the smallest useful authoritative item/equipment backbone:

- item defs,
- inventory runtime state,
- Tool slot,
- Charm slot,
- server-authoritative replication path.

## 7. Locked architecture rules

### Server authority remains non-negotiable

Gameplay truth stays server-owned.

### Presentation must not become gameplay truth

Tile scenes, MultiMeshes, board visuals, loading UI, and debug overlays must not own board logic.

### Content should be added through defs/resources

Continue extending through authored resources, registry loading, validation, and runtime services.

### Large-board support should preserve full-board visibility

Do not solve performance by hiding most of the board unless the design direction changes. Prefer streaming, batching, MultiMeshes, LOD/detail layers, and better materials.

### Placeholder visuals are replaceable, not structural

The current prototype visuals are fine for iteration and can be swapped later.

### Debug/loading systems should observe truth, not own it

Debug and loading UI should display state/progress only.

## 8. Known deliberate gaps

- no item/inventory implementation yet,
- no results/completion layer yet,
- only one baseline tile behavior asset exists today,
- role content is still light by design,
- distant large-board visual richness still needs polish,
- final environment/lighting/art direction is not locked.

## 9. Summary

RevealTogether now has a real server-authoritative board loop, 3D world interaction, authored content, and large-board loading/rendering foundation. The clean next step is either to finish Phase 4b visual/readability polish or to move into Phase 5 item/tool/charm scaffolding once the current large-board work is committed.
