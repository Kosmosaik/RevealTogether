# RevealTogether - Technical Architecture

## Purpose

This document defines the technical direction for **RevealTogether**.
It is focused on architecture, system boundaries, data ownership, and implementation rules.

Primary goals:

- data-driven structure
- modular systems
- clean separation of authority
- easy configurability
- future expansion without throwaway hacks
- no dependence on later full refactors to become maintainable

---

## Current implementation snapshot (2026-04-20)

The current project already has the Phase 0 and Phase 1 foundation in place.

### Implemented foundation
- Config-driven runtime boot through `AppBootstrap` and `RuntimeConfig`
- Centralized structured logging via `LogService`
- Content bootstrap and startup validation via `ContentRegistry` and `StartupValidator`
- Dedicated server and client runtime flows
- Session handshake with explicit hello ack/reject and join snapshot/reject paths
- Server-owned player session state, spawn allocation, despawn cleanup, and basic transform snapshot replication
- Sandbox world and replica avatar presentation used to validate the multiplayer baseline

### Architectural implication
The next work should not expand the networking foundation sideways. The correct next move is to layer the authoritative board runtime on top of the already-working session stack.

---

## 1. Core architecture statement

RevealTogether should be built as a:

**server-authoritative, data-driven, modular 3D online game with a 2D logical grid underneath the world presentation.**

This means:

- gameplay rules run on a logical tile grid
- the world is presented in 3D
- the server owns truth for important state
- clients render and request actions, but do not decide outcomes
- content is defined through data assets and registries rather than scattered hardcoded assumptions

---

## 2. Guiding engineering principles

## 2.1 Server owns truth
The server must be authoritative for:

- tile claims
- damage validation
- tile HP changes
- tile clear events
- unlock propagation
- drop generation
- map progression
- end-of-map results

## 2.2 Scene tree is not the source of truth
Gameplay-critical state should not live only inside scene nodes.
Scene nodes are presentation and interaction views.
The core authoritative state should exist as structured runtime data.

## 2.3 Data first, scripts second
Families, variants, behaviors, roles, map presets, and tuning values should be defined through data where practical.
Scripts should interpret data rather than embed design assumptions everywhere.

## 2.4 Extension points over one-off hacks
If a future feature needs a special case, add a formal extension point instead of patching a random gameplay script.

## 2.5 Stable boundaries early
The project should have clear boundaries from the beginning:

- server simulation
- client presentation
- shared protocol and data definitions
- content resources
- tools and validators

---

## 3. Runtime model

## 3.1 Grid simulation with 3D presentation
The gameplay simulation should run on a logical 2D board.
Each tile has stable grid coordinates.
Those coordinates are projected into a 3D world position for rendering and interaction.

Benefits:
- simple adjacency logic
- clean unlock propagation
- efficient board representation
- easier networking
- easy chunking
- straightforward image reveal mapping

## 3.2 Tile record as authoritative data
A tile should be represented primarily as structured data.

Minimum tile state should include:

- `tile_id`
- `grid_x`
- `grid_y`
- `chunk_id`
- `family_id`
- `variant_id`
- `behavior_id`
- `state`
- `max_hp`
- `current_hp`
- `is_unlocked`
- `is_cleared`
- `claim_owner_id`
- `last_damage_time`
- `special_flags`
- `image_reference` or `uv_reference`

This should be held in authoritative runtime state rather than reconstructed from scene conditions.

---

## 4. Tile content model

The tile system should separate four concepts clearly.

## 4.1 Family
Broad style bucket.

Examples:
- Relic
- Glitch
- Overgrowth
- Scrap

Family definitions should hold:
- display name
- tags
- visual theme references
- VFX palette references
- SFX palette references
- default visual metadata

## 4.2 Variant
Specific tile type inside a family.

Examples:
- Tomb
- Desert Dig Site
- Fossil Bed
- Mushroom Patch
- Forest Trunk
- Cable Nest
- Rust Plate

