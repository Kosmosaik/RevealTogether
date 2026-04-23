# RevealTogether - Implementation Plan

## Purpose

This document tracks the recommended implementation order for **RevealTogether** and marks what is already true in the current repo.

The priority remains:
- authority before polish
- stable runtime boundaries before feature depth
- data-driven extension points before content explosion
- reusable systems before one-off hacks

---

## Current status snapshot (2026-04-23)

The repo is currently beyond the original Phase 1 starting point.

### Completed in code
- **Phase 0** is complete: project skeleton, runtime modes, config loading, logging, autoload bootstrap, content registry, and startup validation all exist.
- **Phase 1** is complete: dedicated server/client/local debug boot paths, hello/join flow, player spawn/despawn, and transform replication are implemented.
- **Phase 2** is complete: authoritative board state, tile claims, timed reveal ticks, clear/unlock propagation, hidden-image reveal, and final-rush transition are implemented.
- **Phase 3** is functionally complete for the current placeholder milestone: 3D movement, orbit camera, zoom, and world interaction are implemented.

### In progress in code
- **Phase 4** is partially complete: map preset assets, tile family assets, tile variant assets, visual scene references, registry loading, and validation exist.
- The remaining missing part of Phase 4 is broader authored content framework coverage such as roles, tile behavior assets, tuning assets, and content inspection tooling.

### Current repo truth
- The current playable loop is already a real server-authoritative shared board match.
- The board is no longer only a placeholder logic idea.
- Placeholder tile visuals are already being chosen through data-backed tile variant definitions.
- Readable targeting polish was intentionally deferred during the current asset-swap slice.

### Recommended next milestone
**Finish the remaining Phase 4 work before moving fully into Phase 5.**

That means the next branch should focus on:
- role definitions
- tile behavior definitions or behavior-link resources
- tuning/content resources that remove more gameplay assumptions from scripts
- lightweight content inspection/debug tooling

---

## 1. Phase overview

## Phase 0 - Project skeleton
**Status:** Complete.

### Goal
Create the permanent project structure and startup model.

### Exit criteria met
- runtime modes exist
- startup validation works
- content IDs can be registered and checked
- autoload bootstrap foundations are in place

---

## Phase 1 - Dedicated server loop
**Status:** Complete.

### Goal
Prove the multiplayer foundation with real connections.

### Exit criteria met
- clients can connect to the server
- players spawn consistently
- disconnect handling exists
- the server owns authoritative session state

---

## Phase 2 - Board and reveal core
**Status:** Complete.

### Goal
Implement the full playable board loop.

### Exit criteria met
- a full map can be started and completed
- claims exist and expire on timeout
- tile progress persists in authoritative board state
- hidden-image reveal underlay works
- final-rush transition exists

### Repo notes
The current board runtime is built around `BoardState`, `TileRecord`, `ChunkState`, `BoardBuilder`, and `BoardActionService`.
Board state is replicated by snapshot on join and by changed-tile delta afterward.

---

## Phase 3 - 3D player controller and camera
**Status:** Complete for the current placeholder milestone.

### Goal
Make the game feel right in its intended 3D form.

### Exit criteria currently satisfied
- players move in 3D space with server-approved transform requests
- orbit camera and zoom are in place
- nearby players are visible through replica avatars
- board interaction works through world-to-grid conversion

### Deferred inside this phase
These are intentionally still light or unfinished:
- stronger readable targeting feedback
- final art readability polish
- richer world dressing

That deferred work should be treated as later presentation polish unless it blocks usability.

---

## Phase 4 - Data-driven content framework
**Status:** In progress.

### Goal
Move content assumptions out of gameplay code.

### Already complete in this phase
- `MapPresetDef` resources exist
- `TileFamilyDef` resources exist
- `TileVariantDef` resources exist
- tile variants can point at authored visual scenes
- `ContentRegistry` loads these assets from configured content directories
- `StartupValidator` validates IDs and cross-references for the currently supported content types

