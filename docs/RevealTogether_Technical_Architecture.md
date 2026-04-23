# RevealTogether - Technical Architecture

## Purpose

This document describes the technical architecture that is **actually present in the current repo**, while also preserving the architectural rules that future work should follow.

It should be read as the source of truth for current runtime boundaries, ownership, and extension points.

---

## Current implementation snapshot (2026-04-23)

The project currently has four major layers online:

1. **bootstrap/runtime foundations**
2. **authoritative multiplayer session flow**
3. **authoritative board/reveal gameplay runtime**
4. **client-side 3D presentation and interaction**

### Implemented today
- runtime mode bootstrap through `AppBootstrap`
- config loading through `RuntimeConfig`
- logging through `LogService`
- content loading through `ContentRegistry`
- startup validation through `StartupValidator`
- authoritative session flow through `MatchSessionService`
- board runtime through `BoardState`, `TileRecord`, `ChunkState`, `BoardBuilder`, and `BoardActionService`
- match/player runtime through `MatchState`, `MatchPlayerState`, and `MatchSpawnPlanner`
- DTO construction through `ConnectionDtos`
- client world orchestration through `ClientSandboxWorld`
- board rendering through `BoardGridView3D`
- orbit camera follow through `PlayerOrbitCameraRigController`
- tile variant visual selection through `TileVariantDef.visual_scene`

### Not implemented yet
- authored role runtime/content
- authored tile behavior definitions beyond the current structural field/link level
- inventory, Tool, Charm, or drop runtime
- results pipeline and match-complete presentation layer
- dedicated content inspection/debug UI beyond logs and validation errors

---

## 1. Architecture principles

These rules still apply and should continue guiding new work.

## 1.1 Server owns gameplay truth
The client may request actions, but the server owns:
- session membership
- player snapshot truth
- board state truth
- reveal progress
- claim ownership and expiry
- clear/unlock propagation
- final-rush state

## 1.2 Data and presentation stay separate
Gameplay truth should live in runtime state objects and authored defs/resources.
Visual scenes should render runtime truth, not replace it.

## 1.3 Content must be authored and validated
Content IDs and cross-links should load through the registry and fail startup early when broken.

## 1.4 Future systems should plug into extension points
New roles, items, tile families, or behaviors should extend the existing structure instead of becoming hardcoded branches in central gameplay scripts.

---

## 2. Actual project structure in the repo

```text
autoload/
  app/
    AppBootstrap.gd
    ContentRegistry.gd
    LogService.gd
    RuntimeConfig.gd

config/
  defaults/
    app.cfg
    client.cfg
    local_debug.cfg
    server.cfg

core/
  content/
    GameContentDef.gd
  validation/
    StartupValidator.gd

data/
  map_presets/
    MapPresetDef.gd
    map_preset_sandbox_64.tres
  tile_families/
    TileFamilyDef.gd
    tile_family_overgrowth.tres
    tile_family_scrap.tres
  tile_variants/
    TileVariantDef.gd
    tile_variant_overgrowth_patch.tres
    tile_variant_scrap_plate.tres
  roles/
  tile_behaviors/
  items/
    tools/
    charms/
  tuning/

game/
  client/
    camera/
      PlayerOrbitCameraRigController.gd
  runtime/
    board/
      BoardActionService.gd
      BoardBuilder.gd
      BoardState.gd
      BoardTileContentCatalog.gd
      ChunkState.gd
      TileRecord.gd
    match/
      MatchPlayerState.gd
      MatchSpawnPlanner.gd
      MatchState.gd

net/
  protocol/
    ConnectionDtos.gd
  session/
    MatchSessionService.gd

scenes/
  bootstrap/
    ClientBootstrap.tscn
    DedicatedServerBootstrap.tscn
    LocalDebugBootstrap.tscn
    bootstrap scripts
  world/
    ClientSandboxWorld.tscn
    ClientSandboxWorld.gd
    board/
      BoardGridView3D.tscn
      BoardGridView3D.gd
      BoardTileVisual.gd
      tile_visuals/
        OvergrowthPatchTileVisual.tscn
        OvergrowthPatchTileVisual.gd
        ScrapPlateTileVisual.tscn
    replicas/
      PlayerReplicaAvatar.tscn
      PlayerReplicaAvatar.gd
```

---

## 3. Bootstrap and runtime ownership

