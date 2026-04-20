# RevealTogether - Design

## Purpose

This document captures the current product and gameplay design direction for **RevealTogether**.
It focuses on the player-facing design, not low-level code structure.
The goal is to lock the core direction early enough that implementation can start without drifting into temporary systems that later need to be rewritten.

---

## Current prototype status (2026-04-20)

The live project has now validated the multiplayer foundation, but it has **not** started the real board/reveal gameplay loop yet.

### What is already proven
- Dedicated server and client connection flow
- Authoritative session ownership for connected players
- Consistent spawning into the sandbox test world
- Replica-avatar presentation as a multiplayer baseline

### What remains for the design to be expressed in play
- authoritative board state
- tile clearing and reveal progression
- claim timeout behavior
- final-rush transition
- map completion payoff

This means the next design-sensitive implementation work is Phase 2, where the board loop finally becomes playable.

---

## 1. High-level concept

RevealTogether is an online multiplayer game where players clear a large field of tiles to reveal a hidden image beneath the map.

At the start of a map, only part of the board is available. As tiles are cleared, more tiles unlock. Progress is shared at the map level, while players still get local competition, rare moments, drops, and end-of-map recognition.

The intended feel is:

- cooperative at the global level
- competitive at the local level
- readable and satisfying moment to moment
- funny, social, and a little chaotic
- rewarding for both active and more relaxed playstyles

---

## 2. Core player loop

1. Join a live map.
2. Move through the 3D space to available tiles.
3. Claim a tile by damaging it.
4. Keep damaging it until it clears.
5. Gain drops, progress, and unlock pressure on surrounding tiles.
6. Repeat while the hidden image becomes more visible.
7. Enter the late-game rush when few tiles remain.
8. Finish the map and view the reveal, map results, and statistics.

---

## 3. Design pillars

### 3.1 Shared progress with personal moments
The map should feel like a shared objective, but the player should still have personal highlights:

- finding or winning a rare tile
- finishing a difficult tile
- placing on a map leaderboard
- being visible to nearby players
- getting a memorable drop

### 3.2 Roles as style identities, not hard classes
Roles should not feel like rigid asymmetrical classes in v1.
They should primarily give:

- visual identity
- animation identity
- thematic tool pool
- flavor and personality

### 3.3 Tile families as style buckets first
Tile families should mainly define visual and presentation identity in the first version.
They should not create heavy meta or role-lock problems early on.

### 3.4 Readable reveal progression
The hidden image is one of the game’s strongest emotional payoffs.
The map should reveal gradually, not instantly, and not in a way that destroys suspense too early.

### 3.5 Future-proof content hooks
The game should support more varied tile interactions later without needing a redesign of the core systems.

---

## 4. Current locked v1 design decisions

### 4.1 Roles
Start with four core roles:

- **Archaeologist**
- **Hacker**
- **Groundkeeper**
- **Scavenger**

These roles are style and theme packages first.
They are not intended to be sharply unique power classes in the first phase.

### 4.2 Tile families
Start with four main tile families:

- **Relic**
- **Glitch**
- **Overgrowth**
- **Scrap**

In v1, these are mainly visual/style categories with broadly similar gameplay function.

### 4.3 Equipment
Keep only two equipped slots in the first version:

- **Tool**
- **Charm**

Consumables and other drops should live in the normal inventory.

### 4.4 Claims
A tile becomes effectively claimed when a player damages it.
As long as the tile has taken damage recently from that player, other players cannot target or damage it.
If it has not taken damage for the configured timeout window, the claim expires.

During the late-game final rush, all claims are removed.

### 4.5 Scope exclusions for now
Do not build current documentation or implementation around:

- monetization
- ad systems
- crafting

Those are intentionally outside the current phase.

---

## 5. Roles

## 5.1 Archaeologist
**Theme:** excavation, ruins, buried secrets, relic recovery.

**Visual language:**
- brush
- shovel
- chisel
- dust
- runes
- tombs and dig sites

**Goal in v1:**
Give players a careful excavation fantasy and clear presentation identity.

## 5.2 Hacker
**Theme:** corruption cleanup, digital interference, broken systems.

**Visual language:**
- static
- scanlines
- probes
- code-like effects
- glitch distortion
- data spikes

**Goal in v1:**
Provide a strong digital cleanup vibe without turning the role into a hard gameplay specialist yet.

