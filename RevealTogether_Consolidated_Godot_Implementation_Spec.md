# RevealTogether - Consolidated Godot Implementation Spec

## Purpose

This consolidated spec is the single high-level reference for the current RevealTogether repo state and the recommended next implementation direction.

It intentionally prioritizes **repo truth** over older aspirational planning language.
Where older documents described future systems as if they already existed, this spec now separates:
- what is already implemented
- what is partially implemented
- what remains planned

---

## Current implementation snapshot (2026-04-23)

RevealTogether currently has a working server-authoritative multiplayer prototype with a real shared board loop.

### Already implemented
- startup/bootstrap flow with runtime-mode selection
- config loading and startup validation
- content registry loading for current supported resource types
- dedicated server, client, and local debug modes
- authoritative match/session flow
- player spawn/despawn and transform replication
- authoritative board state and tile runtime
- reveal ticks, claims, claim expiry, clear/unlock propagation, and final rush
- hidden-image reveal underlay
- 3D player movement, orbit camera, zoom, and visible player avatars
- data-authored map preset / tile family / tile variant loading
- scene-based placeholder tile visuals chosen through tile variant defs

### Partially implemented
- the broader data-driven content framework
  - map presets, tile families, and tile variants are present
  - roles, behaviors, and wider tuning resources are not yet present

### Not implemented yet
- item/inventory/tool/charm runtime
- results and map-complete presentation
- broader authored family/variant roster
- readable targeting polish for final assets
- archive/reward pipeline

---

## 1. Current repo structure

```text
autoload/app/
  AppBootstrap.gd
  ContentRegistry.gd
  LogService.gd
  RuntimeConfig.gd

core/
  content/GameContentDef.gd
  validation/StartupValidator.gd

data/
  map_presets/
  tile_families/
  tile_variants/
  roles/
  tile_behaviors/
  items/tools/
  items/charms/
  tuning/

game/
  client/camera/PlayerOrbitCameraRigController.gd
  runtime/board/
  runtime/match/

net/
  protocol/ConnectionDtos.gd
  session/MatchSessionService.gd

scenes/
  bootstrap/
  world/
    ClientSandboxWorld.*
    board/
    replicas/
```

This structure is already good enough to keep extending.
The main need now is to **fill the existing extension points**, not replace the structure.

---

## 2. Current runtime ownership model

## 2.1 Bootstrap and content
- `AppBootstrap` loads config, loads content, runs validation, and opens the correct runtime scene.
- `RuntimeConfig` is the shared config access layer.
- `ContentRegistry` loads currently supported content defs/resources.
- `StartupValidator` validates supported content IDs and cross-links before the game proceeds.

## 2.2 Multiplayer/session ownership
- `MatchSessionService` is the active session/network orchestrator.
- The server owns player truth and board truth.
- Clients request actions; they do not author gameplay truth.

## 2.3 Match runtime ownership
- `MatchState` holds authoritative per-match state.
- `MatchPlayerState` holds authoritative per-player state.
- `MatchSpawnPlanner` calculates spawn positions around the board.

## 2.4 Board runtime ownership
- `BoardState` owns board-wide authoritative truth.
- `TileRecord` owns tile-level authoritative truth.
- `ChunkState` groups tile indices by chunk.
- `BoardBuilder` creates board runtime state from map/content data.
- `BoardActionService` applies reveal/clear/claim/unlock/final-rush rules.

## 2.5 Client presentation ownership
- `ClientSandboxWorld` orchestrates the playable 3D scene on the client.
- `BoardGridView3D` renders the board from replicated state.
- `BoardTileVisual` and variant scenes render tile appearance only.
- `PlayerOrbitCameraRigController` owns orbit camera behavior.

---

## 3. Current supported content model

## 3.1 Supported resource types today
- `MapPresetDef`
- `TileFamilyDef`
- `TileVariantDef`

## 3.2 Current authored content slice
- map preset: `map_preset.sandbox_64`
- tile families: `tile_family.overgrowth`, `tile_family.scrap`
- tile variants: `tile_variant.overgrowth_patch`, `tile_variant.scrap_plate`

## 3.3 Current visual-content link
`TileVariantDef` contains the visual scene reference used by the board view to instantiate the correct placeholder asset for a tile.

That means the project already has the correct **data -> visual scene** swap path for later art replacement.

---

## 4. Current playable loop

1. Start server/client or local debug mode.
2. Join the authoritative match.
3. Receive full board snapshot and player snapshot data.
4. Move around the board in 3D.
5. Click a tile location to request reveal progress.
6. Let the server process claims, damage ticks, and clears.
7. Replicate changed tiles back to connected clients.
8. Reveal more of the hidden image.
9. Enter final rush when the remaining tile threshold is reached.

This loop is already real and should remain the foundation for future content.

---

## 5. Current implementation-phase truth

## Phase 0 - Project skeleton
**Status:** Complete.

## Phase 1 - Dedicated server loop
**Status:** Complete.

## Phase 2 - Board and reveal core
**Status:** Complete.

## Phase 3 - 3D player controller and camera
**Status:** Complete for the current placeholder milestone.

Readable targeting polish is still deferred.

## Phase 4 - Data-driven content framework
**Status:** In progress.

Completed parts:
- map presets
- tile families
- tile variants
- content loading
- validation
- variant-driven placeholder scenes

Missing parts:
- roles
- behaviors
- wider tuning resources
- content inspection/debug tooling

## Phase 5 - Tool/charm/inventory scaffolding
**Status:** Not started.

## Phase 6 - Results/map-complete flow
**Status:** Not started.

## Phase 7 - Hardening and internal-test preparation
**Status:** Not started.

---

## 6. Recommended next milestone

The correct next milestone is:

**Finish the remaining Phase 4 framework work.**

Recommended focus:
- add role definitions/resources
- add behavior-definition support or validated behavior links
- move more content/tuning assumptions out of scripts and into defs/resources where appropriate
- add simple content-inspection/debug support

This is the most future-proof next step because it strengthens the extension points needed by every later content system.

---

## 7. Locked architecture rules

## 7.1 Server authority remains non-negotiable
Claims, clear state, unlock state, completion state, and player transform truth remain server-owned.

## 7.2 Presentation must not become gameplay truth
Tile visual scenes are presentation only.
The board runtime remains authoritative.

## 7.3 Content should be added through defs/resources
Do not hardcode future gameplay content directly into central scripts when it belongs in authored resources.

## 7.4 Placeholder visuals are replaceable, not structural
The current cube-based placeholder tile scenes are proving the asset path.
They should be replaced later by updating defs/scenes, not by redesigning board truth.

## 7.5 Debug systems should observe truth, not own it
Inspection tools, overlays, and logs should never become hidden gameplay dependencies.

---

## 8. Known deliberate gaps

These gaps are currently acceptable and should not be mistaken for missing foundations:
- only a small authored family/variant set exists
- role data does not exist yet
- tool/charm/inventory systems do not exist yet
- map-complete/results flow does not exist yet
- targeting readability polish is intentionally light

The foundation is already there.
The next work is about **filling the framework**, not inventing a new one.

---

## 9. Summary

RevealTogether is currently in a healthy state for continued development.
The repo already proves:
- authoritative multiplayer
- authoritative board progression
- hidden-image reveal payoff
- 3D movement/camera/presence
- first data-driven tile-visual content path

The project should now continue by finishing the remaining data-driven framework slices and then building items/results on top of that stable core.
