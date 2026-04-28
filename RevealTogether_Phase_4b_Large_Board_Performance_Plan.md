# RevealTogether Phase 4b Addendum: Large Board Performance Plan

## Purpose

This addendum covers the large-board performance work discovered while testing boards larger than the original 64 x 64 sandbox size. The project now has a clearer large-board direction:

- keep the full board visible at all times,
- avoid classic proximity chunk loading that hides distant tiles,
- use chunking for batching, indexing, streaming, and dirty-state organization,
- use cheap full-board rendering for scale,
- layer detailed visuals only where they matter.

The goal is not to make every tile on a huge board a full scene instance. The goal is to make large boards feel massive, readable, stable, and playable while keeping runtime truth separate from presentation.

## Current Large-Board Findings

### 1. Server board generation cost

The original procedural tile-family assignment compared every tile against every chunk seed. With a 256 x 256 board and 4 x 4 chunks, that meant:

- 65,536 tiles,
- 4,096 chunks / seed points,
- roughly 268 million tile-to-seed distance checks.

This explained the long server startup time on large boards.

### 2. Client detailed scene cost

The original board view created one detailed tile visual scene per tile. A 256 x 256 board could therefore create 65,536 `Node3D` scene instances, each with multiple child nodes and mesh instances. That was too expensive for large boards.

### 3. Full-board snapshot payload size

After server generation and rendering were improved, boards around 224 x 224 loaded, but 240 x 240 and 256 x 256 failed to join. That cutoff showed that the remaining blocker was the initial join snapshot payload: the server was sending one huge reliable RPC containing every tile dictionary.

### 4. Large-board visual quality

The current large-board MultiMesh path is performant, but visually simple. Large boards now render as broad state-colored geometry instead of authored detailed tile visual scenes. This is acceptable as a foundation, but not the final desired look.

### 5. Runtime delta performance

The first MultiMesh implementation still rebuilt too much visual data on tile deltas. Incremental indexed MultiMesh updates fixed the click/removal freeze on large boards.

## Design Goals

- Keep the whole board visible.
- Do not rely on hiding distant chunks as the main performance solution.
- Keep authoritative runtime truth in `BoardState`, `TileRecord`, and related runtime classes.
- Keep presentation state in board view / renderer nodes.
- Keep tuning in config/resources instead of hardcoding gameplay values.
- Use chunking for batching, indexing, streaming, dirty tracking, and future network optimization.
- Preserve authored tile visual scenes for close-range detail, hover/selection feedback, and small boards.
- Make large boards load progressively and predictably instead of freezing or silently failing.

## Revised Implementation Order

## Step 1 — Populate chunk state during board generation

Status: Implemented.

When each `TileRecord` is created, ensure its `ChunkState` exists and add the tile index to that chunk. This makes existing chunk metadata real runtime data instead of only dimensions.

Expected effect:

- No visual change.
- No gameplay change.
- Safer base for later chunk snapshots, dirty-chunk replication, renderer batching, and diagnostics.

## Step 2 — Replace all-seed tile-family search with local chunk-seed search

Status: Implemented.

Add a configurable `family_region_seed_search_radius_chunks` value to `MapPresetDef`.

Instead of each tile checking every chunk seed, each tile should only compare seed points inside a local chunk radius around the tile's chunk. For a radius of 2, the tile checks at most 25 seed points instead of 4,096 on the 256 x 256 / 4 x 4 chunk test.

Expected effect:

- Major server generation speed improvement.
- Deterministic output for a given config.
- Tile-family regions remain organic enough for current prototype needs.

## Step 3 — Add a baseline MultiMesh board renderer path

Status: Implemented.

Use `MultiMeshInstance3D` nodes in `BoardGridView3D.tscn` for mass tile rendering on large boards.

The baseline renderer should render broad tile states as MultiMeshes:

- locked tiles,
- unlocked tiles,
- claimed tiles,
- cleared tiles, only when configured to show cleared tile covers.

Detailed tile visual scenes remain available for smaller boards, but large boards should not instantiate one full scene per tile.

Expected effect:

- Client can display large boards without creating tens of thousands of tile scene instances.
- The whole board remains visible.
- Future art/detail can be layered selectively later.

## Step 4 — Make large-board tile deltas incremental

Status: Implemented.

The first MultiMesh path made large boards possible, but tile changes could still rebuild too much data. The next step was to keep indexed MultiMesh instances alive and update only the changed tile instance when a tile changes state.

Expected effect:

- Clicking/removing a tile no longer causes a noticeable full-board rebuild freeze.
- Large-board movement remains smooth after the board has loaded.
- The renderer keeps a clear path toward chunk-level or state-level batching later.

## Step 5 — Stream the initial join board snapshot

Status: Implemented.

The server should not send every tile dictionary in one giant reliable join snapshot. For large boards, the join process should send:

1. join metadata and board summary,
2. tile snapshot chunks,
3. a snapshot-complete message.

The client should emit the normal joined-match flow only after the streamed board snapshot is complete.

Expected effect:

- Boards above the old failure point can join reliably.
- 240 x 240 and 256 x 256 boards should no longer fail only because the join payload is too large.
- Larger boards such as 384 x 384 can work, although initial loading can still take time.

## Step 6 — Add hybrid detailed visuals for large boards

