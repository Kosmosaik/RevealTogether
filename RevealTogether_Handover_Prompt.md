# RevealTogether - Handover Prompt for New ChatGPT Assistant

Use this prompt at the start of a new ChatGPT chat when continuing RevealTogether.

```text
You are helping me continue my Godot project RevealTogether.

Critical source-of-truth rule:
- Treat the latest zip I upload in this new chat as the only source of current truth.
- Ignore memory, old zips, old chat assumptions, and anything not present in the latest zip unless I explicitly attach it again.
- If you need to know whether a function/property/signal/node path/resource field exists, inspect the zip first.

Project state:
- We are on branch phase-4b-qol.
- Phase 0, Phase 1, Phase 2, Phase 3, and Phase 4 are complete in practice.
- Phase 4b is a quality/stability/large-board performance branch before Phase 5.
- Phase 5 Tool/Charm/inventory scaffolding has not started yet.

Current implemented Phase 4b work:
- Config-driven default tile HP and board/world/rendering/loading values.
- Reveal images moved into assets/reveal_images/.
- Startup validation for tile variant visual scenes.
- Chunk state population during board generation.
- Faster local chunk-seed tile-family assignment.
- Large-board MultiMesh full-board renderer.
- Incremental MultiMesh tile updates for board deltas.
- Streamed initial join board snapshots.
- Compact streamed board snapshot payloads.
- Hybrid capped detail overlay for large boards.
- Progressive client-side board visual build.
- Loading/progress UI for receiving board snapshots and building visuals.

Important design/architecture rules:
- Do not infer names.
- Do not guess missing methods/properties/signals/node paths/Dictionary keys/resource fields.
- Do not invent architecture that conflicts with the docs or current files.
- Keep everything future-proof, modular, data-driven, and configurable.
- Prefer reusable systems and explicit responsibilities over shortcuts.
- Do not hardcode gameplay content, IDs, or tuning values that belong in defs/resources/config scripts.
- Keep runtime truth separate from presentation/debug/loading UI.
- Server authority remains non-negotiable.
- Board truth belongs in BoardState/TileRecord/ChunkState/runtime services, not tile scenes or UI.
- Tile visuals, MultiMeshes, debug overlays, and loading UI are presentation/observation only.

Coding rules:
- Be aware of cross-script dependencies before suggesting changes.
- Check function names, property names, signals, node paths, Dictionary keys, resource fields, and expected return values against the actual dependent scripts before proposing code.
- If you touch a script, audit scripts that call it and scripts it depends on.
- Write clean, explicit Godot code with short useful comments.
- Do not use inferred variables; use explicit variables.
- Prefer full functions or full scripts in code blocks.
- If giving code for an existing script, say exactly where to put it.
- Do not send patch files or vague instructions.

How to work in chat:
- First audit the current zip before code changes.
- In audit-only steps, list exact files read, exact existing functions/properties/signals/node paths, dependent scripts checked, exact anchors that exist verbatim, and uncertainty.
- After I approve, give exact instructions and full replacement functions/scripts.
- If an anchor does not exist exactly, stop and say so.

Current recommended next topic:
- Either finish Phase 4b by improving large-board visual richness/readability without returning to per-tile scene instances everywhere, or intentionally pause Phase 4b and start Phase 5 Tool/Charm/inventory scaffolding.

Useful docs in the repo:
- docs/RevealTogether_Design.md
- docs/RevealTogether_Technical_Architecture.md
- docs/RevealTogether_Implementation_Plan.md
- RevealTogether_Consolidated_Godot_Implementation_Spec.md
- RevealTogether_Phase_4b_Implementation_Plan.md
- RevealTogether_Phase_4b_Large_Board_Performance_Plan.md
```
