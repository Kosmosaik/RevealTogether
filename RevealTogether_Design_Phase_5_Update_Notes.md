# RevealTogether - Design Update Notes for Phase 5

These notes are intended to be merged into `docs/RevealTogether_Design.md` before or during Phase 5.

## Restored original design intent

RevealTogether is an online multiplayer game where players clear a large field of tiles to reveal a hidden image beneath the map.

The intended feel remains:

- cooperative at the global level,
- competitive at the local level,
- readable and satisfying moment to moment,
- funny, social, and a little chaotic,
- rewarding for both active and relaxed playstyles.

The core loop remains:

1. Join a live map.
2. Move through the 3D space to available tiles.
3. Claim a tile by damaging it.
4. Keep damaging it until it clears.
5. Gain progress and future rewards.
6. Unlock pressure on surrounding tiles.
7. Continue as the hidden image becomes visible.
8. Enter late-game rush when few tiles remain.
9. Finish the map and view reveal/results later.

## Roles and tool-driven role identity

The first four role identities remain:

- Archaeologist
- Hacker
- Groundkeeper
- Scavenger

However, the player's current role should now be derived from the equipped Tool rather than being a separate fixed class choice.

Examples:

- Equipping an Archaeologist Tool makes the player function as Archaeologist.
- Equipping a Hacker Tool makes the player function as Hacker.
- Equipping a Groundkeeper Tool makes the player function as Groundkeeper.
- Equipping a Scavenger Tool makes the player function as Scavenger.

This lets players switch roles during a map by changing Tool, which supports flexible multiplayer coverage when certain tile types remain.

Roles remain style/theme/progression identities, not rigid class kits in the first version.

## Tile families

The intended first four tile-family themes remain:

- Relic
- Glitch
- Overgrowth
- Scrap

The current repo may only contain a subset of these as authored content. Implementation should not hardcode missing content.

Tile families remain visual/style/content buckets first, with room for future behavior differences.

The project should preserve the distinction between:

- Family: broad style category.
- Variant: specific authored tile type inside a family.
- Behavior: how the tile is interacted with.
- State: runtime condition such as locked, unlocked, claimed, cleared.

## Equipment

The first version should only have:

- Tool
- Charm

Consumables and materials belong in normal inventory, not equipment slots.

## Tools

Tools are the main numerical power carrier.

In Phase 5, equipped Tool should control:

- current role identity,
- eligible tile families,
- base damage,
- attack interval / attack speed,
- crit chance,
- crit multiplier.

Tools are intended to become procedural and collectible later. Phase 5 should support rolled runtime stats through item instances, but does not need a full procedural loot system yet.

## Charms

Charms are expressive utility/flavor items, not another weapon slot.

They may later have active and passive effects, but Phase 5 should only scaffold equip/ownership/replication. Charm effects can be data-driven later through `effect_id` plus parameters.

## Role skills later

Future direction:

- damaging tiles with a Tool can increase skill/progression in that Tool's role,
- players may specialize in one role or generalize across multiple roles,
- role skill can later affect damage, efficiency, drops, or utility.

Do not implement the full role-skill system in Phase 5 unless explicitly expanded.

## Drops later

Drops are not part of Phase 5.

Future intended behavior:

- tile drops appear in the world,
- drops are private to one player for a configured time,
- then they become free-for-all,
- pickup requires proximity and explicit interaction,
- player must have inventory space,
- tooltip/UI should show what the ground item is.

## Scope exclusions still active

Do not build current implementation around:

- monetization,
- ad systems,
- crafting,
- full economy,
- deep role asymmetry,
- permanent account progression,
- final production art pipeline.
