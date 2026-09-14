# Working on Spaceman

- Preserve the core concept: Commander Spaceman is a braincast and effectively the ship. Factories are persistent, recoverable capabilities. Departure and return are the central loop.
- Keep authoritative game state in the simulation, outside scene-tree nodes. Presentation must not change physical state.
- Use Godot 4.5 standard / GDScript and the Compatibility renderer until a deliberate engine upgrade is agreed.
- Keep scenario values in data. New models must state their units and approximations.
- Time advances must be deterministic. Test resource accounting, action preconditions, save continuity, and unattended evolution when changing those systems.
- Remote UI must use observed state, not live omniscient state. Current prototype reacquires information locally; delayed communications are future work.
- Do not commit `.godot/`, exported builds, temporary files, or player saves.
- Before calling a change verified, run the simulation suite and relevant rendered UI checks. If the engine is unavailable locally, use CI and report the actual outcome.
- Work on feature branches and use pull requests. Do not merge or deploy without user authorization.
- Document scope honestly. Prefer one functioning expedition over a framework for hypothetical future systems.
