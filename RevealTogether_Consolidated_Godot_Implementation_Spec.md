# RevealTogether - Consolidated Godot Implementation Specification

## Purpose

This document merges and expands the current RevealTogether design, technical architecture, and implementation plan into one executable implementation specification.

Its job is to close the gap between:
- high-level product direction
- technical architecture goals
- actual Godot implementation decisions

This document is intentionally:
- future-proof
- data-driven
- configurable
- modular
- server-authoritative
- written to reduce refactors later

It is not a replacement for the original design, architecture, and implementation documents.
It is the bridge between them and production code.

---

## Current implementation snapshot (2026-04-20)

The current repo has completed the foundation work described by Phase 0 and Phase 1.

### Confirmed in the current project
- config-driven startup and runtime mode resolution
- `AppBootstrap`, `RuntimeConfig`, `LogService`, and `ContentRegistry` autoload foundation
- startup validation before scene boot
- dedicated server and client bootstrap flows
- explicit hello ack/reject and join snapshot/reject session flow
- server-owned player spawn/despawn handling
- basic server-driven player transform snapshot replication
- sandbox world and replica-avatar presentation used to validate the multiplayer baseline

### Not started yet
- authoritative `BoardState` / `TileRecord` gameplay runtime
- tile claims, clear progress, unlock propagation, and final-rush gameplay
- board/chunk replication and reveal-underlay gameplay presentation
- item/content resource implementation beyond the empty authored folder structure

This means the spec is still valid, but the **active next build target is Phase 2** rather than more startup or connection work.

---

# 1. Executive summary

RevealTogether should be built in **Godot 4.x** as a **dedicated-server-first, server-authoritative multiplayer game** with:

- a logical 2D grid for gameplay truth
- a 3D top-down world presentation
- data-authored content definitions
- strict runtime ownership boundaries
- low coupling between simulation and presentation
- chunk-aware board rendering and replication
- configuration-driven tuning
- validation and tooling from the start

The best implementation strategy is:

1. lock runtime contracts first
2. build the startup/bootstrap path second
3. prove the dedicated server loop third
4. implement board simulation before deep content
5. keep rendering, items, and polish plugged into established frameworks

The project should never depend on:
- tile scene nodes as truth
- client-authoritative shortcuts
- hardcoded content references in gameplay logic
- giant prototype scenes that later need full surgery
- random tuning values hidden inside gameplay scripts

---

# 2. Locked implementation principles

## 2.1 Authority

The server is authoritative for:
- match/session ownership
- player presence in a match
- tile claims
- action validation
- damage ticks
- tile HP
- clear events
- unlock propagation
- drop generation
- map progress
- final-rush transition
- results
- archive output

The client is responsible for:
- input
- local camera
- local prediction only where explicitly safe
- presentation
- VFX/SFX playback based on replicated state
- UI

The client may request actions.
The client may never declare final state.

## 2.2 Separation of simulation and presentation

Gameplay truth must live in structured runtime data.
Scene nodes are views, input surfaces, and composition helpers.

### Rule
A node being visible, hidden, destroyed, loaded, or unloaded must never be the only source of gameplay truth.

## 2.3 Data-first content

The following must be content-authored, not hardcoded into gameplay scripts:
- roles
- tile families
- tile variants
- tile behaviors
- map presets
- items
- tuning sets
- VFX/SFX palette references
- progression thresholds

## 2.4 Extension-point rule

When a future feature needs a special rule, implement it through:
- a behavior interface
- a data tag
- a formal effect hook
- a clean subsystem boundary

Do not patch one-off logic into arbitrary scripts.

## 2.5 Configurability rule

Anything likely to be tuned should live in:
- content resources
- runtime config files
- centralized tuning resources

Not inside random methods.

---

# 3. Recommended Godot project structure

```text
res://
  autoload/
    app/
      AppBootstrap.gd
      RuntimeConfig.gd
      LogService.gd
      ContentRegistry.gd
      DebugFlags.gd
  core/
    ids/
    math/
    utils/
    events/
    validation/
  config/
    defaults/
      server.cfg
      client.cfg
  data/
    roles/
    tile_families/
    tile_variants/
    tile_behaviors/
    map_presets/
    items/
      tools/
      charms/
    tuning/
    fx/
  game/
    runtime/
      match/
      board/
      chunks/
      players/
      items/
      results/
    simulation/
      actions/
      rules/
      drops/
      progression/
    presentation/
      board/
      chunks/
      tiles/
      players/
      camera/
      ui/
      fx/
    services/
  net/
    protocol/
    client/
    server/
    replication/
  scenes/
    bootstrap/
    client/
    server/
    shared/
    ui/
  tests/
    unit/
    integration/
    soak/
  tools/
    validators/
    inspectors/
    debug_views/
    importers/
```

## 3.1 Folder intent

### `autoload/`
Only small, explicit global services.
No large gameplay systems should become hidden singletons.

### `core/`
Pure utilities and shared foundations.
No game-specific logic that belongs to simulation domains.

### `config/`
External runtime config for:
- ports
- addresses
- startup modes
- debug flags
- test behavior
- replication rates
- logging levels

### `data/`
All authored content definitions.

### `game/runtime/`
Authoritative in-memory state models and runtime containers.

### `game/simulation/`
Rules and logic that mutate runtime state.