Variant definitions should hold:
- stable ID
- family link
- display name
- tags
- visual prefab or mesh reference
- default behavior link
- icon or preview references

## 4.3 Behavior
Behavior defines how the tile interacts while being damaged.

Examples:
- standard surface clear
- staged break
- periodic output
- enter-and-exit interaction

Behavior definitions should be runtime-extensible.
A future Tomb interaction should be introduced by adding behavior support, not by hacking a single variant script.

## 4.4 State
Runtime state belongs to the simulation layer.

Examples:
- locked
- unlocked
- claimed
- cleared
- rare-signaled

---

## 5. Networking model

## 5.1 Dedicated server
The game should use a dedicated server model from the start.
Initial internal tests may run from the developer's PC, but the architecture should be written as if deployment to a real host is expected.

## 5.2 Client sends intent
Clients should send requests such as:

- move to position
- target tile
- start action
- stop action
- use item

The client should not send final truth such as:

- tile HP is now X
- tile is cleared
- this claim belongs to me
- I received this drop

## 5.3 Server validates and replicates
The server should validate legality and then replicate the results.

Examples:
- whether a tile is claimable
- whether the tile is already protected by another player's recent damage
- whether the player is in valid range
- how much damage was applied
- whether adjacent tiles unlock
- whether drops should be generated

## 5.4 Recommended networking layers
Split networking responsibilities into clear layers:

### Connection layer
- peer setup
- version checks
- auth/session handshake later if needed
- disconnect handling

### Session layer
- join map
- spawn player
- reconnect rules
- map selection or assignment

### Gameplay replication layer
- tile state deltas
- player transform snapshots
- claim changes
- clear events
- progress updates
- final-rush activation

### UI event layer
- notifications
- result packets
- leaderboard updates
- reveal sequence triggers

---

## 6. Claim ownership model

The current design calls for a simple claim timeout model.

## 6.1 Rule
A tile remains protected from other players while it has been damaged recently enough by its owner.

## 6.2 Required state
At minimum:

- `claim_owner_id`
- `last_damage_time`

## 6.3 Validation logic
When another player attempts to target or damage the tile, the server checks:

- does the tile have an owner?
- has the claim expired?
- is the tile now open?

If the claim has expired, the tile becomes available again.
If not, the request is rejected.

## 6.4 Final-rush override
When the late-game threshold is reached:

- clear all claims
- disable the normal exclusive-claim rule for the remaining stretch

---

## 7. Board and chunk architecture

## 7.1 Why chunking matters
The board can become large quickly.
A naive one-node-per-tile architecture becomes difficult to maintain and optimize as tile counts rise.

Chunking should be used as the main boundary for:

- rendering
- update batching
- visibility
- local rebuild work
- network delta grouping

## 7.2 Recommended board representation
Use either:

- a 2D array with helper indexing, or
- a flat array with deterministic index math

The key requirement is fast lookup for:

- tile by coordinate
- neighbor queries
- chunk membership
- unlock propagation
- clear state checks

## 7.3 Recommended chunk responsibilities
Each chunk should manage or expose:

- tile lookup range
- visual tile presentation container
- refresh hooks for changed tiles
- local visibility lifecycle
- chunk-level update batching

The chunk should not become a mini-authoritative server.
It is a runtime organization unit.

---

## 8. Image reveal architecture

## 8.1 Core idea
The hidden image should exist as an underlayer or mapped reveal surface beneath the tile layer.

Each cleared tile should reveal the corresponding region of the image.

## 8.2 Important implementation rule
Do not couple the image reveal directly to arbitrary scene destruction logic.
The authoritative tile state should decide whether a tile is visually present, hidden, broken, or cleared.

## 8.3 Resolution planning
The project should not assume unlimited image resolution.
Map size and tile count must be chosen intentionally.

Examples:
- 128 x 128 = 16,384 tiles
- 256 x 256 = 65,536 tiles
- 512 x 512 = 262,144 tiles

