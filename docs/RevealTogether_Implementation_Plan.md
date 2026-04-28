# RevealTogether - Implementation Plan

## Purpose

This document tracks the implementation phase status for RevealTogether. It reflects the current repo state after Phase 4 and the Phase 4b quality/large-board work.

## Current status snapshot (2026-04-28)

### Completed in code

- Phase 0 - project skeleton.
- Phase 1 - dedicated server loop.
- Phase 2 - board and reveal core.
- Phase 3 - 3D player controller and camera.
- Phase 4 - data-driven content framework.
- Phase 4b baseline cleanup/config/validation/file organization work that has been chosen so far.
- Phase 4b large-board performance foundation:
  - chunk state population,
  - faster local chunk-seed tile-family assignment,
  - MultiMesh full-board renderer path,
  - incremental MultiMesh tile deltas,
  - streamed join board snapshots,
  - compact streamed snapshot payloads,
  - hybrid capped detailed tile overlay,
  - progressive client-side board visual build,
  - loading/progress UI.

### Current practical state

The project is still pre-Phase 5. The latest work has focused on making the Phase 4 foundation stable, maintainable, and able to support much larger boards without hiding distant chunks.

### Recommended immediate path

Finish or defer the remaining Phase 4b large-board polish items before starting Phase 5. The main remaining Phase 4b topic is visual richness/readability for large boards without returning to per-tile scene instances everywhere.

## Phase 0 - Project skeleton

### Goal

Create the Godot project foundation, boot path, config structure, and initial source organization.

### Status

Complete.

## Phase 1 - Dedicated server loop

### Goal

Support a dedicated server runtime and client connection flow.

### Status

Complete.

### Current notes

The project has client, dedicated server, and local debug bootstrap scenes. The network config is under `config/defaults/app.cfg` and the runtime-specific defaults are under `config/defaults/client.cfg`, `server.cfg`, and `local_debug.cfg`.

## Phase 2 - Board and reveal core

### Goal

Implement authoritative board state and a playable reveal/clear loop.

### Status

Complete.

### Current notes

The server owns board state. Board actions are validated through server-side runtime services, then replicated to clients through board deltas.

## Phase 3 - 3D player controller and camera

### Goal

Move the prototype into a 3D world with player movement, camera, and world-space board interaction.

### Status

Complete.

### Current notes

The camera supports orbit/pitch/zoom configuration. The client world handles player replicas, board click targeting, and focus/hover information used by the board view.

## Phase 4 - Data-driven content framework

### Goal

Move prototype content into authored defs/resources and validate those links.

### Status

Complete in practice.

### Current authored systems

- Map presets.
- Tile families.
- Tile variants.
- Tile behaviors.
- Roles.
- Spawn layouts.

### Current validation

Startup validation checks core config/assets, content registry state, map preset values, spawn layout values, tile family/variant/behavior links, role presence, and client-side tile visual scene structure.

## Phase 4b - Quality, stability, maintainability, and large-board support

### Goal

Stabilize the Phase 4 foundation before Phase 5. Improve maintainability, validation, visual configurability, and large-board behavior.

### Status

In progress, with the major large-board foundation implemented.

### Completed Phase 4b items

- Default tile HP moved to config.
- Visual/world values made configurable where currently useful.
- Reveal images moved out of the project root into `assets/reveal_images/`.
- Startup validation for tile visual scenes improved.
- `MapPresetDef` cleanup started; `family_region_seed_search_radius_chunks` is implemented and used.
- Chunk state is populated during board generation.
- Board generation avoids all-seed-per-tile search by using local chunk-seed search.
- Large boards use a MultiMesh full-board renderer path.
- Tile deltas update MultiMesh state incrementally.
- Initial board snapshots can be streamed instead of sent as one giant payload.
- Streamed snapshots can use compact tile data.
- Large board visuals build progressively across frames.
- Loading/progress UI displays receiving/building stages.
- Large boards use capped detailed tile overlays for nearby/hovered/recently changed important tiles.

### Skipped or deferred Phase 4b items

- Broad visual/lighting/palette changes were tested and reverted because the result was not desired yet.
- Full script-folder reorganization is not being forced now; the current folder layout is domain-based and acceptable.
- The optional board geometry helper is deferred unless future duplication or errors justify it.
- Final large-board art direction is deferred.

### Remaining Phase 4b recommendation

Improve large-board visual richness/readability without adding per-tile scene instances everywhere. Good candidates are per-family MultiMesh grouping, subtle height/scale variation, chunk/region tinting, better distant tile material strategy, and more readable overlay rules.

## Phase 5 - Tool, charm, and inventory scaffolding

### Goal

Add the smallest useful server-authoritative equipment/inventory backbone.

### Not started.

### Main work

- Add item/content defs.
- Add authoritative inventory state.
- Add Tool slot.
- Add Charm slot.
- Add server-authoritative replication for inventory/equipment state.
- Keep role/tool/charm relationships flexible and data-driven.

### Important note

Do not start Phase 5 by inventing a full item economy. Start with the smallest useful framework that can support future tools and charms cleanly.

## Phase 6 - Map progression feedback and results

### Goal

Add player-facing feedback for completed maps and match results.

### Not started.

### Main work

- Detect map completion cleanly.
- Display completion/results feedback.
- Decide what data is shown after a map is completed.
- Keep this separate from inventory/progression until those systems exist.

## Phase 7 - Internal hardening

### Goal

Prepare for smoother internal testing with friends.

### Not started as a formal phase.

### Main work

- Improve error handling.
- Improve reconnect/leave behavior.
- Add more diagnostics for join/load failures.
- Validate common server/client setup paths.
- Tune board sizes and runtime config defaults for internal playtests.

## Recommended next work order

1. Finish the current Phase 4b large-board plan by improving distant-board readability/presentation.
2. Run a manual test pass on small, medium, and large boards.
3. Commit and push the Phase 4b progress.
4. Start Phase 5 with item defs plus Tool/Charm equipment scaffolding.

## Manual test checklist before starting Phase 5

- Dedicated server starts without validation errors.
- Client connects and passes hello/content-hash handshake.
- 64 x 64 board joins and renders correctly.
- 224 x 224 or larger board joins and renders correctly.
- 384 x 384 or intended stress-test board joins, streams, builds visuals, and becomes interactive.
- Loading/progress UI appears during long joins/builds and hides when ready.
- Clicking/revealing a tile does not cause a noticeable full-board freeze.
- Nearby/hovered/recent detail overlay does not flicker against the MultiMesh layer.
- Player movement/camera remain smooth after loading.

## Discipline rules that still apply

### Do not backslide into hardcoded gameplay content

Use defs/resources/config for gameplay content and tuning.

### Separate runtime truth from presentation

Board state and match state remain authoritative runtime truth. Visual scenes, MultiMeshes, debug UI, and loading UI remain presentation/observation.

### Extend through framework hooks

Prefer existing content registry, startup validation, DTO, runtime service, and config patterns.

### Treat placeholder visuals as temporary presentation

The current prototype visuals are replaceable and should not become required gameplay architecture.