### `game/presentation/`
Render and UX concerns only.

### `net/`
Protocol definitions, connection handling, replication code.

### `scenes/`
Scene composition and wiring only.

### `tests/`
Automated test coverage and internal verification content.

### `tools/`
Validators, editors, inspectors, and debug tooling.

---

# 4. Runtime modes and startup model

## 4.1 Required runtime modes

The project should support three explicit startup modes:

1. `client`
2. `dedicated_server`
3. `local_debug`

These must be selected through:
- command-line args
- launch configuration
- config file override

Not by manually opening different scenes in editor as a permanent workflow.

## 4.2 Recommended startup arguments

Recommended arguments:
- `--mode=client`
- `--mode=server`
- `--mode=local_debug`
- `--config=res://config/defaults/server.cfg`
- `--map_preset=alpha_64`
- `--log_level=debug`
- `--port=7777`

## 4.3 Bootstrap flow

### App bootstrap order
1. parse startup args
2. load runtime config
3. initialize logging
4. initialize debug flags
5. load content registry
6. run startup validation
7. start requested runtime mode
8. route to bootstrap scene/service
9. begin connection or host loop

## 4.4 Recommended bootstrap scenes

```text
scenes/bootstrap/
  ClientBootstrap.tscn
  DedicatedServerBootstrap.tscn
  LocalDebugBootstrap.tscn
```

These scenes should stay thin.
They should delegate to services, not contain game logic.

---

# 5. Autoload list

Use a minimal but deliberate autoload set.

## 5.1 `AppBootstrap`
Responsibilities:
- parse launch settings
- select runtime mode
- route startup flow

## 5.2 `RuntimeConfig`
Responsibilities:
- expose loaded config values
- merge defaults + overrides
- provide typed getters
- expose environment flags

## 5.3 `LogService`
Responsibilities:
- structured logging
- channel-based logging
- runtime log level control
- file output support for dedicated server later

## 5.4 `ContentRegistry`
Responsibilities:
- load all content resources
- register by stable ID
- validate cross-references
- expose typed lookup methods

## 5.5 `DebugFlags`
Responsibilities:
- expose debug toggles
- support overlays and debug-only tooling
- allow runtime-safe toggles in local debug mode

## 5.6 Avoid adding autoloads for
- board truth
- match simulation
- player runtime state
- inventory ownership
- camera control
- UI coordination

Those belong to domain services or match-owned runtime objects, not global singletons.

---

# 6. Content authoring strategy

## 6.1 Best authoring format

Use **Godot Resources (`.tres` / `.res`)** for authored game content.

Reason:
- editor-friendly
- typed
- inspectable
- easy to validate
- referenceable in inspector
- good for content iteration

Use external config files (`.cfg` or `.json`) for:
- runtime/server ops settings
- environment overrides
- test launch profiles

## 6.2 Stable ID rule

Every content definition must include:
- `id: StringName`
- `display_name: String`
- optional `tags: PackedStringArray`
- optional `schema_version: int`

IDs must be:
- stable
- unique
- human-readable
- never derived from file path alone

Recommended ID examples:
- `role.archaeologist`
- `tile_family.relic`
- `tile_variant.relic.tomb`
- `tile_behavior.standard_surface`
- `map_preset.alpha_64`
- `item.tool.arch.brush_01`
- `item.charm.echo_lens`

## 6.3 Content validation rules

Validation must fail loudly for:
- duplicate IDs
- missing references
- invalid behavior links
- mismatched family/variant links
- role restrictions pointing to unknown roles
- map presets referencing unknown variants
- invalid chunk size against board dimensions
- invalid image mapping values
- empty loot tables where required
- invalid schema version

---

# 7. Core data model contracts

The project needs a strict distinction between:
- authored content definitions
- runtime authoritative state
- network payload DTOs
- presentation view models

Never treat one as the other.

## 7.1 Authored content base class

Recommended base resource:

```gdscript
class_name GameContentDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var tags: PackedStringArray = []
@export var schema_version: int = 1
```

Subclasses inherit from this base.

## 7.2 Role definition

```gdscript
class_name RoleDef
extends GameContentDef

@export var visual_profile_id: StringName
@export var animation_profile_id: StringName
@export var starter_tool_pool: Array[StringName]
@export var starter_charm_pool: Array[StringName]
@export var allowed_tool_tags: PackedStringArray
@export var allowed_charm_tags: PackedStringArray
@export var role_marker_scene: PackedScene
```

### Implementation direction
Roles are style/theme packages first.
Do not encode heavy asymmetric logic into the role type.

## 7.3 Tile family definition

```gdscript
class_name TileFamilyDef
extends GameContentDef

@export var visual_theme_id: StringName
@export var vfx_palette_id: StringName
@export var sfx_palette_id: StringName
@export var rarity_weight: float = 1.0
@export var default_material_profile_id: StringName
```

## 7.4 Tile variant definition

```gdscript
class_name TileVariantDef
extends GameContentDef

@export var family_id: StringName
@export var default_behavior_id: StringName
@export var visual_scene: PackedScene
@export var icon: Texture2D
@export var base_hp_min: int = 1
@export var base_hp_max: int = 1
@export var clear_drop_table_id: StringName
@export var rare_signal_profile_id: StringName
@export var visual_tags: PackedStringArray
```

## 7.5 Tile behavior definition

