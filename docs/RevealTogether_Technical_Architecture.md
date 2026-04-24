# RevealTogether - Technical Architecture

## Purpose

This document describes the actual current architecture in the repo, with emphasis on runtime ownership, content loading/validation, multiplayer authority, and the practical extension points that should be used next.

## Current implementation snapshot (2026-04-24)

### Implemented today

- dedicated server bootstrap and runtime mode selection
- content registry scanning/loading
- startup validation
- authoritative match/session service
- board generation and reveal flow
- 3D player movement and orbit camera
- replicated player avatars
- authored map preset, role, tile family, tile variant, spawn layout, and tile behavior resources
- debug content inspection overlay
- authored outside-the-map player spawning
- authored edge-based initial unlock rules

### Not implemented yet

- authoritative inventory/equipment state
- authored item resources
- richer per-behavior tile gameplay logic
- results / map-complete flow
- broader progression systems

## 1. Architecture principles

## 1.1 Server owns gameplay truth

The server remains authoritative for:

- match state
- board state
- reveal permission and reveal application
- player runtime state
- spawn planning

Clients observe replicated truth and send requests.

## 1.2 Data and presentation stay separate

The repo already follows the right separation:

- board/tile state lives in runtime data structures
- tile scenes are presentation
- background image is presentation
- debug overlay is observation, not ownership

## 1.3 Content must be authored and validated

Authored content is loaded through `ContentRegistry` and checked through `StartupValidator` before the game is allowed to continue booting.

## 1.4 Future systems should plug into extension points

The correct next moves are to extend the current runtime/content boundaries, not to replace them.

## 2. Actual project structure in the repo

Key areas in the current repo:

- `autoload/app/`
  - bootstrap, runtime config, logging, content registry
- `core/validation/`
  - startup validation
- `data/`
  - authored gameplay-facing content defs/resources
- `game/runtime/board/`
  - board state, tile records, builder, reveal service, content lookup helper
- `game/runtime/match/`
  - match state, player state, spawn planner
- `game/runtime/roles/`
  - role content lookup helper
- `net/session/`
  - session/match multiplayer service
- `scenes/world/`
  - client world, board view, player pawn/camera, visual scenes
- `scenes/debug/`
  - content inspection overlay

## 3. Bootstrap and runtime ownership

## 3.1 `AppBootstrap`

Owns startup sequence and uses content/validation/runtime config before advancing into the correct bootstrap scene.

## 3.2 `RuntimeConfig`

Owns runtime-mode and config-file resolution, including dedicated server vs client bootstrap selection.

## 3.3 `ContentRegistry`

Scans configured content directories, loads resources, registers them by content id, and exposes manifest/warning/state access.

## 3.4 `StartupValidator`

Validates:

- runtime config
- required scene config
- map preset availability
- spawn layout availability
- tile family/variant relationships
- role resources
- tile behavior resources and variant links

## 4. Current authoritative multiplayer/session model

## 4.1 `MatchSessionService`

This service remains the main networked authority boundary. It currently handles:

- host/client session lifecycle
- join snapshot delivery
- board reveal requests
- player runtime synchronization
- role assignment on join
- board snapshot/update RPC flow

## 4.2 Join/bootstrap replication flow

Current high-level flow:

1. client connects
2. client joins match
3. server assembles snapshot
4. client receives snapshot
5. client world builds/applies board and player state

## 4.3 Ongoing replication model

The current repo uses explicit RPC/data transfer rather than implicit scene-authority gameplay. This is the right direction and should be preserved.

## 5. Current match/runtime state model

## 5.1 `MatchState`

Holds board and player state for the running match.

## 5.2 `MatchPlayerState`

Represents a player in runtime state, including position-related data and the authored role id assigned for that player.

## 5.3 `MatchSpawnPlanner`

Resolves player spawn positions from authored spawn layouts. The active sandbox preset currently uses the outer-perimeter layout so players spawn outside the map boundary instead of in an inner ring.

