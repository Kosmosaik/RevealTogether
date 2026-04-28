# RevealTogether - Technical Architecture

## Purpose

This document describes the current architecture in the repo after Phase 4 and the Phase 4b large-board performance work.

## Current implementation snapshot (2026-04-28)

### Implemented today

- Godot 4.6 project using Forward Plus and Jolt Physics.
- Dedicated server, client, and local debug bootstrap scenes.
- Runtime config loading through `RuntimeConfig`.
- Logging through `LogService`.
- Content loading through `ContentRegistry`.
- Startup validation through `StartupValidator`.
- Server-authoritative match/session flow through `MatchSessionService`.
- Authoritative board generation, board state, chunk state, tile records, and reveal actions.
- Chunk state population during board generation.
- Local chunk-seed search for faster large-board family assignment.
- Authored map presets, roles, spawn layouts, tile families, tile variants, and tile behaviors.
- Server-owned player spawn, player state, and transform replication.
- 3D client world with player replicas, orbit camera, configurable environment/lighting, and ground.
- Board presentation through `BoardGridView3D`.
- Large-board MultiMesh tile-cover rendering.
- Incremental MultiMesh tile updates for board deltas.
- Streamed join snapshots for large boards.
- Compact streamed board snapshot payloads.
- Progressive client-side MultiMesh visual build.
- Loading/progress UI for snapshot receive and visual build stages.
- Hybrid large-board detail overlay using capped authored `BoardTileVisual` scene instances.
- Reveal image assets organized under `assets/reveal_images/`.

### Not implemented yet

- Authoritative item/inventory state.
- Tool and Charm equipment slots.
- Authored item definitions.
- Map-complete/results flow.
- Long-term progression.
- Rich behavior-specific tile gameplay beyond the baseline reveal/clear behavior.
- Final visual art direction.

## 1. Architecture principles

### 1.1 Server owns gameplay truth

The server owns authoritative match state, board state, player state, reveal validation, tile damage, tile clearing, and replication. Clients request actions and present replicated state.

### 1.2 Runtime truth and presentation stay separate

Runtime truth belongs in board/match/session classes. Visual scenes, MultiMeshes, overlays, debug UI, and loading UI must not become gameplay authorities.

### 1.3 Content is authored and validated

Content should be added through resources/defs, registered by `ContentRegistry`, and checked by `StartupValidator` where possible.

### 1.4 Large-board support uses batching, streaming, and layering

The project should keep whole-board visibility while using chunking, streaming, MultiMeshes, progressive visual build, and capped detail layers to control cost.

## 2. Current project structure

Important folders:

- `autoload/app/` - global runtime services.
- `assets/reveal_images/` - reveal image textures used by map presets.
- `config/defaults/` - default app/client/server/local-debug config files.
- `core/content/` - shared content base types.
- `core/validation/` - startup validation.
- `data/map_presets/` - authored map presets and `MapPresetDef`.
- `data/roles/` - authored roles and `RoleDef`.
- `data/tile_behaviors/` - authored tile behavior defs.
- `data/tile_families/` - authored tile family defs.
- `data/tile_variants/` - authored tile variant defs.
- `data/tuning/spawn_layouts/` - authored spawn layout defs.
- `game/client/camera/` - camera control code.
- `game/runtime/board/` - authoritative board runtime state/services.
- `game/runtime/match/` - authoritative match/player/spawn state.
- `game/runtime/roles/` - role lookup helpers.
- `net/protocol/` - DTO construction and protocol constants.
- `net/session/` - multiplayer/session service.
- `scenes/bootstrap/` - app/client/server/local debug startup scenes/scripts.
- `scenes/debug/` - debug overlays.
- `scenes/ui/` - runtime UI such as loading/progress overlay.
- `scenes/world/` - client world, board visuals, tile visuals, and player replicas.

## 3. Bootstrap and app services

### `AppBootstrap`

Selects and enters the correct bootstrap scene for the configured runtime mode.

### `RuntimeConfig`

Provides config values from default config files. Gameplay and presentation tuning should prefer config/resources over hardcoded script constants.

### `LogService`

Central logging utility used across boot, networking, world, and validation paths.

### `ContentRegistry`

Loads registered content from configured content directories and computes the content manifest hash used in the client/server handshake.

### `StartupValidator`

Validates required runtime assets, config, content links, map preset values, spawn layout values, role presence, tile family/variant/behavior links, and client-side tile visual scenes. Dedicated server mode skips tile visual scene instantiation checks because visual scenes are client presentation assets.

## 4. Networking and session ownership

### `MatchSessionService`

Owns the multiplayer/session boundary. Responsibilities include:

- hello/protocol/content-hash handshake,
- join-match handling,
- player spawn/despawn replication,
- player transform replication,
- board delta replication,
- join snapshot delivery,
- streamed board snapshot receive/reassembly on clients,
- compact streamed snapshot send/expand paths for large boards.

### Join/bootstrap replication flow

