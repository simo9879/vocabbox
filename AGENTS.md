# Agent guidelines

Read [the prototype handoff](docs/prototype-handoff.md), [the game specification](docs/game-spec.md), and the relevant source scenes before making changes. Treat the handoff as context about the existing implementation; the specification describes the intended player experience.

## Code and scene rules

1. **Comment logical code blocks by purpose.** Add a short comment above a non-obvious block or sequence explaining what it accomplishes. Keep comments useful and current; do not narrate every line or repeat what the code already makes clear.
2. **Give each file one clear responsibility.** Keep files concise and easy to edit. Put separate behavior in separate scripts, scenes, or resources where that improves clarity. Avoid both oversized all-purpose files and needless files for trivial code.
3. **Use DRY and SOLID as design principles.** Keep one authoritative source for shared behavior and lesson data. Use object-oriented design and composition when they make responsibilities, dependencies, or replacement points clearer; avoid abstractions without a concrete use.
4. **Do not render or generate 3D geometry from code.** Do not create runtime meshes, primitive stand-ins, procedural environments, or scripted model geometry. Build the world from actual, reviewed model assets and authored Godot scenes. Replace the existing code-generated scenery and characters gradually with real models; preserve a playable project as each area is reworked. Verify and document asset licenses before adding redistributable content.

## Collaboration and handoff

- Many agents may work on this prototype. Before parallel work, agree on a small task and disjoint file ownership. All agents share the same workspace, so concurrent edits to one file can overwrite each other. Integrate changes deliberately and tell the next agent which files and behaviors are ready.
- Keep the mission, dialogue, presentation, player, camera, art assets, and save behavior separated by responsibility. Coordinate changes to shared scene interfaces and signals with their consumers.
- Do not silently change lesson wording, quality criteria, mission order, save formats, controls, or asset provenance. Record intentional changes in the relevant docs.
- When handing work off, state what changed, which files own the behavior, what remains, and what was verified. Distinguish a headless check from a rendered or manually played check.
- Avoid unrelated code, generated assets, or exported builds when a task is documentation-only. Keep asset credits and the handoff current as the prototype changes.
