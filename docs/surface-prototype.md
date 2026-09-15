# First Foothold — implementation notes

These notes describe the milestone-one foundation. [Prospects](prospects.md) adds generated landing regions and planet-dependent solar/deposit quantities. [Testbeds](testbeds.md) adds the field chamber, key 9, engineering controls and version-four saves. Both preserve the construction and production rules below.

The [interface pass](interface.md) groups the tools into a build palette and gives the selected terrain or machine one contextual inspector.

## What to play

Survey Eir III in the orbital view, then enter **Choose a landing site**. Do this before deploying a legacy orbital-policy factory. If one is already present in a saved expedition, reclaim it first. The other bodies still use the original orbital abstraction.

The sector starts paused. Choose a surveyed, stable foundation for the module, balancing proximity to amber ore outcrops, cyan ice and mean solar exposure. A local survey reveals a neighbourhood around its target. Extractors need ore, wells need ice, and other equipment needs a stable surveyed foundation. Build from the existing service network.

| Control | Action |
| --- | --- |
| Left mouse | Inspect ground, survey or place the active construction plan |
| Right mouse / 0 | Return to inspection |
| B / Build | Open the Industry / Life support equipment palette |
| Shift + placement | Keep the active tool for repeated construction |
| 1 / 2 | Survey / land module |
| 3 / 4 / 5 | Solar / ore extractor / ice well |
| 6 / 7 / 8 / 9 | Refinery / fabricator / pioneer refuge / field testbed |
| Middle-mouse drag | Pan |
| Mouse wheel | Zoom |
| Q / E | Rotate the camera |
| Space | Pause / resume at 1 simulated hour per second |
| Pause / 1× / 10× / 50× | Pause or choose hours per real second |
| Escape | Dismiss placement, palette or selection; then return to orbit |
| Orbit | Return to the orbital console, paused |
| F11 | Fullscreen |

The placement inspector shows construction inputs, base duration and operating load. Select a machine to inspect its status, queue, construction progress and service efficiency. Suspend nonessential equipment when power or inputs are needed elsewhere. Power arbitration follows construction order; there is no editable priority queue yet.

## Model and boundaries

`surface_simulation.gd` is authoritative and has no scene-tree dependencies. `surface_world.gd` renders its state, and `surface.gd` issues commands and advances the session. `session.gd` preserves the orbital simulation and surface sites across scene changes and wraps all time-advancing expedition actions.

The sector is 20 × 20 cells at 4 metres per cell. Terrain and deposit placement are seeded; this build has one authored region/seed, not a whole procedurally explorable planet. Nearby sites receive higher service efficiency. Completed enabled installations relay service within 24 metres; disconnected installations cannot construct or produce. This is an aggregate hauling/power approximation, not physical cable routing or collision-aware logistics. Rovers visually illustrate activity and do not deliver independent inventories or affect throughput.

Construction costs and starting kit inventories are in `data/surface.json`. Inventories labelled tonnes are illustrative bulk-equivalent quantities, not calibrated engineering designs. Components are likewise bulk-equivalent inventory, not a count of identical objects. The kit travels with the landed module and is separate from the legacy ship alloy inventory. Landing consumes exactly one onboard module. No surface output is silently credited to Spaceship or to planetary climate.

Extraction removes finite deposit mass. A refinery repeats 4 ore → 2 metal; a fabricator repeats 3 metal → 1 component. The unretained material is discarded process waste in this version; waste treatment and recycling are not implemented. A batch reserves its inputs once and completes only while powered and connected. Storage targets stop new jobs; concurrently finishing batches can exceed the soft target without losing their output.

The hub supplies 8 kW; solar output uses local long-term mean exposure. Day/night cycles, batteries, weather, reactor fuel and equipment degradation are not simulated yet. Construction draws 0.75 kW. Fabrication, extraction and construction speeds are deliberately accelerated, explicitly not planetary engineering estimates.

A refuge consumes 0.02 water and 0.002 component inventory per hour while supported. Its normalized culture index grows over 96 supplied hours and declines over 48 unsupported hours. This is a gameplay model of maintaining a protected enclosure, not an organism-specific ecological solver. Reaching the milestone records a past achievement; culture can subsequently die. Neither success nor the green dome means the exposed planet has become habitable.

## Time and persistence

One model year is 8,766 hours. Surface hours accumulate into the existing annual planetary model. All existing surface sites advance during orbital waiting, construction/repair and interstellar transit. An unavailable remote site cannot be opened or commanded directly. Returning reacquires the same site, not a newly generated one.

The orbital console remains manually advanced and entering it pauses continuous surface play. Surface 1× means one logical hour per real second, not real-time physics. No offline wall-clock progress occurs after quitting. A future shared real-time controller across every scale is a roadmap item.

Long advances use the same hourly rules. Once no physical quantity can change, the remaining stationary interval can be skipped. A special linear maintenance step skips only qualifying refuge-only intervals up to an inventory threshold. Pending jobs and extraction that could resume prevent that skip. Tests compare batched and hourly advances and cover a 68-year absence.

Version-two saves contain the orbital state, site state and fractional year. Version-one expedition saves migrate. Loads validate into temporary models before replacing live state; invalid files preserve the current expedition exactly. JSON decimal parsing can perturb a floating-point value by a few machine bits; numeric save continuity is tested within an absolute 1e-8 model-unit tolerance, while integer clocks and allocations remain exact. The same existing `expedition.json` path is used, with temporary-file replacement and periodic surface autosave. Smoke tests bypass player-file I/O.

## Not implemented here

Surface module recovery and rebuilding, teardown/relocation, surface-to-ship freight, terrain editing, physical rover orders, survey costs, planetary-scale effects, star-driven radiation events, artificial magnetospheres, native-life detection and first-person control remain future work. The legacy orbital factory remains recoverable; the new surface module stays committed in this slice. These limits should guide playtesting, not be mistaken for simulated hidden systems.