For small boards, normal join snapshot delivery can still be used. For boards above the configured threshold, the server sends:

1. a join snapshot header/metadata payload,
2. streamed board snapshot chunks,
3. a completion signal once all chunks arrive and are reassembled.

When compact streaming is enabled, tile data is packed into palette/index/flag arrays and expanded back into normal tile snapshot dictionaries on the client before the normal joined-match flow continues.

### Ongoing replication model

After join, the server sends board deltas and player transform updates. Board deltas are applied incrementally to cached tile snapshots and presentation state.

## 5. Match/runtime state model

### `MatchState`

Owns the running match state: match id, board state, player states, map preset, and match-level values.

### `MatchPlayerState`

Owns per-player authoritative state used by the match/session flow.

### `MatchSpawnPlanner`

Uses authored `SpawnLayoutDef` data to place players outside the board perimeter.

## 6. Board runtime model

### `BoardState`

Owns board dimensions, chunks, tile records, dirty tile tracking, and summary/snapshot data.

### `TileRecord`

Represents authoritative per-tile state such as tile index, grid position, chunk index, variant id, unlock/clear state, HP, claim state, last damage data, and UV rect.

### `ChunkState`

Represents chunk metadata and tile membership. It is now populated during board generation and can support current/future dirty tracking, diagnostics, streaming, and chunk-level organization.

### `BoardBuilder`

Builds the authoritative board from `MapPresetDef`, tile family/variant content, and spawn/unlock settings. It uses local chunk-seed search controlled by `family_region_seed_search_radius_chunks` instead of comparing every tile against every chunk seed.

### `BoardActionService`

Validates and applies board interactions such as reveal/damage/clear behavior. It should remain server-side gameplay logic.

## 7. Content model

### Supported authored resource types

- `MapPresetDef`
- `TileFamilyDef`
- `TileVariantDef`
- `TileBehaviorDef`
- `RoleDef`
- `SpawnLayoutDef`

### Current authored content slice

- 1 map preset
- 2 tile families
- 2 tile variants
- 1 tile behavior
- 4 roles
- 2 spawn layouts

### Current visual-content link

Tile variants point to visual scenes. `BoardGridView3D` may instantiate those scenes directly on small boards or selectively as a large-board detail overlay. Tile visual scenes remain presentation-only.

## 8. Client world and presentation model

### `ClientSandboxWorld`

Owns the local client presentation scene. Responsibilities include:

- connecting to `MatchSessionService` signals,
- instantiating board view and player replicas,
- configuring camera and viewport rendering,
- forwarding click/reveal requests,
- forwarding focus/hover information to the board view,
- showing loading/progress UI for snapshot and visual-build phases.

### `BoardGridView3D`

Owns board presentation. Current responsibilities include:

- board base and reveal underlay,
- chunk lines when enabled,
- small-board detailed tile scene rendering,
- large-board MultiMesh rendering,
- incremental MultiMesh tile updates,
- progressive visual build,
- hybrid large-board detail overlay,
- detail focus/hover/recent-change prioritization,
- board visual build signals for loading UI.

### `LoadingProgressOverlay`

A lightweight client-side UI node created from code when enabled by config. It displays current loading stage, detail text, and progress while receiving board snapshots and building board visuals.

### `BoardTileVisual`

Base class for authored tile visual scenes. Visuals can respond to presentation state but must not own gameplay truth.

## 9. Config areas to know

Important config sections in `config/defaults/app.cfg` include:

- `[board_actions]`
- `[board_view]`
- `[camera_rig]`
- `[client_world]`
- `[loading_progress_ui]`
- `[match]`
- `[movement]`
- `[network]`
- `[rendering_3d]`
- `[replication]`
- `[content_directories]`

Large-board tuning currently lives mainly under `[board_view]` and `[replication]`.

## 10. Current known gaps and next architectural work

### Still-missing gameplay framework slices

- Item defs.
- Inventory runtime state.
- Equipment runtime state.
- Tool slot.
- Charm slot.
- Replication for inventory/equipment.

### Still-missing match experience slices

- Map completion detection as a player-facing flow.
- Results screen or summary.
- Better progression/reward feedback.

### Remaining large-board presentation work

- Richer distant tile/family readability without per-tile scenes everywhere.
- Better art direction for sky, shadows, palette, tile height, overlays, and region identity.
- More explicit profiling/tuning targets for supported board sizes.

## 11. Architecture rules for future changes

### Do not move board truth into tile scenes

Tile scenes and MultiMeshes are presentation layers only.

### Do not hardcode future content directly into gameplay scripts

Add content through defs/resources/config and validate it.

### Keep networking DTOs explicit

Replication changes should go through clear DTO builders/readers and versioned/understandable payload shapes.

### Keep large-board systems layered

Full-board rendering, detail overlays, streaming, and runtime truth should remain separate systems with explicit responsibilities.

### Keep debug and loading UI observational

Debug overlays and loading UI should observe state/progress, not own gameplay state.
