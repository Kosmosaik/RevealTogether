# RevealTogether - Implementation Plan

## Purpose

This document defines the recommended order of implementation for **RevealTogether**.
The plan is intentionally structured to protect the project from early shortcuts that later cause refactors.

The priority is to build stable foundations first:

- architecture before content depth
- authority before polish
- data boundaries before item complexity
- map flow before secondary systems

---

## Current status snapshot (2026-04-20)

The current repo state has completed the foundational startup and multiplayer loop work.

### Completed in code
- **Phase 0** is complete: project structure, runtime modes, config loading, logging, content registry bootstrap, and startup validation are all present.
- **Phase 1** is complete: dedicated server boot, client connect flow, hello ack/reject, join snapshot/reject, player spawn/despawn, and basic server-driven transform snapshot replication are implemented.

### Current repo truth
- The project already boots in `client`, `dedicated_server`, and `local_debug` runtime modes.
- `AppBootstrap`, `RuntimeConfig`, `LogService`, and `ContentRegistry` are established autoload foundations.
- `MatchSessionService` owns the current connection/session flow and authoritative player-session state.
- The client currently proves the network foundation through the sandbox world and replica avatar layer.

### Next phase
The project should now move into **Phase 2 - Board and reveal core**. That is the next major milestone worth branching for.

---

## 1. Implementation strategy

The project should be built in phases.
Each phase must leave the codebase in a cleaner and more extensible state than before.

Important rule:

**Do not solve early progress with throwaway systems that are known to be incompatible with the final architecture.**

That means:
- no fake local-only authority for core board logic
- no giant single-scene prototype that later needs to be broken apart completely
- no hardcoding content definitions directly into gameplay scripts when those systems are already known to be data-driven later

---

## 2. Phase overview

## Phase 0 - Project skeleton
**Status:** Complete in the current repo state.

### Goal
Create the permanent project structure and startup model.

### Main work
- create the Godot folder structure
- define runtime modes
- add autoload bootstrap layer
- add config loading
- add logging strategy
- add content registry bootstrap
- add startup validation framework

### Exit criteria
- project runs in clean client mode
- project runs in clean dedicated server mode
- startup validation works
- content IDs can be registered and checked

### Why this phase matters
This phase prevents the project from turning into a pile of disconnected experiment scripts.

---

## Phase 1 - Dedicated server loop
**Status:** Complete in the current repo state.

### Goal
Prove the multiplayer foundation with real connections.

### Main work
- create dedicated server entry path
- create client connect flow
- establish map/session join flow
- create player spawn path
- implement disconnect handling
- implement basic server-driven player replication

### Exit criteria
- multiple friends can connect to the server running on the developer PC
- players spawn consistently
- disconnects do not corrupt the session
- server clearly owns authoritative session state

### Notes
This phase should be tested over the intended temporary public-IP setup.

---

## Phase 2 - Board and reveal core
**Status:** Next active implementation phase.

### Goal
Implement the full playable board loop.

### Main work
- create logical board data structure
- create tile records
- implement chunk partitioning
- bind hidden image underlay to the board
- implement unlock seeds
- implement claim timeout rule
- implement tile damage and clear
- implement adjacent unlock propagation
- implement end-of-map detection
- implement final-rush claim removal

### Exit criteria
- a full map can be started and completed
- claims behave correctly
- tile progress persists correctly
- hidden image reveal works correctly
- final-rush transition works correctly

### Why this phase matters
This is the project’s real gameplay heart.
Everything else should build on top of this.

---

## Phase 3 - 3D player controller and camera
### Goal
Make the game feel right in its intended 3D form.

### Main work
- implement player controller in 3D space
- implement tile targeting feedback
- implement constrained top-down camera
- implement zoom levels
- implement limited angle or rotation options
- implement visible nearby players
- implement enough world dressing to validate readability

### Exit criteria
- the game is readable in 3D
- targeting is clear
- map movement feels good
- final reveal still feels meaningful
- camera does not break the reveal loop

### Why this phase matters
The project is not just a board simulation.
It needs to feel like a 3D social multiplayer game.

---

## Phase 4 - Data-driven content framework
### Goal
Move content assumptions out of gameplay code.

### Main work
- define role data assets
- define tile family data assets
- define tile variant data assets
- define behavior definitions or behavior links
- define map preset data assets
- add registry validation for all major content types
- add basic content inspection tools

### Exit criteria
- roles can be added through data
- new tile variants can be added through data
- map presets can be changed without rewriting core board code
- validation catches broken content early

### Why this phase matters
This is the phase that turns the project from a prototype into a framework.

---

## Phase 5 - Tool, charm, and inventory scaffolding
### Goal
Create the backbone for items without over-designing final loot balance.

