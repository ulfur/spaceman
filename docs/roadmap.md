# Development roadmap

This is a sequence of playable proofs, not a promise of dates. Each stage must be useful to play before the next expands the scope. The full direction is in [vision.md](vision.md); scientific constraints and uncertainty are in [science-and-simulation.md](science-and-simulation.md).

| Stage | Deliverable | Exit test |
| --- | --- | --- |
| 0 · First Rain — existing | Two systems, persistent orbital industry, departure/return, saves, CI and exports. | A player can leave a frozen world, resupply elsewhere, return to rain and seed life. This proves continuity, not yet compelling open-ended play. |
| 1 · First Foothold — implemented | An actual 3D surface sector: inspect terrain, survey deposits, choose a module site, build power/extraction/refining/fabrication and maintain an enclosed microbial refuge. Pause and variable speed, persistent sites, compact spatial HUD. | Placement affects access and throughput; a power or feedstock bottleneck is visible and fixable; finite resources constrain growth; save/load and a long absence preserve the same simulation. |
| 2 · Prospects — implemented | Six generated candidate systems under common rules; distant evidence and uncertainty; stellar class, qualitative age/activity and orbital exposure; local probes unlock playable regions with different solar yields and deposits. | New seeds change the expedition without a new mission script. Observation can change where the player chooses to go. Industry-only worlds and abandoned prospects are valid choices. |
| 3a · Testbeds — implemented | First planetary-engineering pilot: a physical 16 m² chamber, industrial power and supplies, heat/gas/water budgets, distinct shielding choices, a specified archive culture and measured history. | The player can establish an enclosed trial, diagnose why it fails, change an intervention and observe the response. Save/load and unattended travel preserve the same experiment. |
| S1 · Spatial expedition — implemented | Addressable galactic fields, system and moon hierarchy, anchored view transitions, geographic site selection and persistent regional industry. Surface camera controls remain usable while paused. | Resolve a field without moving the ship, approach a particular planet, establish two geographic footholds and return to the same factories after saving. |
| S2 · Continuous worlds — next spatial milestone | Stream terrain and deposits around a travelling surface camera; replace the isolated active worksite with neighbouring chunks in one planetary coordinate frame. Preserve per-chunk state, level of detail and unloading rules. | Pan across a worksite boundary without a scene reset; survey and build beyond it; leave the planet and recover the same terrain and industry. |
| 3b · Regional and global engineering | Extend beyond the chamber: regional climate, gas and water inventories, heat transport, atmosphere loss, calibrated photon/particle exposure and exposed biological requirements. Scale interventions against actual planetary budgets. | A plan changes an outside environment for inspectable physical reasons. Different worlds respond differently without a scripted puzzle solution. An enclosed result does not automatically certify global habitability. |
| 4 · The long return | Ship resupply from the spatial industry model; module recovery/rebuilding, maintenance, logistics, standing orders, delayed remote reports and scalable unattended integration. | A century-long absence produces an explainable industrial/ecological history. Loaded and unloaded sites obey consistent accounting. |
| 5 · A world worth inhabiting | Larger navigable regions, stronger terrain/material/lighting art, environmental changes, sound and ecological variation. | The playable scene—not a concept painting—conveys place and change at an acceptable measured frame rate. |
| 6 · Embodiment — distant future | Inhabit a manufactured robot or vehicle in the same persistent world; first-person work and exploration. | Direct control operates the same machinery and inventory as strategic orders. No separate decorative first-person game. |

The [interface pass](interface.md) follows Testbeds: it simplifies all four existing workspaces and validates the same expedition through the revised navigation and controls. Playtesting should now focus on discoverability, pacing and whether a failure suggests a clear next action.

## The direction is an open world

The galaxy is the world, not a mission selector. Stars, planetary systems, moons, terrain, factories and eventual embodied vehicles must share persistent addresses and one physical clock. View changes reveal different spatial scales; they must not silently move Spaceship, reroll terrain or reset industry.

[Spatial expedition](spatial-expedition.md) removes the one-surface-per-body assumption. It adds lazy stellar catalogue fields, a real system hierarchy, regional coordinates and an inspectable descent. These are foundations for continuous worlds, not a completed galaxy simulator. The active industrial simulation is still an 80 m worksite and the wider planetary globe remains a reconstruction. The next spatial milestone must tackle that boundary directly, with chunk streaming and industrial expansion across chunks.

The physical simulation track continues alongside this work: the [Testbeds implementation](testbeds.md) supplies heat, gas, water, power, culture and shielding budgets. Carry those budgets into outside environments and larger regions. A maintained chamber does not establish planetary habitability. Stellar variability, particle and photon exposure, atmosphere loss and global interventions need calibrated models before they become authoritative mechanics.

Ship-resource conversion, recovery and logistics must make distant expeditions sustainable. Procedural addresses alone do not supply meaningful destinations; better scouting, distinct environments and consequences must make choosing where to go matter. Embodiment should eventually use the same physical installations, inventories and geographic world as the strategic game.

Before review: run the deterministic model and migration tests, actual rendered navigation and industrial walkthroughs, and inspect normal and compact layouts. Browser and Linux exports remain the playable deliverables.

## After playtesting this build

Ask whether scouting changes the destination you choose, whether a dim or ice-poor region changes your construction plan, and whether you can identify why a trial is failing. Compare a filtered daylight chamber with a heavily sheltered, artificially lit one. Fix pacing and legibility before adding more equipment. The next physical models should carry those budgets outside the enclosure and make scaling an explicit engineering problem.


### Cross-cutting visual pass — Living worlds

A graphics pass now spans the current orbital, observatory, surface and trial screens: larger layered planets, stellar navigation feedback, continuous geology, detailed instanced/batched industrial art, operating-state animation and a physical trial cutaway. See [visual direction](visual-direction.md) for scope and rendering limits. This advances the look of the existing prototype; streamed planetary terrain, biome simulation, local weather and embodied exploration remain future work.