Do not make the behavior itself just raw data if it needs code execution.
Use a hybrid model:

- behavior definition resource for authoring
- behavior handler registry for executable code

```gdscript
class_name TileBehaviorDef
extends GameContentDef

@export var handler_id: StringName
@export var config: Dictionary = {}
@export var supports_channel_action: bool = true
@export var supports_interaction_entry: bool = false
@export var supports_stages: bool = false
```

### Recommended behavior architecture
- `TileBehaviorDef` is content data
- `ITileBehaviorHandler` is simulation code
- `handler_id` maps content to code
- the board simulation asks the handler to evaluate behavior-specific steps

This is the correct extension point for future tomb/cable nest/multi-stage behaviors.

## 7.6 Map preset definition

```gdscript
class_name MapPresetDef
extends GameContentDef

@export var board_width: int = 64
@export var board_height: int = 64
@export var chunk_width: int = 16
@export var chunk_height: int = 16
@export var start_unlock_seed_count: int = 4
@export var final_rush_remaining_tiles_threshold: int = 50
@export var reveal_image: Texture2D
@export var reveal_mapping_mode: StringName = &"full_board_uv"
@export var family_distribution_table_id: StringName
@export var variant_distribution_table_id: StringName
@export var rare_tile_chance: float = 0.02
@export var spawn_layout_id: StringName
@export var milestone_set_id: StringName
@export var tuning_profile_id: StringName
```

## 7.7 Item definition base

```gdscript
class_name ItemDef
extends GameContentDef

@export var item_kind: StringName
@export var rarity_tier: StringName
@export var stack_limit: int = 1
@export var icon: Texture2D
@export var world_scene: PackedScene
```

## 7.8 Tool definition

Keep the first stat vocabulary small but expandable.

```gdscript
class_name ToolDef
extends ItemDef

@export var allowed_role_ids: Array[StringName]
@export var base_damage_per_tick: float = 1.0
@export var base_tick_interval_sec: float = 0.5
@export var base_crit_chance: float = 0.0
@export var base_crit_multiplier: float = 1.5
@export var base_action_range_tiles: int = 1
@export var affix_pool_id: StringName
@export var stat_tags: PackedStringArray
```

## 7.9 Charm definition

Charms should be expressive, not weapon-clones.

```gdscript
class_name CharmDef
extends ItemDef

@export var allowed_role_ids: Array[StringName]
@export var effect_ids: Array[StringName]
@export var trigger_tags: PackedStringArray
@export var cooldown_sec: float = 0.0
@export var max_stacks: int = 1
```

## 7.10 Runtime player profile vs runtime session player

Separate the two.

### `ProfilePlayerData`
Longer-lived account/profile related values.

### `MatchPlayerState`
Live per-match state:
- peer ID
- role ID
- equipped tool instance
- equipped charm instance
- inventory snapshot
- transform
- current targeted tile
- current action state
- contribution stats
- connection state

## 7.11 Runtime tile record

Recommended runtime class:

```gdscript
class_name TileRecord
extends RefCounted

var tile_index: int
var tile_id: int
var grid_x: int
var grid_y: int
var chunk_index: int
var family_id: StringName
var variant_id: StringName
var behavior_id: StringName
var state_flags: int
var max_hp: int
var current_hp: int
var is_unlocked: bool
var is_cleared: bool
var claim_owner_peer_id: int = 0
var claim_expires_at_ms: int = 0
var last_damage_at_ms: int = 0
var rare_signal_state: int = 0
var uv_rect: Rect2
var runtime_tags: PackedStringArray = []
```

### Why this structure
- small enough for v1
- explicit
- easy to serialize
- independent from presentation
- does not require scene nodes

## 7.12 Runtime board state

```gdscript
class_name BoardState
extends RefCounted

var board_width: int
var board_height: int
var chunk_width: int
var chunk_height: int
var tiles: Array[TileRecord]
var remaining_uncleared_tiles: int
var chunk_states: Dictionary
var reveal_image_id: StringName
var final_rush_active: bool = false
var milestone_progress: Dictionary
```

### Recommended tile storage
Use a **flat array** for tiles with deterministic index math.

#### Index formula
`tile_index = grid_y * board_width + grid_x`

This is the best default for:
- simple lookup
- efficient iteration
- straightforward serialization
- easy chunk membership math

## 7.13 Runtime chunk state

```gdscript
class_name ChunkState
extends RefCounted

var chunk_index: int
var chunk_x: int
var chunk_y: int
var tile_indices: PackedInt32Array
var dirty_tile_indices: PackedInt32Array
var has_visual_subscribers: bool = false
```

The chunk is an organization and replication unit.
It is not a source of gameplay authority by itself.

## 7.14 Match state

```gdscript
class_name MatchState
extends RefCounted

var match_id: String
var map_preset_id: StringName
var board_state: BoardState
var players_by_peer_id: Dictionary
var started_at_unix_ms: int
var state: StringName
var total_clears: int = 0
var final_rush_active: bool = false
var result_payload: Dictionary = {}
```

---

# 8. Board and chunk architecture

## 8.1 Recommended board size strategy

Do not start with an oversized map just because the architecture can support it later.

Use two internal presets from the start:

### `map_preset.sandbox_64`
- 64 x 64 board
- 16 x 16 chunks
- 4 unlock seeds
- fast iteration map