The architecture should support larger boards later, but early versions should use a controlled map size and chunk structure.

---

## 9. Roles, items, and content data

## 9.1 Roles
Roles should be light in terms of rule complexity but formal in data structure.
A role definition should include at least:

- stable role ID
- display name
- tags
- visual identity references
- animation package references
- allowed tool pool or item rules
- role marker or presentation references

## 9.2 Tools
Tools should be role-specific and carry the main rolled numerical profile.
The technical model should allow:

- stable item IDs
- role restrictions
- rolled stat blocks
- future affixes and procedural generation
- visual model references

Detailed balancing can come later, but the data format should not block it.

## 9.3 Charms
Charms should be lighter and more expressive.
The data format should support:

- stable item IDs
- tags
- effect references
- future utility or flavor triggers

The implementation does not need to fully design charm content yet, but the item backbone should keep the path open.

---

## 10. Camera and movement architecture

## 10.1 Camera goals
The game is 3D but should remain readable.
The camera should support:

- top-down readability
- limited rotation or angle control
- zoom adjustments
- stable reveal-friendly framing

## 10.2 Avoid free camera complexity
The camera should not be fully free if that harms:

- image reveal pacing
- targeting clarity
- map readability
- player fairness

## 10.3 Movement
Player movement can feel free in the 3D world while still respecting grid-based interaction rules.
Range checks, claim checks, and tile targeting logic should all depend on the logical grid and simulation rules, not purely on client-side visual assumptions.

---

## 11. Recommended Godot project structure

```text
res://
  autoload/
    app_config/
    services/
  core/
    events/
    math/
    utils/
  data/
    roles/
    tile_families/
    tile_variants/
    tile_behaviors/
    map_presets/
    items/
    tuning/
  net/
    protocol/
    client/
    server/
  game/
    board/
    chunks/
    players/
    camera/
    items/
    map_flow/
    ui/
  scenes/
    client/
    server/
    shared/
  tests/
  tools/
```

### Folder intent

- `autoload/` for small, explicit global services only
- `data/` for data assets and config
- `net/` for protocol, connection, replication, authority
- `game/` for domain systems
- `scenes/` for scene composition, not core truth
- `tools/` for content validators, importers, inspectors, and debug helpers

---

## 12. Runtime modes

The project should support explicit runtime modes.

At minimum:
- client mode
- dedicated server mode
- local debug mode if useful

Mode should be selected through startup configuration or command-line arguments, not by scene hacks.

---

## 13. Validation and tooling

A data-driven project stays healthy only if invalid data fails early.

Recommended validation rules:

- duplicate IDs fail on startup
- missing references fail on startup
- invalid behavior links fail on startup
- broken map preset references fail on startup
- role/item/family mismatches fail loudly

Useful tools:
- content registry validator
- map preset inspector
- tile distribution preview tool
- ID audit tool
- server state debug viewer

---

## 14. Persistence boundaries

Even if persistence is minimal in early internal tests, the architecture should already distinguish between:

- profile state
- session state
- live map state
- archive/result state

These should not be mixed into one blob.

This prevents future migration pain when the project moves from local testing to more serious hosting.

---

## 15. Guardrails against technical debt

Do not allow the following patterns to become normal:

- client-authoritative shortcuts for gameplay-critical events
- scene-only ownership of tile truth
- random hardcoded tuning values inside gameplay scripts
- role- or family-specific special cases spread across unrelated files
- one-off tile scripts that bypass the shared behavior model
- editor-only assumptions that break dedicated server mode

---

## 16. Immediate technical next step

The next technical step is to implement the authoritative Phase 2 board stack on top of the current session foundation.

That means locking and then building:
- `BoardState` and `TileRecord` as runtime truth
- authored map preset resources and board bootstrap
- chunk partitioning helpers and index math
- board replication DTO boundaries
- claim timeout and final-rush state storage
- the first presentation bridge from authoritative board data into the 3D client world