### Main work
- define item base structures
- define Tool and Charm data models
- define inventory ownership and storage rules
- implement server-approved item grants
- add drop hooks from tile clear events
- add placeholder UI for basic item visibility

### Exit criteria
- tools can exist as role-specific data-backed items
- charms can exist as separate utility items
- inventory can hold drops
- item ownership is server-approved

### Important note
This phase should create the structure, not the final content depth.
Detailed charm effects and full item balancing can wait.

---

## Phase 6 - Map progression feedback and results
### Goal
Add the first satisfying full-match outcome layer.

### Main work
- add global map progress tracking
- add progress milestone events
- add late-game phase signaling
- add results screen
- add final reveal sequence
- add contribution statistics package
- add archive-ready result output structure

### Exit criteria
- players receive a proper map completion sequence
- results are server-produced and consistent
- end-of-map data can be stored or reused later

### Why this phase matters
This is where the game starts to feel complete, not just functional.

---

## Phase 7 - Internal hardening
### Goal
Prepare the build for more serious testing and eventual migration to a proper host.

### Main work
- profile chunk updates
- profile board update cost
- test reconnect edge cases
- test map reset correctness
- improve debug visibility
- improve logging
- validate runtime mode setup
- remove accidental local-only assumptions

### Exit criteria
- internal sessions are stable enough to trust
- server crashes and desyncs are reduced
- moving off the developer PC later is straightforward

---

## 3. Suggested detailed work order inside early phases

## 3.1 Recommended order before any deep gameplay extras
1. project skeleton
2. dedicated server startup
3. client connect and spawn
4. logical board data model
5. tile claim and damage validation
6. tile clear and unlock propagation
7. hidden image reveal
8. final-rush phase
9. 3D camera and movement
10. data-driven registries

Only after this should the project spend serious time on:
- richer tile behaviors
- deeper item design
- expanded role set
- more advanced progression systems

---

## 4. Team discipline rules during implementation

## 4.1 No temporary architecture that is known to be wrong
If a shortcut conflicts with the intended architecture, do not normalize it just because it is faster in the moment.

## 4.2 Every new system must declare ownership
For every new feature, answer:
- who owns the data?
- who validates the action?
- who renders the result?
- where does tuning live?

## 4.3 Data must be validated early
Do not allow broken IDs, missing references, or invalid links to survive into runtime silently.

## 4.4 New features should plug into frameworks
Do not implement future Tomb-style tile behavior, new roles, or special items by patching random central files.
Use the extension structure deliberately.

---

## 5. Deliverables by milestone

## Milestone A - Server-connected sandbox
Deliverables:
- dedicated server running
- multiple clients connected
- visible player presence
- clean join and disconnect handling

## Milestone B - Fully playable map loop
Deliverables:
- map start
- unlock progression
- claim timeout
- tile clearing
- image reveal
- map completion

## Milestone C - 3D feel validation
Deliverables:
- top-down 3D controller
- constrained camera
- readable tile targeting
- visible social presence

## Milestone D - Data-driven framework validation
Deliverables:
- role definitions loaded from data
- tile family and variant definitions loaded from data
- map presets loaded from data
- validation tools working

## Milestone E - Item backbone
Deliverables:
- Tool and Charm data structures
- inventory scaffold
- server-driven item grants
- placeholder item UI

## Milestone F - Internal test candidate
Deliverables:
- stable results flow
- debug visibility
- hardening pass
- reproducible server startup process

---

## 6. Success criteria for the first serious internal build

The first serious internal build should satisfy all of the following:

- friends can connect over the dedicated server setup reliably
- board state remains synchronized
- claims obey the server timeout rule consistently
- a map can be played from start to finish without soft lock
- image reveal works correctly and feels meaningful
- code and content remain organized by domain rather than by prototype leftovers
- the project is ready to accept more content without structural rewrites

---

## 7. Risks to watch early

## 7.1 Overbuilding visual content before framework maturity
Do not spend too much time on detailed tile behaviors, charm designs, or special item flavor before the board and data model are stable.

## 7.2 One-node-per-tile assumptions
A naive tile scene approach can become difficult to scale.
Chunk-aware architecture should come early.

## 7.3 Local test assumptions becoming permanent
Testing on the developer PC is fine.
Hardcoding the project around that environment is not.

## 7.4 Client-authoritative convenience
These shortcuts feel productive early and become expensive later.
Avoid them.

---

## 8. Immediate next artifact after Phase 1

After completing Phase 1, the most useful next artifact is:

**a Phase 2 board-and-reveal runtime breakdown**

That should lock the next implementation slice for:
- `BoardState` and `TileRecord` runtime contracts
- authored map preset structure and board bootstrap flow
- chunk partitioning and index helpers
- claim timeout and final-rush state hooks
- board replication DTO boundaries
- first board presentation bridge and debug overlays