### `map_preset.alpha_128`
- 128 x 128 board
- 16 x 16 chunks
- 8 unlock seeds
- main internal multiplayer validation map

This gives:
- a fast debug map
- a more realistic social test map
- stable chunk math
- early scale testing without jumping to huge counts

## 8.2 Chunk size recommendation

Default to **16 x 16** chunks.

Reason:
- clean divisibility for 64 and 128 boards
- manageable tile groups
- good visual refresh unit
- clean replication grouping
- avoids giant per-chunk rebuild cost

Keep chunk size configurable in map presets.

## 8.3 Board generation pipeline

Recommended generation order:
1. load map preset
2. validate dimensions/chunk compatibility
3. create empty board state
4. assign tile families by weighted distribution
5. assign variants by family-compatible weighted distribution
6. assign behavior IDs
7. roll base HP
8. assign rare tile flags
9. assign UV reveal rectangles
10. assign chunk membership
11. seed initial unlocked tiles
12. run integrity validation
13. publish match-ready board snapshot

## 8.4 Neighbor query helpers

BoardState should expose helper methods:
- `get_tile_index(x, y)`
- `is_in_bounds(x, y)`
- `get_tile_by_index(index)`
- `get_tile_by_coord(x, y)`
- `get_neighbors4(index)`
- `get_neighbors8(index)`
- `get_chunk_index_for_coord(x, y)`

These helpers should be central and reused everywhere.
Do not duplicate neighbor math in multiple systems.

---

# 9. Tile state machine

## 9.1 Required tile state concepts

Track these concepts separately:
- locked/unlocked
- uncleared/cleared
- claim ownership
- rare signaled/not signaled
- behavior-local stage state if needed later

Do not collapse all tile meaning into one single string enum if it causes ambiguity.

## 9.2 Recommended tile state model

Use booleans/flags for broad state and reserve behavior-local state for extension handlers.

### Core state
- `is_unlocked`
- `is_cleared`
- `claim_owner_peer_id`
- `claim_expires_at_ms`

### Optional extensible state
- `behavior_runtime_state: Dictionary`

## 9.3 Standard tile lifecycle

1. tile generated locked or unlocked
2. tile becomes targetable when unlocked and not cleared
3. player begins valid action
4. first valid damage tick grants or refreshes claim
5. additional ticks reduce HP
6. HP reaches 0
7. tile is marked cleared by server
8. claim cleared
9. neighbors evaluated for unlock propagation
10. drops/results/progress emitted
11. chunk marked dirty
12. replication packet scheduled

## 9.4 Claim rule

Recommended exact rule:
- a tile becomes claimed only after the **first successful damage tick**
- client hover or pre-target does not claim a tile
- a claim is refreshed each time a successful damage tick lands
- claim expiration is represented as an absolute timestamp on the tile
- claim expiry never resets tile HP

This is simple, deterministic, and hard to misinterpret.

## 9.5 Final-rush rule

When remaining uncleared tiles are less than or equal to the preset threshold:
- set `final_rush_active = true`
- clear all tile claims
- prevent new exclusive claims from being created
- allow any valid player to damage any uncleared unlocked tile

This avoids end-of-map hostage situations cleanly.

## 9.6 Simultaneous action conflict rule

If two players attempt to start actions on the same tile at nearly the same time:
- the first successful server-validated damage tick wins the exclusive claim if final rush is not active
- later attempts are rejected until claim expiry or tile clear
- rejection should return a small reason code for UI feedback

### Recommended reason codes
- `out_of_range`
- `tile_locked`
- `tile_cleared`
- `claimed_by_other`
- `action_not_allowed`
- `match_not_active`

---

# 10. Action system

## 10.1 Recommended v1 action model

Use a **server-ticked channel action model**.

That means:
- player starts action on a tile
- server validates the request
- server applies repeated damage ticks while action remains valid
- action stops on:
  - client stop request
  - out-of-range
  - target invalidation
  - disconnect
  - tile clear
  - match end

This is the cleanest v1 model for claims, pacing, and networking.

## 10.2 Why this is better than ad hoc click damage

It gives:
- deterministic timing
- easier claim refresh
- cleaner tool stat model
- better future charm/tool hooks
- more readable VFX cadence
- simpler multiplayer validation

## 10.3 Action state per player

```gdscript
class_name PlayerActionState
extends RefCounted

var action_kind: StringName = &"none"
var target_tile_index: int = -1
var started_at_ms: int = 0
var next_tick_at_ms: int = 0
var is_active: bool = false
```

## 10.4 Validation path

When client sends `start_tile_action(tile_index)`:
1. confirm match active
2. confirm player exists
3. confirm tile exists
4. confirm tile unlocked
5. confirm tile not cleared
6. confirm player in valid range
7. confirm claim rules allow action
8. create/update action state
9. acknowledge action start if valid

Then server tick loop handles damage ticks.

## 10.5 Tick damage formula

Keep the first formula small and expandable.

Recommended v1:
- base damage from equipped tool
- optional crit roll
- optional charm modifier hooks
- optional tile behavior modifier
- clamp at minimum 1 if a hit is otherwise valid

Do not overdesign combat math early.

---

# 11. Networking model

## 11.1 Transport recommendation

Use Godot's multiplayer API with a dedicated server model.
Keep transport-specific code wrapped behind thin service boundaries so migration later is easier.

