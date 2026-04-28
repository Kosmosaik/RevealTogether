# RevealTogether - Design

## Purpose

This document captures the current design truth for the RevealTogether prototype. It reflects the repo state after Phase 4, the Phase 4b quality pass, and the large-board performance work.

## Current prototype status (2026-04-28)

RevealTogether is a cooperative online tile-reveal prototype built in Godot. The current game loop is server-authoritative and playable in the prototype sense:

1. Start a dedicated server.
2. Connect one or more clients.
3. Join the default match.
4. Spawn outside the board boundary.
5. Move around the 3D world with the player controller and orbit camera.
6. Approach unlocked edge tiles.
7. Click/reveal tiles through a server-validated action path.
8. Watch the shared board open inward over time.

The project can now handle much larger boards than the original 64 x 64 sandbox. Large boards use streamed snapshots, compact snapshot data, a cheap full-board MultiMesh presentation layer, capped nearby/detail overlays, progressive client-side visual building, and loading/progress UI.

## Confirmed current design direction

### Shared progress with personal presence

The board is shared. Players have individual world-space presence, replicated avatars, movement, camera control, and later role/tool/charm identity, but the board reveal objective is cooperative.

### Server-owned truth

The server owns match state, board state, player state, tile reveals, claims/damage timing, and authoritative deltas. Client scenes and visual nodes present state only.

### Full-board visibility is preferred

Large boards should still communicate scale. The current direction avoids classic proximity chunk loading that hides distant board areas. Chunking is used for generation, organization, streaming, batching, and future dirty-state work, not for making the rest of the board disappear.

### Roles are style identities first

The current roles remain broad style/theme identities rather than hard asymmetric classes. The first four roles are:

- `role.archaeologist`
- `role.groundkeeper`
- `role.hacker`
- `role.scavenger`

Lumberjack and Mycologist remain possible future separate roles, not current substyles.

### Tile families and variants are presentation/content buckets

Tile families are broad visual/style buckets. Tile variants provide specific authored visual scenes and behavior links. Gameplay truth stays in runtime board records and server services.

### Equipment scope remains intentionally narrow

The early equipment direction remains only:

- Tool
- Charm

Consumables should remain regular inventory content later, not equipment slots.

### Scope exclusions for now

Do not expand the current design into these areas yet:

- monetization
- crafting
- highly asymmetric roles
- complex combat systems
- production art pipelines
- deep progression trees

## Current authored content in the repo

### Map presets

- `map_preset.sandbox_64`

### Tile families

- `tile_family.overgrowth`
- `tile_family.scrap`

### Tile variants

- `tile_variant.overgrowth_patch`
- `tile_variant.scrap_plate`

### Roles

- `role.archaeologist`
- `role.groundkeeper`
- `role.hacker`
- `role.scavenger`

### Spawn layouts

- `spawn_layout.sandbox_outer_perimeter`
- `spawn_layout.sandbox_ring_8`

### Tile behaviors

- `tile_behavior.standard_reveal_clear`

## Current presentation direction

Small boards may still use authored per-tile visual scenes. Large boards use a hybrid approach:

- the full board remains visible through a MultiMesh tile-cover layer,
- detailed authored tile scenes are spawned only for a capped focus/detail set,
- hovered/focused/recently changed tiles can receive detail priority,
- detailed visuals are presentation-only and must not become gameplay truth.

The current lighting/color work is functional and configurable, but final visual polish is still intentionally deferred. Shadows, sky/background, palette, tile detail, and distant board richness are still open art-direction topics.

## Design implications of the current implementation

### The board-opening fantasy is proven

Outside-the-map spawning plus edge-based initial unlocks create the intended feeling of opening the board from the perimeter inward.

### Large-board readability is now a real design concern

Performance now supports much larger maps, so design work should consider how players understand huge boards: region identity, readable tile families, useful detail near the player, and clear loading feedback.

### Placeholder visuals are acceptable but not final

The current visuals are prototype assets. They are good enough for mechanics and scale testing, but they should remain replaceable presentation content.

### Data-driven content remains a core constraint

New gameplay content should be authored through resources/defs/config and loaded/validated through existing systems. Avoid hardcoding new gameplay IDs or tuning values inside runtime scripts.

## Recommended next design-sensitive priorities

1. Finish the large-board presentation foundation enough that huge maps are readable and pleasant to test.
2. Define the minimum Tool and Charm design boundaries before starting Phase 5 inventory/equipment work.
3. Define the first meaningful behavior differences beyond `tile_behavior.standard_reveal_clear`.
4. Define player-facing map completion/results feedback for the later results phase.
5. Decide what large board sizes should be considered supported targets for internal tests.

## Summary

The project is no longer just a foundation prototype. It has a server-authoritative reveal loop, authored content, world-space movement, large-board loading, large-board rendering, and loading/progress feedback. The next design work should either finish the remaining large-board visual polish or move carefully into the first Tool/Charm/inventory gameplay layer.
