# RevealTogether - Design

## Purpose

This document records the current player-facing design direction for **RevealTogether**.
It is intentionally aligned with the current repo state so the design docs do not drift away from what is actually implemented.

---

## Current prototype status (2026-04-23)

The live project is no longer only a networking sandbox.
It now proves the first playable shared board loop in 3D.

### Confirmed in the current repo
- dedicated server, client, and local debug runtime modes
- join flow with authoritative server-owned session state
- shared logical board with full snapshot on join and board delta replication afterward
- tile claiming, timed claim expiry, tile clearing, unlock propagation, and final-rush activation
- hidden-image reveal under the board
- 3D movement, orbit camera, zoom, and visible remote player avatars
- data-authored map preset, tile family, and tile variant loading with startup validation
- placeholder scene-based tile visuals for the currently authored tile variants

### Intentionally not finished yet
- role data assets and role-specific presentation/content
- tool, charm, inventory, and drop scaffolding
- richer tile behaviors beyond the current standard reveal/clear loop
- readable targeting/highlight polish for final art-driven tiles
- map-complete presentation, results flow, and archive output
- the full planned family/variant roster from the longer-term design target

### Important repo truth
The project currently proves the gameplay loop with a **small authored content slice**, not the full future content plan.
That is expected and correct for the current phase.

---

## 1. High-level concept

RevealTogether is an online multiplayer game where players move around a 3D space and clear a large shared tile board to reveal a hidden image underneath.

The board is the shared objective.
Players contribute to the same map, but still get local competition, social presence, recognizable themes, and room for future loot and role flavor.

The intended feel is:
- cooperative at the map level
- competitive in local moments
- readable and satisfying moment to moment
- social, a little chaotic, and easy to spectate
- expandable without rewriting the core loop

---

## 2. Core player loop

1. Join a live match.
2. Spawn into the 3D board space.
3. Move to reachable tiles.
4. Target a tile and request a reveal action.
5. Let the server validate claim ownership and damage ticks.
6. Clear tiles to reveal more of the hidden image and unlock neighbors.
7. Enter final rush when the remaining tile threshold is reached.
8. Finish the map and later transition into stronger results/reward presentation.

---

## 3. Locked v1 design direction

## 3.1 Shared progress with personal moments
The board should feel communal, but players still need local moments that feel personal.
Examples for later phases include:
- finishing a contested tile
- claiming a hard-to-reach tile first
- standing out visually through role/tool/charm identity
- earning memorable drops or end-of-map recognition

## 3.2 Roles are style identities first
The intended v1 role set is still:
- **Archaeologist**
- **Hacker**
- **Groundkeeper**
- **Scavenger**

These remain the target design direction, but they are **not implemented as authored role data in the current repo yet**.

## 3.3 Tile families are broad presentation buckets first
The intended broad family set is still:
- **Relic**
- **Glitch**
- **Overgrowth**
- **Scrap**

In the current repo, only a smaller authored slice is present to prove the framework.
The design target remains larger than the current authored content set.

## 3.4 Equipment scope remains intentionally narrow
The first real equipment scope remains:
- **Tool**
- **Charm**

Consumables stay in regular inventory rather than becoming extra equipped slots.
This is still design direction only; the inventory/equipment layer is not implemented yet.

## 3.5 Claims remain lightweight and time-based
A tile becomes effectively claimed when a player damages it.
If that player stops damaging the tile for the configured timeout window, the claim expires.
During final rush, claims are removed so the map can finish faster.

This rule is already reflected in the current gameplay runtime.

## 3.6 Scope exclusions remain the same
Do not design current implementation around:
- monetization
- ads
- crafting

Those remain intentionally out of scope.

---

## 4. Current authored content in the repo

This section describes the repo as it exists today, not the broader future plan.

### Map presets currently authored
- `map_preset.sandbox_64`

### Tile families currently authored
- `tile_family.overgrowth`
- `tile_family.scrap`

### Tile variants currently authored
- `tile_variant.overgrowth_patch`
- `tile_variant.scrap_plate`

### Current visual approach
- board layout is driven by logical grid data
- reveal texture is shown as an underlay beneath cleared tiles
- tile variants reference `PackedScene` visuals through `TileVariantDef`
- current placeholder visuals are scene-authored cube-based tiles sized to the board tile footprint

### Current board presentation implications
The board already supports swapping placeholder visuals for authored assets through data-backed tile variant scene references.
That means later art replacement should happen by changing content assets and scenes, not by redesigning gameplay truth.

---

## 5. Design implications of the current implementation

## 5.1 The core loop is now real enough to guide design
The project has passed the stage where design is purely theoretical.
Server ownership, reveal flow, final rush, and hidden-image payoff now exist in playable form.

## 5.2 Readable targeting polish can wait until the asset pass
Because tile visuals are still placeholder-driven and will change again with stronger art, highly polished target readability should be treated as a later presentation pass unless it blocks usability.

## 5.3 Future content should plug into the existing board loop
The next design-heavy work should extend the current loop through:
- more authored tile families/variants
- role presentation and eventual role-backed item identity
- tools/charms/inventory
- results/reward layers

It should not replace the current authoritative board model.

---

## 6. Recommended next design-sensitive priorities

1. Finish the remaining data-authored content framework, especially roles, behaviors, and tuning resources.
2. Add the first item/equipment backbone for Tool and Charm.
3. Add map-complete presentation, contribution stats, and results flow.
4. Expand the authored family/variant roster after the framework is ready.

---

## 7. Summary

The current repo already expresses the intended heart of RevealTogether:
- shared board progress
- authoritative tile clearing
- gradual hidden-image reveal
- 3D multiplayer presence

What is missing now is not the gameplay heart.
What is missing is the next layer of **content framework, item framework, and match-completion presentation**.