Status: Next recommended step.

Large boards should keep the cheap full-board MultiMesh renderer, but add a separate detail layer that spawns authored `BoardTileVisual` scenes only for a limited set of important tiles.

Suggested detail candidates:

- tiles near the local player,
- hovered tile,
- selected/targeted tile,
- recently damaged tile,
- tiles in a small camera-focus radius.

The full board remains visible through MultiMesh. The detail layer adds authored geometry only where the player is looking or interacting.

Expected effect:

- Large boards stop looking like only flat/simple state-colored blocks.
- Small boards can still use full detailed tile visuals.
- Large boards keep stable performance because the detailed scene count is capped.
- The system does not require hiding distant chunks.

Important design note:

This should be implemented as presentation-only detail. It must not become runtime truth. Tile state still comes from board snapshots/deltas.

## Step 7 — Add progressive client-side board visual build

Status: Planned.

Even with streamed snapshots, the client still eventually receives and processes every tile, then builds MultiMesh data for the board. Large boards can work, but initial loading can take a while.

The next loading improvement is to build visual data in batches across multiple frames.

Expected effect:

- The client does not freeze as long during initial board construction.
- Loading can show progress.
- Very large boards feel more stable and intentional during join.

Suggested behavior:

- receive the full streamed board snapshot,
- store tile snapshots,
- build render instances in configurable batches,
- show loading/progress state until the board view is ready.

## Step 8 — Add explicit large-board loading/progress feedback

Status: Planned.

After progressive build exists, expose clear user-facing loading status instead of making the client appear stuck.

Suggested loading states:

- connecting,
- receiving board snapshot chunks,
- building board visuals,
- spawning player,
- ready.

Expected effect:

- Large board loading feels controlled instead of broken.
- Debugging future large-board regressions becomes easier.
- It becomes clearer whether a delay is network transfer, snapshot processing, or renderer build.

## Step 9 — Improve large-board visual richness without per-tile scenes everywhere

Status: Planned.

After the hybrid detail layer exists, improve the cheap full-board layer so distant tiles are still more readable.

Possible future approaches:

- per-family or per-variant MultiMesh groups,
- small height variation in the MultiMesh layer,
- per-instance color/custom data if the material pipeline supports it cleanly,
- chunk-level visual tinting,
- subtle grid/region overlays,
- LOD meshes for common tile families.

Expected effect:

- Distant board areas feel less like a single flat color field.
- The board remains cheap enough for very large maps.
- Authored detail still appears near the player through the hybrid detail layer.

## Step 10 — Compact initial board snapshots further

Status: Later architectural optimization.

Streaming fixed the immediate large-payload failure, but the server still sends many static fields for every tile. Long term, the client should not need every static tile field from the server if the board can be reconstructed deterministically from shared content, map preset, and seed.

Future direction:

- server sends map preset ID, board seed, dimensions, and mutable runtime state,
- client reconstructs static tile layout locally,
- server sends only authoritative mutable state and correction data.

Expected effect:

- Smaller join payloads.
- Faster large-board joins.
- Better scalability for very large maps.

This should come after the current systems are stable because it touches network protocol, determinism, content manifests, and validation more deeply.

## Step 11 — Add diagnostics and safety limits

Status: Planned.

Add large-board logging and guardrails so future issues are visible immediately.

Useful diagnostics:

- board width/height/tile count,
- chunk count,
- renderer mode selected,
- tile snapshot chunk count,
- snapshot receive progress,
- visual build progress,
- detailed visual overlay count,
- timing for server generation,
- timing for client board build.

Expected effect:

- Easier performance debugging.
- Safer future changes.
- Better confidence when testing bigger boards.

## Updated Acceptance Checks

### Small board checks

- A 64 x 64 board still loads and plays normally.
- Small boards still use authored detailed tile visuals by default.
- Revealing a tile still updates the correct tile state visually.
- Cleared tiles still expose the reveal underlay according to existing config.

### Large board checks

- A 224 x 224 board loads and plays smoothly.
- A 256 x 256 board can join successfully.
- A 384 x 384 board can join successfully, even if initial loading takes time.
- Clicking/removing a tile on a large board does not cause a full-board rebuild freeze.
- The whole board remains visible after loading.
- Large-board rendering does not instantiate one detailed tile scene per tile.

### Architecture checks

- No gameplay content is hardcoded in runtime scripts.
- Runtime board truth remains in `BoardState` and `TileRecord`, not in presentation nodes.
- Large-board visual detail remains presentation-only.
- Config/resources control thresholds, batch sizes, and tuning values.
- Chunking is used for batching/indexing/streaming foundations, not for hiding the map by default.

## Recommended Next Implementation Batch

The next implementation batch should be Step 6:

1. Add a large-board detailed visual overlay layer.
2. Keep the current MultiMesh full-board renderer active.
3. Spawn detailed `BoardTileVisual` scenes only for a capped local/important set of tiles.
4. Make the cap/radius configurable.
5. Ensure the detail layer is presentation-only and rebuilt from cached tile snapshots.

After that, test:

- 64 x 64 board,
- 224 x 224 board,
- 256 x 256 board,
- 384 x 384 board.

If visual quality feels better and runtime remains smooth, move to progressive client-side board visual build and loading/progress feedback.
