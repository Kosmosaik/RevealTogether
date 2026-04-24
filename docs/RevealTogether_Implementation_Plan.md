# RevealTogether - Implementation Plan

## Purpose

This document tracks implementation truth against the current repo. It focuses on what is already complete, what remains, and what should happen next without inventing architecture that the project does not currently use.

## Current status snapshot (2026-04-24)

### Completed in code

- Phase 0: project skeleton
- Phase 1: dedicated server loop
- Phase 2: board and reveal core
- Phase 3: 3D player controller and camera
- Phase 4: data-driven content framework, functionally complete in practice

### Current repo truth

The repo currently contains authored content for:

- map presets
- tile families
- tile variants
- roles
- spawn layouts
- tile behaviors

The repo also includes:

- startup validation
- content registry loading
- content inspection overlay
- role assignment on join
- authored outer-perimeter spawning
- edge-based initial board unlocks
- scene-based tile visuals linked through variant content

### Small schema cleanup still visible

`MapPresetDef.gd` still contains unused placeholder id fields that are not backed by active resource domains in the current repo. This is a cleanup item, not a blocker to moving forward.

### Recommended next milestone

Move into Phase 5 and keep the next branch focused on gameplay-extension scaffolding rather than more framework churn.

## 1. Phase overview

## Phase 0 - Project skeleton

### Goal

Establish a clean Godot project structure with explicit runtime ownership and enough bootstrap/config plumbing to support later multiplayer and content work.

### Exit criteria met

- bootstrap path exists
- runtime config exists
- logging/content bootstrap exists
- project structure is modular enough for later phases

## Phase 1 - Dedicated server loop

### Goal

Get a server process and client process talking cleanly enough to connect, join, and keep a minimal session alive.

### Exit criteria met

- headless dedicated server mode works
- client can connect and join
- basic session flow exists
- join/bootstrap path is functioning

## Phase 2 - Board and reveal core

### Goal

Make the server own a real board, replicate it to clients, and allow tile reveal actions through an authoritative flow.

### Exit criteria met

- server-owned board state exists
- tile DTO replication works
- click-to-reveal path works
- reveal requests are validated server-side
- board snapshots and updates are applied on the client

### Repo notes

The current repo goes beyond a trivial board proof. Board generation, tile content assignment, reveal state, and final-rush threshold support are already present.

## Phase 3 - 3D player controller and camera

### Goal

Validate that the prototype feels right as a navigable 3D world rather than only as a board test.

### Exit criteria currently satisfied

- controllable player pawn exists
- orbit camera rig exists
- camera-relative movement exists
- replicated player avatars exist
- client sandbox world integrates player movement with board interaction

### Deferred inside this phase

- readability polish for precise target selection
- final production camera tuning
- art-driven interaction feedback

These remain presentation concerns, not blockers for the phase.

## Phase 4 - Data-driven content framework

### Goal

Move gameplay-facing authored content into explicit defs/resources that load, validate, and integrate cleanly with the runtime.

### Completed in this phase

- `MapPresetDef`
- `TileFamilyDef`
- `TileVariantDef`
- `RoleDef`
- `SpawnLayoutDef`
- `TileBehaviorDef`
- content registry loading of authored resources
- startup validation of authored resources and links
- debug content inspection overlay
- role assignment via authored role list
- variant-linked scene visuals
- variant-linked tile behavior ids

### Practical completion status

Phase 4 is functionally complete. The authored-content framework is real and working in the repo.

### Optional cleanup / follow-up

- remove or implement the unused placeholder ids still present in `MapPresetDef.gd`
- expand tile behaviors beyond the single standard baseline
- deepen role content only when actual gameplay systems need it

### Exit criteria satisfied in practice

- content authors can add map/tile/role/behavior/spawn resources
- those resources load through the registry
- those resources are validated at startup
- the runtime consumes authored content instead of hardcoded gameplay content in the core paths
- debug tooling can inspect loaded content state

## Phase 5 - Tool, charm, and inventory scaffolding

### Goal

Add the first real gameplay-extension layer without breaking the server-authoritative board loop.

### Main work

- authoritative inventory state
- tool slot and charm slot scaffolding
- data-authored item/resource definitions
- tool/charm application hooks that can later affect reveal behavior, pacing, or utility
- clear separation between runtime state and presentation/debug data

### Important note

Phase 5 should not turn into full progression or crafting scope. It should establish the first clean extension backbone for later design work.

## Phase 6 - Map progression feedback and results

### Goal

Add a player-facing sense of map progress and completion.

### Main work

- map-complete trigger flow
- result / summary presentation
- progress feedback around remaining tiles and board completion
- any minimum progression feedback needed for internal tests

## Phase 7 - Internal hardening

### Goal

Prepare the prototype for more reliable internal multiplayer testing.

### Main work

- bug fixing
- clearer validation/errors
- replication hardening
- disconnect/rejoin edge cases
- polish around startup and content iteration workflow

## 2. Recommended immediate work order

1. Do the tiny `MapPresetDef` schema cleanup.
2. Push the Phase 4 wrap-up branch.
3. Start Phase 5 on a fresh branch.
4. Implement minimal authoritative inventory and equipment-slot state.
5. Add the first data-authored item defs needed for Tool and Charm.

## 3. Milestone summary

## Milestone A - Server-connected sandbox

Achieved.

The project already supports dedicated server startup, client connection, session join, and world/bootstrap flow.

## Milestone B - Fully playable shared board loop

Achieved.

The board is shared, authoritative, and revealable in multiplayer.

## Milestone C - 3D feel validation

Achieved.

The project already proves movement, orbit camera, camera-relative motion, and world-space board interaction.

## Milestone D - Data-driven framework validation

Achieved in practice.

The content framework is real, authored, loaded, validated, and consumed by live runtime code.

## Milestone E - Item backbone

Not started.

This is the clean next milestone.

## Milestone F - Internal test candidate

Not yet.

This comes after Phase 5/6 work and another hardening pass.

## 4. Discipline rules that still apply

## 4.1 Do not backslide into hardcoded gameplay content

Content that belongs in authored defs/resources should continue to move there, not back into gameplay scripts.

## 4.2 Separate runtime truth from presentation

Keep board state, player state, and future inventory/equipment state authoritative and explicit. Tile scenes and overlays must stay presentation-only.

## 4.3 Extend through framework hooks

Use the content framework, validators, and runtime service boundaries that already exist.

## 4.4 Treat placeholder visuals as temporary presentation, not gameplay truth

Current scene visuals are replaceable. They should not become the owner of board logic.

## 5. Practical next-branch target

**Phase 5 bootstrap:** add the minimum authoritative item/inventory/equipment scaffolding needed to support future Tool and Charm gameplay.
