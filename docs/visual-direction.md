# Visual direction: from concepts to a real build

The concept images and screen mockups produced during design are aspirational illustrations, not screenshots of working software. Their telemetry is illustrative, not a scientific catalogue. The implementation target is now a scene we can actually run, select, build in and measure.

## Direction

Spaceship is Spaceman's body. The interface is a synthetic sensory workspace, not a human cockpit with decorative controls. Use restrained technical typography, bone-white markings, amber commands and muted cyan observations against graphite. Terrain and machinery carry most of the image; the HUD gives context and intent.

For the surface prototype, use a full-window 3D sector with actual light, shadows, parallax, foundations, resource outcrops and recognizable industrial silhouettes. Warm mineral ground contrasts with pale manufactured equipment, dark radiators and small signal lights. Selection, construction ghosts, survey marks and service lines live on the ground. Avoid permanent card grids, rounded web-form controls and large panels obscuring the site.

Controls should answer: what am I pointing at, what will be built, why is placement blocked, what does it cost, and why is this machine waiting? Keyboard shortcuts complement mouse selection; visible labels remain necessary. Colour is accompanied by text, not the sole signal.

## The four workspaces

| Workspace | Primary visual | Essential interaction |
| --- | --- | --- |
| Galactic | Local stellar neighbourhood; reconstructions explicitly marked as inferred. | Compare evidence, travel cost and dated reports. |
| System | Body relationships and routes; schematic scale labelled. | Observe, select transfers and allocate limited equipment. |
| Planet | Globe and regional overlays showing measured coverage. | Diagnose constraints and choose a landing/intervention region. |
| Surface | Real 3D terrain and industry with minimal overlays. | Survey, preview, place, inspect production and revise the network. |

No Man's Sky is a long-term reference for the appeal of exploring a place, not a claim that this prototype matches its fidelity or scope. The next visual milestone is credible, readable machinery on tangible ground. More ambitious terrain streaming, biomes, atmospheres and embodiment must be earned by working builds and measured performance.

## Implemented interface pass

The [interface pass](interface.md) applies this direction across the four current screens: common navigation and time controls, one contextual inspector, a collapsed surface build palette, grouped trial controls and separate history views. The planet and terrain carry the composition. Secondary instructions, long dossiers and utility commands are disclosed when needed. Normal and compact native-engine screenshots are reviewed from CI.


## Living worlds graphics pass

This is implemented procedural art in Godot 4.5 Compatibility. Every view is rendered by the game; there are no painted backgrounds pretending to be playable terrain.

- **Orbit:** a larger inspection globe, multiple terrain frequencies, relief shading, ocean reflections, polar frost, independently moving cloud patterns, a shaded night side and a thin illuminated atmosphere. The observed body supplies the seed and the existing temperature, water and biomass values. An airless moon has no atmospheric halo. The geometry remains an illustration, especially for generated prospects whose geography has not been resolved.
- **Navigation:** a restrained stellar backdrop with cursor parallax, star glows and hover feedback. The selected route carries a moving planning pulse. Catalogue positions and travel distances remain fixed; the pulse does not depict an actual ship in transit.
- **Surface:** the 80 m working sector sits in continuous seeded geology. Stratified outcrops, scattered debris, surface relief, a sky reflection source, softer fill lighting, distance haze and restrained bloom give depth. Cold surfaces receive patchy frost. Distant scenery has no resource or collision meaning. Pressure gates the haze; lighting is a fixed art setup, not a simulation of local daylight or atmospheric radiative transfer.
- **Industry:** metre-scale chamfered housings, landing struts, photovoltaic cells, drills, pipework, radiators, service equipment and glazed culture beds replace placeholder blocks. Static geometry is combined by material; loose geology uses eight instanced batches. Selection volumes follow the larger asset silhouettes. Deposits are revealed only after survey and shrink as their remaining resource falls.
- **Activity:** antenna rotation, drill and pump rotors, radiator fans, fabrication carriages, culture-surface motion and service rovers follow the simulation's operating state. Pausing freezes them. Disabled, unpowered, exhausted or production-blocked equipment stops. Surveying produces a short feedback wave; this is a UI indication, not a physical radar simulation.
- **Trials:** the same equipment kit appears in a lit 3D cutaway with the front glazing omitted for inspection. The actual experiment remains sealed. Culture coverage, water state, fitted canopy and grow-light visibility follow trial state. A separate full-size graph preserves the sampled measurements and their units.

The animation rate is illustrative and capped at high simulation speeds. Orbital inspection rotation and navigation feedback run independently of the simulation clock. Rovers illustrate service activity and do not yet have collision avoidance or pathfinding. No effects manufacture inventory, advance time, alter physical models or add new fields to saved expeditions.

The renderer deliberately uses material batching, instanced rocks, ordinary depth fog and the Compatibility glow implementation. It does not rely on Forward+-only volumetric fog, SDFGI or screen-space indirect light. See the Godot 4.5 [Environment reference](https://docs.godotengine.org/en/4.5/classes/class_environment.html), [SurfaceTool](https://docs.godotengine.org/en/4.5/classes/class_surfacetool.html) and [MultiMesh](https://docs.godotengine.org/en/4.5/classes/class_multimesh.html).

Validation runs the model suites and all four interactive engine walkthroughs, captures normal and compact windows, and checks that machinery moves while presentation leaves the simulation unchanged. The surface walkthrough also records a short sequence of rendered motion frames and reports draw calls and visible primitives. Those counts are diagnostics; CI software rendering is not a hardware performance benchmark.