## 11.2 Message category split

Split protocol into four categories.

### A. Connection
- hello
- hello_ack
- version_reject
- content_hash_reject
- disconnect_notice

### B. Session
- join_match_request
- join_match_accept
- join_match_reject
- player_spawn
- player_despawn
- reconnect_snapshot

### C. Gameplay
- start_tile_action_request
- stop_tile_action_request
- action_reject
- tile_delta_batch
- claim_delta_batch
- progress_update
- final_rush_started
- drop_grant
- inventory_update

### D. UI / Results
- toast_event
- leaderboard_update
- match_completed
- reveal_sequence_start
- result_payload

## 11.3 Reliable vs unreliable guidance

### Reliable
Use for:
- connection/session control
- action start/stop
- item grants
- match completion
- results
- board deltas that must not be lost if not redundantly included elsewhere

### Unreliable or unreliable ordered
Use for:
- player transform snapshots
- transient visual hints
- nearby player movement replication

Keep this decision centralized in the network layer.

## 11.4 Protocol DTO rule

Never send runtime classes directly.
Use DTO builders/serializers.

Reason:
- cleaner versioning
- easier debugging
- safer field control
- less coupling between runtime objects and wire format

## 11.5 Versioning and compatibility

At connect time validate:
- protocol version
- content hash
- optional build version

Reject mismatches immediately with a human-readable reason.
This avoids bizarre content desync during testing.

---

# 12. Match/session lifecycle

## 12.1 Recommended match states

```text
booting
waiting_for_players
active
final_rush
completing
completed
shutting_down
```

## 12.2 Session lifecycle

1. server boots
2. map preset selected
3. match generated
4. players connect
5. players join session
6. players receive initial snapshot
7. active simulation begins
8. final rush triggers when threshold reached
9. last tile clears
10. completion sequence begins
11. result payload generated
12. archive payload written
13. match resets or server returns to waiting state

## 12.3 Reconnect strategy

Reconnect should be explicitly supported even in early internal builds.

### Reconnect flow
1. reconnecting peer completes version/content validation
2. server identifies or reassigns session player
3. server sends full reconnect snapshot:
   - match state
   - current board progress
   - relevant visible chunk state
   - player state
   - inventory state
   - final-rush status
4. client destroys stale local presentation state
5. client rebuilds from snapshot
6. normal delta flow resumes

## 12.4 Disconnect behavior

On disconnect:
- stop active action
- release transient per-player action state
- do not reset tile HP
- do not clear map progress
- let claims expire naturally unless match rules explicitly remove them

This is the simplest and fairest first implementation.

---

# 13. Replication strategy

## 13.1 Chunk-aware replication

Board deltas should be grouped by chunk where practical.

Recommended replication units:
- tile changed
- chunk dirty batch
- progress event
- match phase event

## 13.2 Snapshot strategy

Support two forms:
- full snapshot
- delta batch

### Full snapshot
Used for:
- first join
- reconnect
- local debug rebuild
- testing tools

### Delta batch
Used for:
- ongoing play
- tile HP updates
- claim updates
- clear events
- unlock events

## 13.3 Dirty tracking

Each chunk should track dirty tile indices.
At replication time:
1. gather dirty tiles by chunk
2. build compact DTOs
3. emit delta batch
4. clear dirty markers once confirmed for send cycle

## 13.4 Recommended tile delta DTO fields

```text
tile_index
current_hp
is_unlocked
is_cleared
claim_owner_peer_id
claim_expires_at_ms
rare_signal_state
behavior_state_patch
```

Keep payloads patch-oriented.
Do not resend the entire tile definition every time.

---

# 14. Presentation architecture

## 14.1 Board presentation rule

The board renderer must consume authoritative board state and render it.
It must not invent gameplay truth.

## 14.2 Chunk presentation layer

Recommended structure:
- `BoardPresenter`
- `ChunkPresenter`
- `TileVisualController`

### Responsibilities
**BoardPresenter**
- manages visible chunk presenters
- routes chunk refreshes
- owns reveal underlay

**ChunkPresenter**
- owns visual objects for one chunk
- batches updates
- manages visibility lifecycle

**TileVisualController**
- updates one tile's visible state
- plays VFX/SFX
- shows target/claim/clear feedback
- never owns authoritative tile logic

## 14.3 Visual performance strategy

Do not begin with a giant freeform one-node-per-tile scene as permanent architecture.

Recommended approach:
- keep the presentation API chunk-based
- allow a simple tile visual implementation for early internal testing
- structure it so a more optimized renderer can replace internals later without touching simulation

This preserves future flexibility without prototype debt.

## 14.4 Reveal underlay implementation

Recommended v1:
- one board-sized reveal plane/mesh under the tile layer
- full hidden image mapped across the board using UVs
- each tile stores or derives its UV rect
- clearing a tile removes or fades its cover visual
- the image itself is never “generated” by tile destruction logic

This is robust, clean, and aligned with server truth.

---

# 15. Camera and 3D presentation spec

## 15.1 Camera goals

The camera must prioritize:
- tile readability
- reveal pacing
- fairness
- nearby player visibility
- target clarity

## 15.2 Recommended v1 camera model

Use:
- top-down angled camera
- limited rotation presets or constrained small rotation band
- zoom in/out within configured min/max
- no fully free camera