## 3.1 `AppBootstrap`
`AppBootstrap` is the startup gatekeeper.
It loads runtime config, loads content, runs startup validation, determines runtime mode, and opens the correct bootstrap scene.

## 3.2 `RuntimeConfig`
`RuntimeConfig` is the config access layer for merged defaults/runtime values.
Gameplay and presentation scripts read runtime tuning from here rather than baking constants directly into multiple places.

## 3.3 `ContentRegistry`
`ContentRegistry` scans configured content directories, instantiates supported resource types, validates IDs, and provides lookup access to loaded content.

## 3.4 `StartupValidator`
`StartupValidator` performs startup-time validation of the currently supported data domains.
At the moment this includes:
- map preset validation
- tile family validation
- tile variant validation
- cross-reference checks between families and variants

---

## 4. Current authoritative multiplayer/session model

## 4.1 `MatchSessionService`
`MatchSessionService` is the current session/network orchestrator.
It owns:
- ENet server/client startup
- hello handshake
- join-match flow
- player spawn/despawn replication
- authoritative player transform requests on the server
- authoritative reveal requests on the server
- periodic transform replication
- periodic reveal processing and board delta replication

## 4.2 Join/bootstrap replication flow
The current session flow is:
1. client connects
2. client receives hello ack/reject
3. client requests join
4. server creates/uses authoritative `MatchState`
5. server sends match snapshot including player snapshots and a full board snapshot
6. client world instantiates board view and player replicas from that snapshot

## 4.3 Ongoing replication model
After join:
- player transforms are replicated on an interval
- reveal actions are processed on a server tick interval
- board changes are sent as changed-tile delta payloads instead of full board snapshots each tick

---

## 5. Current match/runtime state model

## 5.1 `MatchState`
`MatchState` owns the per-match authoritative runtime bundle.
It includes:
- match identity
- map preset identity
- `BoardState`
- player snapshot storage
- spawn slot bookkeeping
- match-completion/final-rush related summary state

## 5.2 `MatchPlayerState`
`MatchPlayerState` owns per-player authoritative match data such as:
- peer identity
- display name
- world position
- yaw
- active reveal target tile index
- spawn slot index

## 5.3 `MatchSpawnPlanner`
`MatchSpawnPlanner` calculates spawn positions around the board using runtime-configured ring settings.
Spawn logic is not baked into visual scenes.

---

## 6. Current board runtime model

## 6.1 `BoardState`
`BoardState` is the authoritative board container.
It owns:
- board dimensions
- chunk dimensions/counts
- map preset identity
- reveal image path/id summary data
- `TileRecord` storage
- chunk storage
- remaining/cleared/unlocked counters
- final-rush and completion summary state

It exposes snapshot/summary DTO builders that are used by the network layer.

## 6.2 `TileRecord`
The current `TileRecord` fields are:
- `tile_index`
- `tile_id`
- `grid_x`
- `grid_y`
- `chunk_index`
- `family_id`
- `variant_id`
- `behavior_id`
- `state_flags`
- `max_hp`
- `current_hp`
- `is_unlocked`
- `is_cleared`
- `claim_owner_peer_id`
- `claim_expires_at_ms`
- `last_damage_at_ms`
- `rare_signal_state`
- `uv_rect`
- `runtime_tags`

This is the current authoritative tile truth.

## 6.3 `ChunkState`
`ChunkState` groups tile indices by chunk and stores chunk coordinate/size metadata.
Chunking is part of the board runtime model even though current rendering is still lightweight.

## 6.4 `BoardBuilder`
`BoardBuilder` constructs the authoritative board from a `MapPresetDef`.
Its current responsibilities include:
- board dimensions and chunk layout
- reveal texture UV mapping
- unlock seed placement
- procedural family/variant assignment for the currently authored content slice
- tile/chunk population
- initial summary counter setup

## 6.5 `BoardActionService`
`BoardActionService` applies authoritative reveal/clear gameplay rules.
Its current responsibilities include:
- reveal damage ticks
- claim acquisition/refresh
- claim expiry
- tile clear handling
- adjacent unlock propagation
- final-rush transition
- board completion detection
- changed-tile collection for replication

---

## 7. Current content model

## 7.1 Supported authored resource types
The repo currently supports these authored content types:
- `MapPresetDef`
- `TileFamilyDef`
- `TileVariantDef`

