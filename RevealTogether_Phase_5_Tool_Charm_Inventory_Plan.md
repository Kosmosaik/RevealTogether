# RevealTogether - Phase 5 Tool, Charm, and Inventory Implementation Plan

**Branch:** `phase-5-tool-charm-inventory`  
**Status:** Not started  
**Assumption:** Phase 4b is intentionally considered finished/deferred and will be committed before this branch starts.  
**Source of truth for implementation:** The latest project zip provided for the implementation step only. Do not trust old zips or memory when writing code.

---

## 1. Purpose

Phase 5 adds the first server-authoritative item, equipment, and inventory backbone for RevealTogether.

The goal is not to build the full loot game yet. The goal is to add the smallest useful framework that can safely support:

- static item definitions,
- runtime item instances,
- Tool and Charm equipment slots,
- a visible inventory/equipment UI,
- test item spawning/granting,
- equipped Tool affecting tile damage,
- role identity being derived from equipped Tool,
- future procedural rolls, drops, skills, persistence, and ground items.

Phase 5 should prove that the project can support item-driven gameplay without mixing runtime truth into visuals or UI.

---

## 2. Core design decisions locked for Phase 5

### 2.1 Equipment slots

The first version has only two equipment slots:

- `Tool`
- `Charm`

No armor, offhand, ring, pet, cosmetic, backpack, relic, or extra equipment slots should be added in Phase 5.

Consumables, materials, resources, and future drops belong in normal inventory, not in equipment slots.

### 2.2 Tool affects tile damage

The equipped Tool must affect tile damage in Phase 5.

The first gameplay version should support:

- base damage,
- attack interval / attack speed,
- crit chance,
- crit multiplier.

The server must be authoritative over damage, cooldown/rhythm, crit rolls, claim checks, tile-family eligibility, and board deltas.

### 2.3 Active hold-to-attack for now

The first interaction model should remain active:

1. Player moves near an eligible tile.
2. Player holds the attack input.
3. Client sends attack intent/request while input is held.
4. Server validates range, tile state, equipped Tool, cooldown, tile-family eligibility, and claim rules.
5. Server applies damage and replicates board deltas.

Later idle-friendly behavior can be added as a separate interaction mode, but Phase 5 should not implement idle auto-attack yet.

### 2.4 Role identity comes from equipped Tool

This is a design change from a static player-selected role model.

A player's current role should be derived from their equipped Tool.

Examples:

- Equipping an Archaeologist Tool makes the player function as Archaeologist.
- Equipping a Hacker Tool makes the player function as Hacker.
- Equipping a Groundkeeper Tool makes the player function as Groundkeeper.
- Equipping a Scavenger Tool makes the player function as Scavenger.

The current role is therefore equipment-driven and can change when the player changes Tool.

This supports flexible map play: if a role/tile type is missing near the end of a map, players can switch tools to help.

### 2.5 Tool controls eligible tile families

A Tool should define which tile families it can damage.

Recommended model:

- `ToolDef.role_id`: the role identity granted by the tool.
- `ToolDef.allowed_tile_family_ids`: the tile families this tool can damage.

This avoids hardcoding role/tile rules into board logic and allows future tuning.

Current authored tile families in the project may not include all four intended design families yet. Phase 5 should only create working test tools for families that exist in the current zip unless new tile-family content is intentionally added.

### 2.6 Role skill progression is design-recorded, not implemented deeply yet

Future direction:

- damaging eligible tiles should eventually increase skill/progression in the Tool's role,
- players can specialize in one role or generalize across multiple roles,
- role skill can later influence damage, efficiency, drops, or other progression.

Phase 5 should not build the full skill/progression system unless explicitly expanded. It may add safe hooks or event data so future role-skill work can consume damage events later.

### 2.7 Charms are equipped but have no real effects yet

Charms are universal in Phase 5.

They may later support active and passive effects, but Phase 5 should focus on:

- definition structure,
- runtime ownership,
- equip/unequip,
- inventory UI,
- replication-safe public summary fields.

Recommended future-proof charm shape:

- `effect_id`,
- `effect_params`,
- active/passive metadata later.

Do not implement complex charm effects in Phase 5.

### 2.8 No drops in Phase 5

Phase 5 should not add real tile drops, ground loot, reward tables, rarity moments, or end-of-map rewards.

Instead, Phase 5 should spawn/grant test items so the inventory/equipment/tool-damage loop can be tested.

Future drop direction to document but not implement now:

