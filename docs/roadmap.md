# Development roadmap

This is a sequence of playable proofs, not a promise of dates. Each stage must be useful to play before the next expands the scope. The full direction is in [vision.md](vision.md); scientific constraints and uncertainty are in [science-and-simulation.md](science-and-simulation.md).

| Stage | Deliverable | Exit test |
| --- | --- | --- |
| 0 · First Rain — existing | Two systems, persistent orbital industry, departure/return, saves, CI and exports. | A player can leave a frozen world, resupply elsewhere, return to rain and seed life. This proves continuity, not yet compelling open-ended play. |
| 1 · First Foothold — current prototype | One actual 3D surface sector: inspect terrain, survey deposits, choose a module site, build power/extraction/refining/fabrication and maintain an enclosed microbial refuge. Pause and variable speed, persistent sites, compact spatial HUD. | Placement affects access and throughput; a power or feedstock bottleneck is visible and fixable; finite resources constrain growth; save/load and a long absence preserve the same simulation. |
| 2 · Prospects | Several generated candidate systems under common rules; distant evidence and uncertainty; stellar spectrum, age/activity and orbital exposure; local probes improve knowledge. | New seeds change the expedition without a new mission script. Observation can change where the player chooses to go. Industry-only worlds and abandoned prospects are valid choices. |
| 3 · Planetary engineering | Regional climate, gas and water inventories, gravity, heat transport, photon/particle shielding and biological requirements. Pilot interventions with costs, throughput and uncertainty. | A plan succeeds or fails for inspectable physical reasons. The same process behaves differently on different worlds. A refuge is useful without claiming global habitability. |
| 4 · The long return | Ship resupply from the spatial industry model; module recovery/rebuilding, maintenance, logistics, standing orders, delayed remote reports and scalable unattended integration. | A century-long absence produces an explainable industrial/ecological history. Loaded and unloaded sites obey consistent accounting. |
| 5 · A world worth inhabiting | Larger navigable regions, stronger terrain/material/lighting art, environmental changes, sound and ecological variation. | The playable scene—not a concept painting—conveys place and change at an acceptable measured frame rate. |
| 6 · Embodiment — distant future | Inhabit a manufactured robot or vehicle in the same persistent world; first-person work and exploration. | Direct control operates the same machinery and inventory as strategic orders. No separate decorative first-person game. |

## Current scope lock: First Foothold

Build a bounded surface sector, not an entire planet. The minimum useful chain is module → extraction → refining → fabrication, supported by power and a service network. An enclosed pioneer refuge gives those outputs a purpose. Construction takes time. Deposits run out. Losing life support has consequences.

The prototype uses procedural 3D meshes and Godot-native spatial interaction; no generated screenshot is a runtime asset. The orbit prototype remains accessible. This slice does not implement stellar flares, a magnetic shield, global terraforming from surface production, a procedural galaxy, physical rover pathfinding, full ship-resource conversion, or first-person control.

Before review: run legacy and new simulation tests, malformed-save checks, shared-clock/module-accounting checks, an actual rendered placement walkthrough, and inspect screenshots at normal and compact window sizes. Export browser and Linux builds in CI. Record any remaining approximation in the implementation notes.

## After playtesting this build

First ask whether surveying, choosing a site, diagnosing a bottleneck and expanding are enjoyable. Fix legibility and pacing before adding more structures. Then replace authored distant-world certainty with evidence and make the star/planet model drive the next set of decisions. Do not inflate scope by adding a button for every idea in the science document.
