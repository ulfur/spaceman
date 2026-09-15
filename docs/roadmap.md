# Development roadmap

This is a sequence of playable proofs, not a promise of dates. Each stage must be useful to play before the next expands the scope. The full direction is in [vision.md](vision.md); scientific constraints and uncertainty are in [science-and-simulation.md](science-and-simulation.md).

| Stage | Deliverable | Exit test |
| --- | --- | --- |
| 0 · First Rain — existing | Two systems, persistent orbital industry, departure/return, saves, CI and exports. | A player can leave a frozen world, resupply elsewhere, return to rain and seed life. This proves continuity, not yet compelling open-ended play. |
| 1 · First Foothold — implemented | An actual 3D surface sector: inspect terrain, survey deposits, choose a module site, build power/extraction/refining/fabrication and maintain an enclosed microbial refuge. Pause and variable speed, persistent sites, compact spatial HUD. | Placement affects access and throughput; a power or feedstock bottleneck is visible and fixable; finite resources constrain growth; save/load and a long absence preserve the same simulation. |
| 2 · Prospects — implemented | Six generated candidate systems under common rules; distant evidence and uncertainty; stellar class, qualitative age/activity and orbital exposure; local probes unlock playable regions with different solar yields and deposits. | New seeds change the expedition without a new mission script. Observation can change where the player chooses to go. Industry-only worlds and abandoned prospects are valid choices. |
| 3a · Testbeds — current milestone | First planetary-engineering pilot: a physical 16 m² chamber, industrial power and supplies, heat/gas/water budgets, distinct shielding choices, a specified archive culture and measured history. | The player can establish an enclosed trial, diagnose why it fails, change an intervention and observe the response. Save/load and unattended travel preserve the same experiment. |
| 3b · Regional and global engineering — next | Extend beyond the chamber: regional climate, gas and water inventories, heat transport, atmosphere loss, calibrated photon/particle exposure and exposed biological requirements. Scale interventions against actual planetary budgets. | A plan changes an outside environment for inspectable physical reasons. Different worlds respond differently without a scripted puzzle solution. An enclosed result does not automatically certify global habitability. |
| 4 · The long return | Ship resupply from the spatial industry model; module recovery/rebuilding, maintenance, logistics, standing orders, delayed remote reports and scalable unattended integration. | A century-long absence produces an explainable industrial/ecological history. Loaded and unloaded sites obey consistent accounting. |
| 5 · A world worth inhabiting | Larger navigable regions, stronger terrain/material/lighting art, environmental changes, sound and ecological variation. | The playable scene—not a concept painting—conveys place and change at an acceptable measured frame rate. |
| 6 · Embodiment — distant future | Inhabit a manufactured robot or vehicle in the same persistent world; first-person work and exploration. | Direct control operates the same machinery and inventory as strategic orders. No separate decorative first-person game. |

The [interface pass](interface.md) follows Testbeds: it simplifies all four existing workspaces and validates the same expedition through the revised navigation and controls. Playtesting should now focus on discoverability, pacing and whether a failure suggests a clear next action.

## Current scope lock: Testbeds

The [Testbeds implementation](testbeds.md) connects the environmental evidence from Prospects to a maintained physical experiment. Use the existing surface service graph, power arbitration and inventory. Heat and pressure respond over time; water phase changes, gas processing and biomass production preserve explicit material budgets. Shielding channels remain distinct. Verify that an unsupported culture can fail without deleting its mass or its history.

This is the first part of the planetary-engineering milestone. Global and regional climate dynamics, quantitative radiation dosimetry and exposed ecosystems remain open work. Environmental estimates and biological screening limits must remain labelled as model assumptions. A small chamber cannot manufacture a planetary atmosphere.

## First Foothold foundation

Build a bounded surface sector, not an entire planet. The minimum useful chain is module → extraction → refining → fabrication, supported by power and a service network. An enclosed pioneer refuge gives those outputs a purpose. Construction takes time. Deposits run out. Losing life support has consequences.

The prototype uses procedural 3D meshes and Godot-native spatial interaction; no generated screenshot is a runtime asset. The orbit prototype remains accessible. This slice does not implement stellar flares, a magnetic shield, global terraforming from surface production, a procedural galaxy, physical rover pathfinding, full ship-resource conversion, or first-person control.

Before review: run legacy and new simulation tests, malformed-save checks, shared-clock/module-accounting checks, an actual rendered placement walkthrough, and inspect screenshots at normal and compact window sizes. Export browser and Linux builds in CI. Record any remaining approximation in the implementation notes.

## After playtesting this build

Ask whether scouting changes the destination you choose, whether a dim or ice-poor region changes your construction plan, and whether you can identify why a trial is failing. Compare a filtered daylight chamber with a heavily sheltered, artificially lit one. Fix pacing and legibility before adding more equipment. The next physical models should carry those budgets outside the enclosure and make scaling an explicit engineering problem.
