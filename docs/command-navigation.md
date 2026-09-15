# Command navigation

This pass addresses the reported empty runtime, unresponsive zoom and inability to select nearby objects. It gives orbital navigation and surface screening different jobs while retaining the persistent physical scene.

## Controls

| Workspace | Purpose | Pointer and camera |
| --- | --- | --- |
| Star chart | Observe candidates, resolve systems and review transit | Click to select; double-click to resolve. Wheel, two-finger scroll, pinch or − / + change scale. Middle/right drag pans. |
| System | Inspect the parent-relative arrangement of worlds | Click a contact; double-click to approach orbit. Focus target inspects it within the map. System restores the whole system. |
| Orbit | Target a planet or moon and issue local orders | Click its silhouette, marker or edge bearing. Single-click keeps the camera; double-click or Focus approaches the target. Planet + moons frames the physical neighbourhood. Day side changes the inspection angle. |
| Surface survey | Compare geographic screening priors and choose a foothold | Solar / Ore / Ice select a data layer; Visual restores natural lighting. Click a region; Locate site centers it. Reconnoitre opens the selected ground site. Nearby contacts remain targetable; Track in orbit opens the selected object's orbital view. |

System, orbit and survey share drag-to-rotate, wheel, two-finger scroll, pinch and visible − / + controls. Keyboard + / − also zoom; F focuses the target; Home recovers the contextual view. Empty instrument containers ignore pointer input, and map interaction is clipped to the rendered viewport. Fullscreen uses the existing visible button, Control–Command–F, Option/Alt–Return or F11.

## What the display means

Orbital navigation opens at the planet-and-moon scale. Physical bodies remain small when viewed across large distances; instrument marks identify unresolved bodies. Trajectories are the existing circular orbit fits. Corner marks identify the target, while edge bearings keep other local contacts reachable outside the camera view. Overlapping unresolved moons stay grouped with the primary until magnification separates them. A contact center hidden behind a resolved foreground body is not drawn or pickable as a visible object. Bearings are navigation instruments, not direct visual sightings or evidence of a sensor detection model.

Range is the inspection camera's distance to its focus. Contact distances are from the selected body, not from a simulated ship orbit. The current simulation places Spaceship in a star system; it does not yet model its local transfer trajectory. Camera navigation cannot spend fuel, move the ship, advance time, unlock observations or build factories.

Surface survey approaches the chosen geographic hemisphere on the same mesh. Its 72 × 36 texture is built from the same `region_context` values displayed in the inspector: solar factor, ore factor and ice factor. These are screening priors, not newly measured deposits. The colour range is 0–2.5×, with higher values saturated; numbers remain available for exact comparison. The map is an emissive instrument layer, so night-side data stays legible. Visual mode shows the actual light direction. The selected outline is the addressed five-degree region; its ground operation remains one isolated 80 m site inside that address.

## Startup and input fixes

The screenshot's root-node mutation error also reproduced on the pinned Godot 4.5 runtime, including a startup crash. `Universe` and `DisplayControls` are now presentation autoloads. Godot loads them before the main scene, as described in its [autoload documentation](https://docs.godotengine.org/en/4.5/tutorials/scripting/singletons_autoload.html). The HUD no longer tries to attach siblings while root is initializing children. Authoritative expedition state remains in the existing RefCounted simulation.

Zoom maintains an accumulated target range and immediately starts moving toward it. Repeated wheel and pinch events no longer restart a zero-slope fly-to tween. Discrete navigation still uses the longer physical approach. Godot's [pan gesture event](https://docs.godotengine.org/en/4.5/classes/class_inputeventpangesture.html) is handled alongside wheel and magnification events for trackpad scrolling.

## Verification and limits

CI launches the actual game executable with both a fresh expedition and a saved generated system, then exercises the rendered interface. `test_command_ui.gd` sends pointer and gesture events through Godot hit-testing: rapid wheel bursts, pan, pinch, visible controls, moon targeting, edge bearings, surface picking, screening values, returning to a targeted orbit and compact layouts. Native macOS repeats the command interactions and fullscreen checks; its CPU renderer uses a reduced 3D viewport for interaction tests. Linux captures the full-resolution frames. Existing model and expedition walkthroughs remain gates.

This pass adds navigation, not a ship-flight model or new science. Continuous terrain, physical ship transfers, global climate, measured surface mapping and day/night industrial power remain substantive future work. Save schema, factory inventories and scientific evidence gates are unchanged.