- drops appear in the world,
- drops are private to one player for a configured duration,
- after the private window expires, drops become free-for-all,
- pickup requires proximity and explicit interaction,
- player must have inventory space,
- ground item tooltip/UI shows what the item is before pickup.

### 2.9 Session-only runtime inventory with future-safe IDs

Inventory is session-only in Phase 5.

However, the model should be future-safe:

- every item instance should have a unique runtime instance id,
- every item instance should reference a static item definition id,
- rolled stats should live on the runtime item instance,
- rolled stats should persist for the life of the session,
- later persistence can save/load item instances without redesigning the model.

---

## 3. Definitions vs instances

Phase 5 must clearly separate static definitions from runtime item instances.

### 3.1 Static item definitions

A definition is authored content.

Example:

- "Rusty Shears" is a Groundkeeper Tool definition.
- It defines default possible stats, allowed tile families, role identity, display data, and future visual hooks.

Definitions should live under `data/` and be loaded by the content registry/catalog flow.

Definitions are not owned by a player and do not represent a specific copy in an inventory.

### 3.2 Runtime item instances

An item instance is a specific copy owned by a player during a match/session.

Example:

- Player A owns item instance `item_instance.player_3.0001`.
- It references `tool.groundkeeper.rusty_shears`.
- It has rolled damage, crit chance, crit multiplier, and attack interval values.

Runtime item instances are server-owned truth.

This is what allows two players to own the same Tool definition but have different rolls later.

---

## 4. Recommended data/content model

### 4.1 Use shared base item data plus specialized Tool/Charm defs

Recommended structure:

- common item fields for identity, display, stack rules, and public visual hooks,
- specialized Tool fields for damage and tile-family eligibility,
- specialized Charm fields for future charm effects.

Recommended files/directories, subject to audit before implementation:

```text
 data/items/ItemDef.gd
 data/items/tools/ToolDef.gd
 data/items/tools/*.tres
 data/items/charms/CharmDef.gd
 data/items/charms/*.tres
```

Recommended item kinds:

```text
tool
charm
consumable
material
resource
```

Only `tool` and `charm` need to be functional in Phase 5.

### 4.2 Common item definition fields

Suggested static fields:

```text
id
item_kind
display_name
description
rarity_id or rarity_rank
max_stack
is_equippable
public_visual_id
icon_texture_path or icon_texture
```

Notes:

- Tools and Charms should have `max_stack = 1`.
- Future consumables/materials can use `max_stack > 1`.
- `public_visual_id` should be safe to replicate to other players.
- Internal stats should not be replicated to other players unless intentionally public.

### 4.3 Tool definition fields

Suggested fields:

```text
role_id
allowed_tile_family_ids
base_damage_min
base_damage_max
attack_interval_seconds_min
attack_interval_seconds_max
crit_chance_min
crit_chance_max
crit_multiplier_min
crit_multiplier_max
```

For Phase 5, deterministic authored test items may use equal min/max values until procedural item rolls are expanded.

### 4.4 Charm definition fields

Suggested fields:

```text
allowed_role_ids or empty for universal
effect_id
effect_params
```

For Phase 5, charms can equip successfully but should have no gameplay effect.

---

## 5. Runtime state model

### 5.1 Inventory item instance

Suggested runtime fields:

```text
instance_id
item_def_id
item_kind
quantity
rolled_stats
created_source
created_tick_or_timestamp
```

Rules:

- Tool and Charm item instances always have `quantity = 1`.
- Stackable items later can use `quantity > 1`.
- Rolled stats belong here, not only in the definition.

### 5.2 Player inventory state

Suggested runtime fields:

```text
player_id
item_instances_by_id
slot_limit or capacity
```

The owner receives the full inventory state. Other players do not.

### 5.3 Player equipment state

Suggested runtime fields:

```text
player_id
equipped_tool_instance_id
equipped_charm_instance_id
current_role_id
public_tool_visual_id
public_charm_visual_id
```

`current_role_id` should be derived from the equipped Tool and not separately edited by the client.

### 5.4 Public equipment summary

Other players should receive only public equipment presentation data.

Suggested public fields:

```text
player_id
current_role_id
public_tool_visual_id
public_charm_visual_id
```

For now, visuals may still be placeholders. The structure should exist so later avatar/tool/charm visuals can be swapped in without redesigning replication.

---

## 6. Server-authoritative equip rules

Client may request:

- equip item,
- unequip item,
- inspect inventory,
- optionally move/reorder inventory later.

Server validates:

- player exists,
- player owns item instance,
- item definition exists,
- item kind is valid for requested slot,
- item is not already equipped in an invalid way,
- future station/range restriction if enabled,
- future cooldown if enabled.