## 15.3 Camera config values

Put the following in tuning/config:
- default pitch
- default distance
- zoom min
- zoom max
- rotation step or allowed angle list
- camera smoothing strength
- target framing offset
- final reveal camera path profile

## 15.4 Recommended interaction readability features

Add these from the start:
- tile hover highlight
- locked tile indicator
- claimed-by-other indicator
- active target marker
- clear event burst
- nearby player role marker
- final-rush global signal

These matter more than detailed scenery early on.

---

# 16. Player controller spec

## 16.1 Movement model

Player movement can be free in 3D space, but gameplay interaction is validated against logical grid rules.

Recommended rule:
- movement is world-space
- action legality is server-checked using world position projected against target tile rules

## 16.2 Start with a simple but strict controller

Start with:
- click-to-move or direct movement, whichever you prefer for feel testing
- but keep target validation server-side
- movement replication separated from tile interaction logic
- nearby player interpolation handled client-side only

Do not tie movement code directly into tile simulation code.

## 16.3 Range validation

Use a server-side range check based on:
- player world position
- tile world center derived from grid coord
- configured tool range

Keep this formula centralized in a rules service.

---

# 17. Items, inventory, and grants

## 17.1 Inventory boundary

Inventory is owned by the server.
The client only renders inventory state and sends use/equip requests.

## 17.2 Separate item definition from item instance

### `ItemDef`
Static authored data.

### `ItemInstance`
Runtime granted item with rolled values.

```gdscript
class_name ItemInstance
extends RefCounted

var instance_id: String
var item_def_id: StringName
var rolled_stats: Dictionary = {}
var stack_count: int = 1
var bind_state: StringName = &"match_bound"
```

## 17.3 Minimum v1 equipment model

MatchPlayerState should include:
- `equipped_tool_instance_id`
- `equipped_charm_instance_id`
- `inventory_instance_ids`

Keep the slot model fixed to:
- Tool
- Charm

Do not build extra equipment slot systems yet.

## 17.4 Drop generation

Drops should be generated server-side from:
- tile variant drop table
- rare tile modifiers
- milestone event rewards
- optional player modifiers from charms later

Use drop-table IDs in content data, not hardcoded switch logic.

## 17.5 Minimum v1 stat vocabulary

### Tool stats
- damage_per_tick
- tick_interval_sec
- crit_chance
- crit_multiplier
- action_range_tiles

### Charm effect categories
- passive_stat_modifier
- on_tile_clear
- on_claim_gain
- on_rare_tile_clear
- utility_signal

This is enough for a scalable skeleton without overcommitting to final design.

---

# 18. Progression, results, and archive output

## 18.1 Global match progress

Track:
- uncleared tile count
- cleared tile count
- total progress percent
- milestone triggers
- final-rush active
- completion timestamp

## 18.2 Recommended milestone model

Use milestone definitions in data:
- 25%
- 50%
- 75%
- 90%
- final_rush
- complete

Each milestone can emit:
- UI event
- VFX trigger
- sound event
- server log event
- optional reward hook later

## 18.3 Per-player contribution stats

Recommended first stats package:
- tiles_cleared
- damage_done
- claims_won
- rare_tiles_cleared
- actions_started
- active_time_sec
- final_rush_damage
- drops_received

This is enough for result screens and future archive use.

## 18.4 Result payload structure

```text
match_id
map_preset_id
started_at
completed_at
duration_sec
player_results[]
global_stats
milestones_reached[]
reveal_image_id
archive_version
```

## 18.5 Archive strategy

Even if full persistence is minimal early on, define separate archive payloads.

Recommended archive repositories:
- `MatchArchiveRepository`
- `ProfileRepository` later
- `LiveSessionRepository` in-memory for v1

This keeps persistence boundaries clean from the start.

---

# 19. Tuning system

## 19.1 Tuning rule

All gameplay-tunable values should be centralized and named.
No anonymous magic numbers in simulation scripts.

## 19.2 Tuning categories

Create tuning resources or config groups for:

### Match
- match state timers
- completion delay
- reconnect timeout

### Claims
- claim timeout sec
- final-rush threshold

### Actions
- action validation cooldown
- default tick interval
- invalidation grace thresholds

### Board
- unlock rules
- rare tile chance
- HP roll ranges
- chunk dimensions defaults

### Camera
- pitch
- zoom min/max
- smoothing
- reveal framing

### Replication
- transform send rate
- tile delta send rate
- snapshot throttle
- bandwidth debug caps

## 19.3 Recommended tuning profile structure

Use a `TuningProfileDef` resource referenced by `MapPresetDef`.

This allows different map presets to use different pacing and board values cleanly.

---

# 20. Validation and debug tooling

## 20.1 Startup validation pass

Before runtime mode starts:
- content registry validates
- map presets validate
- protocol version is available
- config values validate
- test launch flags validate

Startup should fail early rather than let bad content leak into runtime.

## 20.2 Required debug tools

### A. Content registry validator
Shows:
- duplicate IDs
- broken references
- load failures
- unused content

### B. Map preset inspector
Shows:
- board dimensions
- chunk layout
- estimated tile counts
- family/variant distribution previews
- rare tile preview stats

### C. Server state viewer
Shows:
- match state
- connected peers
- action states
- claim states
- chunk dirtiness
- final-rush flag

