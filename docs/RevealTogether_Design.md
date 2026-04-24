# RevealTogether - Design

## Purpose

This document captures the current design truth of the project based on the latest repo snapshot. It is not a wishlist. It describes what the prototype already proves, what is intentionally deferred, and what design constraints are now locked by the existing implementation.

## Current prototype status (2026-04-24)

The project is now a playable multiplayer prototype with:

- a dedicated-server flow
- an authoritative shared board
- client join/bootstrap replication
- a working third-person/top-down player controller with orbit camera
- tile reveal from the client through server-authoritative board actions
- data-authored map presets, tile families, tile variants, roles, spawn layouts, and tile behaviors
- a debug content inspection overlay for checking loaded content state

### Confirmed in the current repo

- Players spawn outside the map using an authored outer-perimeter spawn layout.
- Initial revealed tiles are taken from the outer edge of the board using a percentage-based unlock rule.
- Tile family placement is region-based and intentionally organic/distorted rather than a rigid checker or striping layout.
- Tile visuals are scene-driven placeholder assets, but gameplay truth still lives in board state, not in tile scenes.
- Role assignment exists and is data-authored, but role gameplay depth is still intentionally light.
- A standard tile behavior asset exists and is linked through tile variants.

### Intentionally not finished yet

- tool/charm/inventory gameplay
- results / map-complete flow
- milestone/progression content
- authored item content
- richer behavior-specific tile gameplay
- final production visual pass and readability polish

### Important repo truth

The prototype is now strong enough that future design work should plug into the current server-authoritative board loop rather than replace it.

## 1. High-level concept

RevealTogether is a shared board-clearing game where multiple players spawn outside a hidden map, move around the world in 3D space, and work inward by clearing tiles. The current prototype proves the spatial feel, the shared board state, and the data-driven content direction.

The board is the gameplay truth. The background image is presentation. Tile scenes are presentation. Player movement and tile reveals happen in the world, but the board state remains the source of truth.

## 2. Core player loop

1. Join a match.
2. Spawn outside the map boundary on ground near the board.
3. Move around the world with the 3D controller and camera rig.
4. Approach available edge tiles.
5. Click to request reveal.
6. Let the server validate and apply the reveal.
7. Watch the shared board open inward over time.

This is already the real playable loop of the prototype.

## 3. Locked v1 design direction

### 3.1 Shared progress with personal moments

The game is fundamentally cooperative. The board is shared and server-owned. Individual players still have spatial presence, movement, and later role/tool identity, but the core objective is collective reveal progress.

### 3.2 Roles are style identities first

Roles currently exist as authored content and assignment data. They should continue to behave as style/theme identities first, not hard class-locks with wildly asymmetric rules. Strong asymmetry is still out of scope for the current direction.

### 3.3 Tile families are broad presentation buckets first

Tile families currently act as broad thematic buckets. Variants provide specific visual expressions inside those buckets. This is the right direction for now: broad family mood, narrower variant expression, server-truth gameplay kept separate.

### 3.4 Equipment scope remains intentionally narrow

The current design direction still favors only two early gear slots:

- Tool
- Charm

Consumables should remain normal inventory content later rather than equipment slots.

### 3.5 Claims remain lightweight and time-based

The earlier design direction still holds: claims should be lightweight presence markers tied to tile interaction timing, not heavy ownership structures. That system is not implemented yet, but nothing in the repo contradicts it.

### 3.6 Scope exclusions remain the same

For now, do not expand design scope into:

- monetization
- crafting
- large role asymmetry
- production asset pipelines
- complex combat-style systems

## 4. Current authored content in the repo

### Map presets currently authored

- `map_preset.sandbox_64`

### Tile families currently authored

- `tile_family.overgrowth`
- `tile_family.scrap`

### Tile variants currently authored

- `tile_variant.overgrowth_patch`
- `tile_variant_scrap_plate`

### Roles currently authored

- `role.archaeologist`
- `role.groundkeeper`
- `role.hacker`
- `role.scavenger`

### Spawn layouts currently authored

- `spawn_layout.sandbox_outer_perimeter`
- `spawn_layout.sandbox_ring_8`

### Tile behaviors currently authored

- `tile_behavior.standard_reveal_clear`

## 5. Design implications of the current implementation

### 5.1 The board-opening fantasy is now proven

The switch to outside-the-map spawning plus edge-based initial access makes the reveal fantasy much clearer. Players now work inward from the perimeter instead of feeling dropped into the center.

### 5.2 Placeholder visuals are good enough for design iteration

The current scene-based placeholder cubes are enough to test:

- movement feel
- board scale
- edge approach
- reveal pacing
- family/variant readability at a prototype level

Readable target polish can still wait until the production art pass.

### 5.3 Data-driven content is now a real design constraint

Map presets, tile families, variants, behaviors, roles, and spawn layouts are already authored as content resources. New design work should continue through authored defs/resources instead of hardcoding more rules in gameplay scripts.

## 6. Recommended next design-sensitive priorities

1. Define early Tool and Charm design boundaries before inventory work expands.
2. Define the first real tile-behavior differences after the current standard behavior baseline.
3. Define what a completed map should trigger from a player-facing perspective.
4. Decide what minimum progression/results feedback is needed for internal playtests.

## 7. Summary

The project has moved past concept-only design. It now has a real shared board loop, real world-space player movement, and a real authored content foundation. Phase 4 is effectively complete in gameplay-framework terms, and the next meaningful design work should focus on the first gameplay-extension layer rather than more foundational rewrites.