For Phase 5, equipment changes can be allowed from the visible UI/debug UI.

Future direction:

- player may need to go to a station near the ground edge/outside the map to change role/equipment.

Implementation should leave a clear hook such as `can_change_equipment(...)` so station restrictions can be added later without rewriting the equipment service.

---

## 7. Tool damage / attack rules

### 7.1 Validation path

When a client attacks a tile, the server should validate:

1. player exists,
2. player has an equipped Tool,
3. target tile exists,
4. target tile is unlocked and not cleared,
5. target tile family is allowed by equipped Tool,
6. player is in valid range,
7. claim rules allow damage,
8. player is not attacking faster than the equipped Tool allows,
9. crit is rolled server-side,
10. damage is applied server-side,
11. board deltas are replicated.

### 7.2 Damage calculation

Suggested Phase 5 calculation:

```text
base_damage = rolled_stats.base_damage
is_crit = server_rng_roll < rolled_stats.crit_chance
final_damage = base_damage * rolled_stats.crit_multiplier if crit else base_damage
```

For the first version, crit multiplier can default to `2.0`.

### 7.3 Attack rhythm

"Rhythm" means the Tool controls how often the server allows successful damage events.

For example:

```text
attack_interval_seconds = 0.65
```

The client may send attack intent while the mouse button is held, but the server should throttle successful damage using the equipped Tool's interval.

---

## 8. Networking and replication

### 8.1 Use separate inventory/equipment payloads

Inventory/equipment should not be bundled into the large board snapshot.

Reason:

- board snapshots can be huge and streamed,
- inventory/equipment is player-specific and much smaller,
- owner/private state and public state have different visibility rules.

### 8.2 Snapshot plus deltas

Recommended approach:

- send full owner inventory/equipment snapshot on join or when needed,
- send small owner deltas after changes,
- send public equipment summary on player spawn/join,
- send public equipment update when a player changes Tool/Charm.

This is better than only full snapshots or only deltas because it is simpler to recover from missed state while keeping normal changes cheap.

### 8.3 Visibility rules

Owner receives:

```text
full inventory
full equipment
item names/descriptions/stats/rolled values
```

Other players receive:

```text
player_id
current_role_id
public_tool_visual_id
public_charm_visual_id
```

Other players should not receive full inventory, rolled stats, private item names, or item quantities unless intentionally made public later.

---

## 9. UI scope

Phase 5 should add a simple visible inventory/equipment UI.

Minimum owner UI:

- current Tool slot,
- current Charm slot,
- inventory list,
- visible item names/stats for owned items,
- equip/unequip action buttons,
- basic feedback when equip fails.

Presentation rules:

- UI does not own gameplay truth,
- UI sends requests,
- server validates,
- UI updates from replicated authoritative state.

The UI can be simple and functional. No polished drag/drop, comparison panels, rarity animations, item tooltips, or advanced sorting are required yet.

---

## 10. Test item spawning/granting

Because drops are not part of Phase 5, test items are needed.

Recommended approach:

- grant a small set of test Tool and Charm instances when a player joins the match,
- make this controlled by config or a debug/test grant service,
- ensure granted items use the same runtime item instance path as future drops/rewards.

Initial useful test items should match content currently present in the project.

For example, if only Overgrowth and Scrap tile families exist in the audited zip, create/test:

- a Groundkeeper Tool that can damage Overgrowth tiles,
- a Scavenger Tool that can damage Scrap tiles,
- a no-effect test Charm.

Do not hardcode missing Relic/Glitch content unless those tile families are added intentionally in the same phase.

---

## 11. Documentation updates required before/with implementation

### 11.1 Design document

Update the design doc to restore and preserve:

- high-level original game concept,
- cooperative global progress with local personal moments,
- four intended core roles: Archaeologist, Hacker, Groundkeeper, Scavenger,
- tile families: Relic, Glitch, Overgrowth, Scrap,
- family / variant / behavior / state separation,
- equipment limited to Tool and Charm,
- role identity now derived from equipped Tool,
- Tool controls eligible tile families,
- tools are the main numerical power carrier,
- charms are expressive utility/flavor items,
- no monetization/crafting in current scope.

### 11.2 Technical architecture document

Update architecture docs to include:

- static item definitions,
- runtime item instances,
- player inventory state,
- player equipment state,
- owner/private vs public equipment replication,
- server-authoritative tool damage path,
- future station-based equipment change hook.

### 11.3 Main implementation plan