### D. Board overlay debug HUD
Shows:
- chunk bounds
- tile indices
- claim owners
- unlocked/cleared states
- target validation info

## 20.3 Logging channels

Recommended channels:
- `BOOT`
- `CONFIG`
- `CONTENT`
- `NET`
- `MATCH`
- `BOARD`
- `ACTION`
- `DROP`
- `RESULT`
- `DEBUG`

This makes internal testing much easier.

---

# 21. Automated testing strategy

## 21.1 Unit tests

Cover:
- tile index math
- chunk index math
- neighbor queries
- claim validation
- damage formula
- unlock propagation
- final-rush trigger
- content validation helpers

## 21.2 Integration tests

Cover:
- server boot
- client connect
- join match
- start action
- tile clear
- reconnect snapshot rebuild
- match completion

## 21.3 Soak tests

Create soak scripts for:
- many tile clears over time
- repeated reconnect/disconnect
- repeated match resets
- heavy chunk dirtying
- long internal sessions

## 21.4 Determinism principle

Full deterministic lockstep is not required.
But simulation rules should still be deterministic on the authoritative server given the same inputs and timing model.

---

# 22. Security and abuse guardrails

This is not a full anti-cheat system yet, but basic server protections should exist.

## 22.1 Required server sanity checks
- reject impossible action spam
- reject invalid tile indices
- reject impossible range requests
- reject item use without ownership
- reject protocol mismatches
- ignore duplicated stale stop/start requests safely

## 22.2 Rate limiting
Add lightweight request throttling per peer for:
- start action spam
- stop action spam
- join spam
- invalid item use spam

Keep thresholds configurable.

---

# 23. Concrete phase-by-phase implementation plan

This section expands the original phases and adds the recommended best implementation choices.

---

## Phase 0 - Project skeleton and bootstrap

### Goal
Create the permanent project structure, runtime modes, content loading path, and validation foundation.

### Build decisions
- set up final folder structure immediately
- create bootstrap scenes for client/server/local debug
- implement RuntimeConfig and LogService first
- implement ContentRegistry next
- implement startup validation before gameplay logic
- define stable content ID conventions now

### Recommended deliverables
- command-line launch works
- dedicated server mode starts headless
- client mode starts cleanly
- local debug mode can boot a local test session
- bad content fails startup

### Do not do
- no gameplay logic in bootstrap scenes
- no manual scene-jumping as permanent startup architecture
- no loading content ad hoc from random scripts

### Suggested class/file targets
- `autoload/app/AppBootstrap.gd`
- `autoload/app/RuntimeConfig.gd`
- `autoload/app/LogService.gd`
- `autoload/app/ContentRegistry.gd`
- `core/validation/StartupValidator.gd`

---

## Phase 1 - Dedicated server loop

### Goal
Prove real multiplayer structure with authoritative session ownership.

### Build decisions
- implement hello/version/content-hash handshake first
- create join-match request and accept/reject flow
- spawn players into a real MatchState object
- keep transform replication separate from simulation rules
- support disconnect cleanup from day one

### Recommended deliverables
- multiple clients connect to the dedicated server
- session join is authoritative
- players spawn consistently
- transforms replicate
- disconnects stop active actions cleanly

### Suggested message implementation order
1. hello
2. hello_ack / reject
3. join_match_request
4. join_match_accept with initial snapshot
5. player_spawn
6. transform replication
7. player_despawn

### Do not do
- no board logic tied into connection code
- no assuming local testing means local-only authority
- no skipping version/content validation

---

## Phase 2 - Board and reveal core

### Goal
Implement the playable board loop with proper runtime truth.

### Build decisions
- create BoardState and TileRecord first
- use flat tile storage
- implement chunk indexing immediately
- implement unlock seeding through data
- implement server-ticked channel actions
- implement tile clear pipeline and chunk dirtying
- implement reveal underlay as a board-wide image surface
- implement final-rush override as match state, not scattered conditionals

### Recommended deliverables
- full map can be created
- unlocked tiles can be acted on
- claims work
- claim expiry works
- clears work
- neighbors unlock
- progress updates fire
- hidden image reveal works
- final rush triggers and removes claims

### Suggested implementation order
1. BoardState math helpers
2. TileRecord runtime data
3. map preset board generator
4. tile action validation
5. damage tick loop
6. claim refresh/expiry
7. clear event pipeline
8. unlock propagation
9. progress tracking
10. final-rush trigger
11. reveal underlay sync

### Do not do
- no node-destruction-as-truth
- no hardcoded board dimensions in gameplay scripts
- no special-case tile logic inside board core

---

## Phase 3 - 3D controller, targeting, and camera

### Goal
Make the game readable and satisfying in 3D without weakening the architecture.

### Build decisions
- keep camera constrained and configurable
- implement tile targeting indicators before decorative polish
- keep controller logic separate from action validation
- expose world-to-tile projection helpers in a shared presentation/service layer

### Recommended deliverables
- movement feels good
- targeting is clear
- claimed/locked/clearable states are readable
- camera supports zoom and limited rotation
- nearby players are visible without clutter

### Suggested implementation order
1. player controller
2. camera rig
3. world-to-tile selection helper
4. hover/highlight states
5. claimed-by-other feedback
6. final-rush global visual signal
7. first-pass nearby player readability polish