## 5.3 Groundkeeper
**Theme:** overgrowth control, pruning, clearing roots, managing nature gone wild.

**Visual language:**
- shears
- cutters
- roots
- leaves
- spores
- organic cleanup

**Goal in v1:**
Create a fun and readable role with high visual personality.

**Expansion note:**
Lumberjack and Mycologist may later become separate roles rather than substyles, but they are not part of the current core four.

## 5.4 Scavenger
**Theme:** junk, salvage, improvised tools, industrial scrap.

**Visual language:**
- wrench
- crowbar
- sparks
- bolts
- metal plates
- rough salvage work

**Goal in v1:**
Support an industrial, rough-and-ready role fantasy.

---

## 6. Tile families and variants

The project should clearly separate these concepts:

### Family
A broad style category.

Examples:
- Relic
- Glitch
- Overgrowth
- Scrap

### Variant
A specific type of tile inside a family.

Examples:
- Tomb
- Fossil Bed
- Mushroom Patch
- Forest Trunk
- Cable Nest
- Rust Plate
- Corrupt Node

### Behavior
The way the player interacts with a tile while clearing it.

Examples:
- standard surface clearing
- enter-and-exit interaction
- periodic delivery interaction
- multi-stage break

### State
The current runtime condition of the tile.

Examples:
- locked
- unlocked
- claimed
- cleared
- highlighted rare tile

### Important design rule
Most variants can share simple behavior in v1.
The architecture should still leave room for future micro-mechanics.

Example future idea:
A **Tomb** tile variant could let the Archaeologist enter the tomb, deal damage from inside, then emerge occasionally with drops.

That kind of idea should be supported later through tile behavior design, not through one-off hacks.

---

## 7. Equipment direction

## 7.1 Tools
Tools should feel like weapon-like items in other loot games.

Key direction:
- role-specific
- procedural over time
- can roll stat values like crit and other combat-like properties
- main carrier of numerical power profile

Tools should eventually feel collectible and expressive, but the project should not lock itself into rigid tool archetypes too early.

## 7.2 Charms
Charms should feel less like weapons and more like strange, flavorful, expressive items.

Key direction:
- vibey
- utility-oriented
- not primarily raw weapon stats
- room for weird mechanics, map feel, and personality

Detailed charm effect design is intentionally postponed until the technical foundation is built.

---

## 8. Claim and map flow design

## 8.1 Claim behavior
A tile is protected from other players while it has recently been damaged by its owner.

Recommended intent:
- active and idle both count as long as they still apply damage
- inactivity causes the claim to expire
- tile progress never resets because a claim expired

## 8.2 Late-game final rush
When the remaining tile count reaches the configured threshold:

- remove all claims
- open the final stretch to everyone
- increase urgency and competitive tension
- prevent one player from holding the end hostage

## 8.3 End-of-map reveal
The final completion should be a major event.

Desired sequence:
- last tile clears
- camera recenters and reveals the board
- image becomes fully visible
- map results and statistics are shown
- rewards and archive-ready outcome data are generated

---

## 9. Camera and world presentation

The game is a **3D** game, not a 2D one.

Target presentation:
- top-down readability
- limited camera rotation or angle options
- zoom level changes
- no free camera that ruins the image reveal or map clarity

Design intent:
- preserve the drama of uncovering the image
- keep movement and nearby players readable
- let tile interactions feel alive in 3D

---

## 10. Content philosophy

The project should be expandable through content definitions, not through monolithic hardcoded systems.

That means:
- new roles should be addable later
- new tile families and variants should slot into existing frameworks
- richer tile interactions should not require redesigning the board system
- tools and charms should have space to grow later without rewriting the item backbone

---

## 11. What this design is optimizing for

This design is intentionally optimizing for:

- readable shared multiplayer progress
- satisfying map reveal pacing
- clean future expansion
- strong visual identity by role and tile family
- social and funny map moments
- a solid foundation for loot and progression later

It is **not** currently optimizing for:

- deep role asymmetry
- crafting systems
- monetization loops
- highly specialized hard counter gameplay

---

## 12. Immediate next design step

The next practical step after the completed multiplayer foundation is to validate the board/reveal loop in Phase 2.
That work should lock:

- readable tile-state progression
- claim feedback and timeout communication
- reveal-underlay presentation rules
- final-rush readability and urgency cues
- board-scale pacing before deeper item and role layering