## 7.2 Current authored content slice
The currently authored content slice is:
- map preset: `map_preset.sandbox_64`
- families: `tile_family.overgrowth`, `tile_family.scrap`
- variants: `tile_variant.overgrowth_patch`, `tile_variant.scrap_plate`

## 7.3 Current family/variant responsibilities
`TileFamilyDef` currently carries family-level metadata such as:
- ID
- display name
- family color
- spawn weight
- fallback/default behavior link fields

`TileVariantDef` currently carries variant-level metadata such as:
- ID
- family ID
- display name
- spawn weight override / weighting support
- behavior override link
- visual scene reference

## 7.4 Current lookup helper
`BoardTileContentCatalog` builds board-facing cached lookups from `ContentRegistry`, especially variant lookup by ID for the board view.

---

## 8. Current client world/presentation model

## 8.1 `ClientSandboxWorld`
`ClientSandboxWorld` is the client-side orchestrator for the playable 3D scene.
It currently owns:
- world environment configuration
- ground setup
- board view instantiation
- player avatar scene loading/instantiation
- match signal wiring
- local click-to-tile request flow
- local movement request flow
- camera follow updates

## 8.2 Current interaction path
The current tile interaction path is:
1. mouse input intersects the board plane
2. `BoardGridView3D.get_tile_index_from_world_position()` converts world position to tile index
3. the client sends `request_reveal_tile(tile_index)` to `MatchSessionService`
4. the server validates and processes reveal state
5. changed tiles replicate back down

This means click targeting depends on logical board coordinates, not on per-scene collision for each visual tile.

## 8.3 `BoardGridView3D`
`BoardGridView3D` currently renders the board through a hybrid approach:
- generated board base mesh
- generated reveal underlay plane
- generated chunk line meshes
- scene-instanced tile visuals chosen by tile variant ID

Important repo truth:
- the `LockedTiles`, `UnlockedTiles`, and `ClearedTiles` `MultiMeshInstance3D` nodes still exist in the scene, but the current active tile presentation path is the scene-based tile visual path under `TileVisuals`
- gameplay truth does **not** live in those visuals
- tile world size is derived from runtime config (`board_view.tile_size`)

## 8.4 `BoardTileVisual`
`BoardTileVisual` is the shared visual base class used by tile visual scenes.
It applies tile snapshot state to content root visibility plus locked/claimed overlays.

## 8.5 Current placeholder asset strategy
The current tile variant visuals are still placeholder scenes, but they already prove the intended swap path:
- each tile variant can point to its own scene
- scene visuals are selected through authored data
- visual replacement should happen by changing defs/scenes, not by rewriting board truth

---

## 9. Current camera/player presentation model

## 9.1 `PlayerOrbitCameraRigController`
The camera rig controller owns the current orbit/follow camera behavior.
Key runtime-configured concerns include:
- follow smoothing
- yaw rotation
- pitch limits
- zoom distance limits
- near/far clip setup
- look-at height

## 9.2 `PlayerReplicaAvatar`
Remote and local visible player bodies are rendered through `PlayerReplicaAvatar` scenes that are updated from authoritative player snapshots.

---

## 10. Current known gaps and next architectural work

## 10.1 Still-missing content framework slices
The current architecture still needs:
- role resource types
- behavior resource types or stronger validated behavior links
- broader tuning resources
- content inspection/debug tools

## 10.2 Still-missing match experience slices
The current architecture still needs:
- map-complete presentation
- results/contribution packaging
- item/inventory runtime
- reward/drop scaffolding

## 10.3 Readability polish remains presentation work
Readable targeting/highlight polish and richer environment dressing are still future work, but they should remain presentation layers on top of the current authoritative runtime model.

---

## 11. Architecture rules for future changes

## 11.1 Do not move board truth into tile scenes
Tile scenes are presentation.
`BoardState` and `TileRecord` remain the truth.

## 11.2 Do not hardcode future content directly into gameplay scripts
New families, variants, roles, behaviors, tools, and charms should extend authored defs/resources and registry validation.

## 11.3 Keep networking DTOs explicit
Snapshot and delta payload contracts should stay explicit and versionable rather than passing arbitrary ad-hoc dictionaries between unrelated scripts.

## 11.4 Keep runtime truth separate from debug helpers
Logs, overlays, and content inspection tools are useful, but they should observe runtime truth rather than becoming hidden dependencies for gameplay logic.