### Do not do
- no free camera that breaks reveal pacing
- no movement rules embedded in tile simulation code
- no decorative world clutter before readability is proven

---

## Phase 4 - Data-driven content framework

### Goal
Move content assumptions fully out of gameplay code.

### Build decisions
- formalize content base classes
- create typed resource definitions for all core content
- create behavior handler registry
- create map preset schema and validation
- build editor/debug tools alongside registry validation

### Recommended deliverables
- roles load from data
- tile families load from data
- tile variants load from data
- behaviors map from data to handlers
- map presets drive board generation
- invalid content fails early

### Suggested implementation order
1. GameContentDef base
2. RoleDef / TileFamilyDef / TileVariantDef
3. TileBehaviorDef + handler registry
4. MapPresetDef
5. tuning profile defs
6. registry validation
7. inspector/debug tools

### Do not do
- no variant behavior hardcoded in random tile visuals
- no file-path-derived identity as a substitute for stable IDs
- no content references hidden inside UI scripts

---

## Phase 5 - Tool, charm, and inventory scaffolding

### Goal
Build the item backbone once, cleanly, without locking final balance too early.

### Build decisions
- separate ItemDef from ItemInstance
- make inventory server-owned
- create basic roll pipeline for granted items
- keep stat vocabulary intentionally small
- add effect hooks but only implement a few categories initially

### Recommended deliverables
- item defs load from data
- item instances can be granted by server
- players can equip Tool and Charm
- tile clears can grant drops
- inventory updates replicate cleanly
- simple charm effects can hook into events

### Suggested implementation order
1. ItemDef base
2. ToolDef / CharmDef
3. ItemInstance runtime model
4. inventory state and ownership
5. drop grant pipeline
6. equip/unequip requests
7. one or two simple charm hooks
8. placeholder UI

### Do not do
- no crafting system bleed
- no giant item taxonomy before the basics work
- no client-side item granting

---

## Phase 6 - Map progression feedback and results

### Goal
Make the match feel complete and socially satisfying.

### Build decisions
- result payload generated server-side
- milestone system data-driven
- final reveal sequence triggered from match completion event
- archive payload separated from UI payload

### Recommended deliverables
- progress milestones fire
- final-rush UI signal works
- completion reveal works
- results screen shows meaningful stats
- archive payload can be stored or reused later

### Suggested implementation order
1. progress tracker
2. milestone definitions
3. final-rush UI events
4. completion event
5. result payload builder
6. reveal sequence integration
7. archive writer skeleton

### Do not do
- no result math on the client
- no unstructured end-of-match blob data
- no tying final reveal to arbitrary camera scripts only

---

## Phase 7 - Internal hardening

### Goal
Prepare the build for serious internal testing and later migration to real hosting.

### Build decisions
- add profiling hooks for board/chunk work
- expand reconnect testing
- add chunk-dirty and delta visibility tools
- verify match reset correctness repeatedly
- make server logs useful for real diagnosis

### Recommended deliverables
- long sessions remain stable
- reconnect is dependable
- chunk update cost is visible
- match reset produces clean state
- migration away from developer PC is operationally straightforward

### Suggested implementation order
1. debug overlays
2. logging improvements
3. reconnect tests
4. repeated reset tests
5. board/chunk profiling
6. protocol abuse checks
7. launch scripts for dedicated server usage

### Do not do
- no polishing-only phase while technical debt remains
- no ignoring desync symptoms because the game “mostly works”

---

# 24. Explicit non-goals for current implementation

The following are intentionally outside the current implementation focus:
- monetization
- ads
- crafting
- deep role asymmetry
- large-scale meta progression
- highly specialized tile micro-mechanics
- production hosting infrastructure optimization beyond sane early boundaries

This protects the core build.

---

# 25. Immediate next coding targets

The best immediate targets now are:

1. `BoardState` and `TileRecord` runtime truth
2. authored map preset resource and board bootstrap pipeline
3. chunk partitioning, index math, and neighbor helpers
4. board snapshot / delta DTO boundaries
5. claim timeout storage and final-rush state hooks
6. tile clear and unlock-propagation pipeline
7. first board presentation bridge in the client world
8. board debug overlays and validation helpers
9. simple action-validation shell for tile interactions
10. only then move toward controller-targeting integration

This keeps Phase 2 aligned with the already-finished networking foundation.

---

# 26. Recommended first internal test milestone

The first truly meaningful internal milestone should meet all of these conditions:

- dedicated server runs outside editor-only assumptions
- clients connect through the real intended flow
- board state is authoritative and synchronized
- claims work and expire correctly
- a map can be completed from start to finish
- final rush removes claims correctly
- reveal image payoff works
- invalid content fails at startup
- code structure already supports additional roles, variants, and items without rewriting foundations

If a feature does not help reach this milestone, it probably should not be prioritized yet.

---

# 27. Final guidance

RevealTogether should be built as a framework-backed game from day one, not as a prototype that is later “cleaned up.”

The right implementation philosophy is:

- strict boundaries
- thin scenes
- server-owned truth
- content resources for authored design
- tuning in data
- chunk-aware board handling
- small stat vocabulary first
- debug visibility from the start
- progression and polish built on top of stable simulation

That is the path most likely to keep the project modular, configurable, future-proof, and enjoyable to expand.
