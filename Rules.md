



Use only this zip and any file I explicitly attach in this turn as source of truth.

Ignore memory and older zips.



Step 1: audit only, no code.

Before suggesting any changes, list:

1\. exact files read,

2\. exact functions/properties/signals/node paths that exist in the target script,

3\. dependent scripts checked,

4\. exact insertion/replacement anchors that exist verbatim,

5\. any uncertainty.

6\. If an implementation phase is completed, let me know so we can do a github push and create a new branch. 



Rules:

\- Do not infer names.

\- Do not guess missing methods/properties.

\- If an anchor does not exist exactly, stop and say so.

\- Do not give code in the audit phase.



After I approve the audit, move to Step 2:

\- give exact instructions,

\- give full replacement functions/scripts,

\- say exactly where each block goes,

\- use only names verified in the audit.





Critical architecture rules:

\- Do not invent architecture that conflicts with the docs.

\- Keep everything future-proof, modular, data-driven, and configurable.

\- Prefer reusable systems and explicit responsibilities over shortcuts.

\- Do not hardcode gameplay content, IDs, or tuning values that belong in defs/resources/config scripts.

\- Keep runtime truth separate from presentation/debug UI.



Coding rules:

\- Be aware of cross-script dependencies before suggesting changes.

\- Check function names, property names, signals, node paths, Dictionary keys, resource fields, and expected return values against the actual dependent scripts before proposing code.

\- Do not guess missing method/property names.

\- If you touch a script, mentally audit the scripts that call it and the scripts it depends on.

\- Write clean, explicit Godot code with short useful comments.

\- Do not use inferred variables; use explicit variables.

\- Prefer full functions or full scripts in code blocks.

\- If giving code for an existing script, say exactly where to put it.

\- Do not send patch files or tell me vaguely where code goes.



How to work in chat:

\- Explain each step briefly before giving code.

\- Give exact instructions.

\- Give full code blocks so I can copy/paste directly into Godot.

\- Do not send entire files unless necessary, but do send whole functions/scripts when that is the safest option.

\- If something is uncertain, reconcile it against the current zip and docs first.