### Remaining work in this phase
- define role data assets
- define tile behavior assets or equivalent links
- move more tuning into authored resources where appropriate
- add lightweight content inspection/debug tooling
- widen validation coverage as more content domains come online

### Exit criteria for full completion
- roles can be added through data
- tile families/variants/map presets are all data-authored and validated
- behavior links are validated cleanly
- content authors can inspect the loaded content state without digging through runtime code

---

## Phase 5 - Tool, charm, and inventory scaffolding
**Status:** Not started.

### Goal
Create the backbone for items without over-designing final loot balance.

### Main work
- define item base structures
- define Tool and Charm data models
- implement inventory ownership/state
- implement server-approved item grants
- connect tile clear events to future drop hooks
- add placeholder UI for item visibility

### Important note
This phase should create the structure, not the final item depth.

---

## Phase 6 - Map progression feedback and results
**Status:** Not started.

### Goal
Add the first satisfying full-match outcome layer.

### Main work
- global map progress tracking and presentation
- map-complete sequence
- contribution/result packaging
- results UI and final reveal framing
- archive-ready output structure for later reuse

---

## Phase 7 - Internal hardening
**Status:** Not started.

### Goal
Prepare the build for heavier internal testing.

### Main work
- profile board update cost
- profile tile visual update cost
- test reconnect and reset paths
- improve debug visibility
- improve logging and validation coverage
- reduce accidental local-only assumptions

---

## 2. Recommended immediate work order

1. Finish the remaining **Phase 4** content framework work.
2. Move into **Phase 5** item/equipment scaffolding.
3. Build **Phase 6** map-complete/results flow.
4. Use **Phase 7** to harden the playable loop before broader internal testing.

---

## 3. Milestone summary

## Milestone A - Server-connected sandbox
**Status:** Reached.

Includes:
- server boot
- client join flow
- visible player presence
- basic transform replication

## Milestone B - Fully playable shared board loop
**Status:** Reached.

Includes:
- map start
- unlock progression
- claim timeout
- tile clearing
- hidden-image reveal
- final-rush transition

## Milestone C - 3D feel validation
**Status:** Reached for current placeholder scope.

Includes:
- 3D controller
- orbit camera and zoom
- world interaction with the board
- visible social presence

Deferred polish:
- stronger targeting readability
- better asset readability and environment dressing

## Milestone D - Data-driven framework validation
**Status:** Partially reached.

Already present:
- map presets loaded from data
- tile families loaded from data
- tile variants loaded from data
- startup validation for supported content

Still missing:
- role definitions
- behavior definitions
- broader tuning resources
- content inspection/debug utilities

## Milestone E - Item backbone
**Status:** Not started.

## Milestone F - Internal test candidate
**Status:** Not started.

---

## 4. Discipline rules that still apply

## 4.1 Do not backslide into hardcoded gameplay content
IDs, authored content links, and tuning values that belong in defs/resources should keep moving out of gameplay scripts.

## 4.2 Separate runtime truth from presentation
The board, claims, clear state, and unlock rules belong to the authoritative runtime.
Visual scenes and overlays should only render that truth.

## 4.3 Extend through framework hooks
New tile families, future roles, items, and behavior types should plug into the existing content/runtime structure rather than patching central scripts with special cases.

## 4.4 Treat placeholder visuals as temporary presentation, not gameplay truth
The current scene-based placeholder tiles prove the asset-swap path.
They should not become an excuse to move gameplay ownership into visual scenes.

---

## 5. Practical next-branch target

The cleanest next branch is:

**Phase 4 completion branch**

Suggested scope:
- add the first `RoleDef` resource type and registry support
- add behavior-definition support or explicit validated behavior links
- move more board/content tuning into authored resources where it belongs
- add a simple debug/content-inspection surface for loaded defs

That keeps the project aligned with the long-term architecture and makes the later item phase safer.
