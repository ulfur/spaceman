# Interface pass

The four playable workspaces now use a common navigation bar, resource strip, contextual inspector and bottom time controls. The previous layouts surrounded the scene with simultaneous instructions, multiple destinations, repeated statistics and permanently exposed controls. This pass gives each screen a primary task and makes secondary detail available when needed.

| Workspace | Main task | Detail on demand |
| --- | --- | --- |
| Star chart | Select a system, acquire evidence and review a route | Evidence tab contains the full dated dossier; Menu contains new expeditions and seeds |
| Orbit | Select a local body and survey or operate it | Orbital industry expands the original climate programme; Menu contains saves, loading and the journal |
| Surface | Inspect, survey and place machinery on the actual terrain | Build opens Industry / Life support; the selection inspector fits its contents |
| Field trial | Read the chamber and diagnose its response | Climate / Shielding / Culture contain related orders; measurement tabs switch to a large history graph |

## Navigation and controls

Star chart is the only interstellar route planner, including Eir and Vesper. Arrival keeps the chart open so the player can probe the world; the local-orbit link always names Spaceship's current system. The orbit view's body selector chooses the world or industrial companion. The survey/landing action leads into the surface. Select a finished testbed there to enter its field trial. Header links move back through these levels without presenting another duplicate engineering entry point on every screen.

The surface starts ready to place a module on a fresh site. **B / Build** opens the equipment palette. Choose **Industry** or **Life support**, then place equipment on the ground. A successful placement returns to inspection; **Shift** keeps the selected construction tool for repeated placement. Number keys **0–9** remain direct shortcuts. **Esc** closes a palette, placement or selection before returning to orbit. **Right-click** cancels placement. The inspector's close button clears the selection.

Field trials keep current temperature, pressure and live biomass visible. **Chamber** shows equipment and physical exchanges; **Temperature**, **Pressure** and **Culture** show the selected measurement history instead. **Inspect limits** opens the Culture controls with the complete diagnosis. Outside measurements expand there. A trial selector appears only when several chambers exist; it is not rebuilt every simulated hour.

Temperature setpoints require Auto; pressure setpoints require the gas regulator. Current modes use the same selected-button treatment as navigation tabs and time rates. Inoculation, upgrades and construction still use their model preconditions. Parts are the surface component inventory, measured in bulk-equivalent tonnes; archive packets and factory modules are counts.

Time remains explicit. Orbit advances years in discrete steps. Surface and trials start paused; **1× / 10× / 50×** mean logical hours per real second. **Space** toggles pause, and opening Menu pauses continuous time. Trials also offer a day/week advance. The shared clock remains visible while inspecting another control tab. Changing tabs, opening the palette or dismissing UI does not advance the expedition.

**Menu** holds secondary actions and contextual help. It opens beside the navigation bar inside the game viewport, keeps keyboard focus inside its actions, blocks clicks reaching the scene behind it, and closes on an outside click or Esc. Save/load and expedition-reset behaviour remain explicit; resetting still requires confirmation. **F11** toggles fullscreen outside menus.

## Implementation and checks

`scripts/interface.gd` owns shared Godot presentation primitives, styles, menu behaviour and layout helpers. Each scene keeps its existing session/model commands. The old two-star presentation and four separate button skins have been removed. No simulation equations, save schemas, generated-world data or resource recipes change in this pass.

Rendered tests use mouse hit-testing through the actual navigation, tabs, palettes and controls. They retain the original departure/return expedition, the surface production chain, scouting and probing, and culture establishment/loss. They also check that purely presentational interactions preserve simulation state, that seeding remains available after factory recovery, and that navigation/inspectors fit normal and compact windows. CI captures the resulting screens and exports Web and Linux builds.

The design still uses procedural terrain and native Godot graphics. Broader terrain art, audio, new planetary workspaces, mobile-specific layouts and controller navigation are separate work.