Update the main implementation plan so Phase 5 is no longer a generic placeholder. It should reference this Phase 5 plan and mark Phase 4b as intentionally finished/deferred.

---

## 12. Work order

### Phase 5.0 - Branch and documentation setup

1. Commit and push Phase 4b.
2. Create `phase-5-tool-charm-inventory` branch.
3. Add this Phase 5 plan document.
4. Update the design document with restored original design intent and new tool-driven role model.
5. Update implementation/architecture docs with the Phase 5 direction.

### Phase 5.1 - Audit current content and action path

Before writing code, audit:

- current role defs,
- current tile family defs,
- current tile variant defs,
- current board action service,
- current player state,
- current match session service,
- current network DTO/protocol files,
- current client world input flow,
- current UI scene structure.

List exact files, functions, properties, signals, Dictionary keys, node paths, and insertion anchors before implementation.

### Phase 5.2 - Add item definition resources and catalog

Add static definition support for:

- Item base/shared data,
- Tool defs,
- Charm defs,
- initial test Tool/Charm resources,
- startup validation for required fields and referenced role/tile-family ids.

### Phase 5.3 - Add runtime inventory/equipment state

Add server-owned runtime state for:

- item instances,
- player inventory,
- player equipment,
- derived current role from equipped Tool,
- public equipment summary.

### Phase 5.4 - Add test item grants

Grant test items to players on join through a debug/test path.

The grants should create real runtime item instances so later drops/rewards can reuse the same path.

### Phase 5.5 - Add equip/unequip request flow

Add client request and server validation for:

- equip Tool,
- equip Charm,
- unequip Tool/Charm if allowed,
- equipment-changed replication.

Equipment changes may be allowed anywhere in Phase 5, but code should have a clear hook for future station restrictions.

### Phase 5.6 - Add inventory/equipment UI

Add simple visible UI showing:

- inventory items,
- equipped Tool,
- equipped Charm,
- item stats,
- equip/unequip controls,
- basic error/status feedback.

UI must remain presentation-only.

### Phase 5.7 - Integrate equipped Tool into tile damage

Modify the attack/reveal path so:

- player must have an equipped Tool,
- Tool allowed tile families are checked,
- damage uses rolled Tool stats,
- attack interval is enforced server-side,
- crit is rolled server-side,
- tile deltas still flow through the existing authoritative board path.

### Phase 5.8 - Public equipment summary for other players

Replicate public equipment presentation fields for other players.

Do not implement final tool/charm visuals unless explicitly chosen. The goal is the data path and future visual hook.

### Phase 5.9 - Manual test pass

Required tests:

- server starts without validation errors,
- client joins and receives test inventory,
- inventory/equipment UI appears,
- Tool can be equipped,
- Charm can be equipped,
- equipped Tool changes derived current role,
- Tool can damage allowed tile family,
- Tool cannot damage disallowed tile family,
- attack interval prevents too-fast damage,
- crit can occur server-side,
- board deltas still update correctly,
- second client sees only public equipment summary/visual hooks,
- large-board loading still works,
- no inventory/equipment state is treated as board truth or visual truth.

---

## 13. Explicit non-goals for Phase 5

Do not implement:

- real drops,
- ground item pickups,
- loot tables,
- rarity moments,
- shops,
- trading,
- crafting,
- account persistence,
- end-of-map rewards,
- role skill progression math,
- polished item comparison UI,
- drag/drop inventory,
- final tool/charm 3D visuals,
- idle auto-attack mode,
- station-based equipment restriction unless explicitly pulled into scope.

---

## 14. Open decisions for later phases

These are intentionally not blockers for Phase 5:

- exact station design for changing equipment near the board edge,
- idle-friendly auto-attack mode,
- role skill progression formula,
- drop privacy duration,
- ground item tooltip design,
- inventory capacity rules,
- rarity tiers and color language,
- procedural loot roll ranges and affix system,
- persistence/account save format,
- charm active/passive effect architecture details.

---

## 15. Phase 5 completion definition

Phase 5 is complete when:

1. players receive test item instances on join,
2. players can view inventory/equipment in a simple UI,
3. players can equip a Tool and Charm through server-validated flow,
4. equipped Tool derives current role,
5. equipped Tool determines which tile families the player can damage,
6. equipped Tool controls damage, attack interval, and crit,
7. other clients receive only public equipment summary/visual hooks,
8. all new item/equipment state is server-owned,
9. documentation reflects the new tool-driven role model,
10. existing board, claim, loading, and large-board behavior still works.