## 6. Current board runtime model

## 6.1 `BoardState`

Owns the authoritative board dimensions, tile collection, chunk collection, and summary helpers.

## 6.2 `TileRecord`

Owns per-tile truth including:

- coordinates
- reveal/locked state
- family id
- variant id
- behavior id

This is important: tile scenes do not own this data.

## 6.3 `ChunkState`

Provides chunk-level structure for board organization and generation support.

## 6.4 `BoardBuilder`

Builds board state from authored map-preset data and authored tile content. It currently handles:

- board size and chunk layout
- region-style family assignment
- variant selection inside families
- behavior id propagation from variants
- initial edge unlock setup
- authored spawn-layout usage through the wider match flow

## 6.5 `BoardActionService`

Applies authoritative reveal logic and board mutations on the server.

## 7. Current content model

## 7.1 Supported authored resource types

Current supported authored resource types in the repo:

- `MapPresetDef`
- `TileFamilyDef`
- `TileVariantDef`
- `RoleDef`
- `SpawnLayoutDef`
- `TileBehaviorDef`

## 7.2 Current authored content slice

Current repo snapshot includes:

- 1 map preset
- 2 tile families
- 2 tile variants
- 4 roles
- 2 spawn layouts
- 1 tile behavior

## 7.3 Current family/variant responsibilities

- Map preset: board size, reveal image, unlock tuning, region tuning, spawn layout id
- Tile family: broad thematic bucket and weighted region assignment
- Tile variant: family membership, behavior link, weighted variant selection, visual scene
- Role: authored player identity list used by runtime role assignment
- Spawn layout: authored spawn-position strategy/tuning
- Tile behavior: authored behavior identity resource for tile behavior links

## 7.4 Current lookup helpers

- `BoardTileContentCatalog` resolves authored tile families, variants, and behaviors
- `RoleContentCatalog` resolves authored roles

## 8. Current client world/presentation model

## 8.1 `ClientSandboxWorld`

Coordinates:

- world bootstrap
- board snapshot application
- player/world integration
- click interaction path

## 8.2 Current interaction path

Current reveal path:

1. client raycasts/selects tile world interaction
2. client sends reveal request
3. server validates/apply reveal
4. replicated board state updates client view

## 8.3 `BoardGridView3D`

Builds the visible board representation. It uses scene-based tile visuals, but those visuals are downstream of runtime tile data and content ids.

## 8.4 `BoardTileVisual`

Holds presentation logic for current placeholder visuals.

## 8.5 Current placeholder asset strategy

Current tile visuals are cube-like placeholder scenes. They are sufficient for prototype playtesting and are not structural architecture.

## 9. Current camera/player presentation model

## 9.1 `PlayerOrbitCameraRigController`

Provides orbit/pitch/zoom style camera behavior for the local player.

## 9.2 `PlayerReplicaAvatar`

Represents remote players visually in the world.

## 10. Current known gaps and next architectural work

## 10.1 Still-missing gameplay framework slices

- authoritative inventory state
- authored item definitions
- equipment/tool/charm runtime scaffolding
- richer behavior execution logic beyond the current baseline content link

## 10.2 Still-missing match experience slices

- map completion flow
- results/summary flow
- stronger playtest-facing feedback layers

## 10.3 Small schema cleanup still visible

`MapPresetDef.gd` still contains placeholder ids for future content domains that are not active in the current repo. Those should either be removed or turned into real authored content domains before they become misleading.

## 11. Architecture rules for future changes

## 11.1 Do not move board truth into tile scenes

Tile scenes remain replaceable presentation.

## 11.2 Do not hardcode future content directly into gameplay scripts

Continue extending through defs/resources, registries, validators, and explicit runtime systems.

## 11.3 Keep networking DTOs explicit

The current explicit multiplayer flow is safer than hiding gameplay truth inside scene ownership.

## 11.4 Keep runtime truth separate from debug helpers

The debug content overlay is useful and should stay observational only.
