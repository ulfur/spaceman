# Commander Spaceman

**Commander Spaceman commands the spaceship Spaceship.**

He is a braincast of the original commander: a digital mind adapted to life as a ship. He travels between stars, builds industry from local resources, and gives lifeless worlds the possibility of a future.

**First Rain** is the first playable expedition. Leave a factory on a frozen world. Travel to another star. Come home to the consequences.

**First Foothold** adds a real 3D industrial sector: survey terrain, land a module, extract ore and ice, build power/refining/fabrication, and maintain an enclosed pioneer refuge. It shares the expedition clock and save, while the orbital model remains deliberately simple.

**Prospects** adds six generated systems to scout and visit. Buy orbit fits, spectra and stellar activity observations, compare dated evidence and travel reserves, then arrive, probe and open a new 3D region. Its sunlight and resource richness change actual factory output and deposits. See [Prospects controls and model](docs/prospects.md).

The broader goal spans a galactic map, star systems, planetary engineering, RTS-style surface industry, and eventually first-person robot embodiment. See [Game direction](docs/vision.md) for that vision and the distinction between current features and future work.

The updated concept is an open-ended expedition simulation: observe distant systems, choose where to travel, develop an industrial plan, and discover the consequences. [Science and simulation](docs/science-and-simulation.md) records scientific constraints and speculative engineering; [Visual direction](docs/visual-direction.md) translates the concept-art direction into runtime goals. The [development roadmap](docs/roadmap.md) sets the order and acceptance tests for playable milestones.

## Play

Open `project.godot` in **Godot 4.5 standard** and press **F6 on `main.tscn`**, or **F5** to run the project. No plugins, external art assets, Python service, or package installation are required. CI pins Godot 4.5; newer engine versions are not yet part of the test matrix.

```sh
godot --path .
```

The game starts paused. In orbit, use **+1 / +10 / +50 yr** to advance time. **F11** toggles fullscreen. Saves live in Godot's application data directory as `expedition.json`; old expedition saves migrate to the combined format.

### Try the new surface prototype

**Survey Eir III → Surface operations / 3D**, before deploying the legacy orbital-policy factory. If your existing save already has one there, reclaim it first. Land the module near ore and ice, then use the bottom toolbelt to build. **Space** pauses; **1× / 10× / 50×** set simulated hours per second. **Middle-drag** pans, **wheel** zooms and **Q/E** rotate. **Escape** returns to orbit, paused. See [surface controls and model boundaries](docs/surface-prototype.md).

A useful first production chain is solar → ore extractor + ice well → refinery → fabricator → refuge. Add enough solar capacity and inspect machine status when something stalls. Deposits and life-support supplies are finite: a refuge is not automatically sustainable forever. Module recovery and surface freight are not yet implemented in this slice.

### Scout another system

Open **Prospects / observatory** from orbit. Click a star, run an **Orbit fit**, **Spectrum**, and **Activity watch** as useful, then review **Commit transit**. On arrival, a **Local probe** unlocks that planet's **Surface operations / 3D**. **Local orbit** exposes its industrial companion and the original ship-supply mechanics. Observation consumes time and fuel; a probe also consumes alloy. New expeditions can use a chosen neighbourhood seed. Saves now use version three and migrate both earlier formats.

### Your first expedition

1. **Survey Eir III**, then **land a factory module**. Keep its equilibrium target at **288 K**.
2. **Depart for Vesper**. Confirm the costs and factories being left behind. The journey takes **68 years**.
3. **Survey Vesper B** and land the second factory. Advance **10 years**, then **collect manufactured supplies**. More time means more reserves, until the deposit is exhausted.
4. **Depart for Eir**. Eir III has kept changing during both journeys. This completes **First Rain** if the world has developed enough liquid water.
5. **Release pioneer life**, then advance decades to watch it grow. Continue exploring, recover factories, build replacements, repair Spaceship, or experiment with a different climate target.

You begin with enough transit reserves for one round trip even without mining. Further journeys require industry. Recovering a warming factory stops its work; the atmosphere subsequently loses its greenhouse effect slowly. Extreme targets can destroy a developing biosphere.

## Builds and CI

Pull requests run a headless simulation suite and an actual rendered UI expedition under Xvfb, with screenshots saved as the **expedition-checks** artifact. Successful runs also export **spaceman-web** and **spaceman-linux** artifacts in [GitHub Actions](https://github.com/ulfur/spaceman/actions).

To play the browser artifact, extract it and serve that directory over HTTP:

```sh
python3 -m http.server 8000
```

Open `http://localhost:8000` in a WebGL 2-capable browser. Opening `index.html` directly from disk will not work. The export uses Godot's Compatibility renderer and single-threaded web mode. Browser save persistence depends on local site storage being available. The browser export is built by CI; the automated rendered interaction test exercises the native engine.

For Linux, extract the artifact, run `chmod +x spaceman.x86_64`, then run the executable. macOS and Windows users can run the source project in Godot; native exports for those platforms are not configured yet.

Local verification:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/test_simulation.gd
godot --headless --path . --script res://tests/test_surface.gd
godot --headless --path . --script res://tests/test_prospects.gd
godot --path . --script res://tests/test_ui.gd -- --smoke
godot --path . --script res://tests/test_surface_ui.gd -- --smoke
godot --path . --script res://tests/test_prospects_ui.gd -- --smoke
```

The last command needs a display and writes screenshots to ignored `build/`. On a Linux CI machine, prefix it with `xvfb-run -a`. Smoke mode bypasses player saves.

## Structure

| Path | Responsibility |
| --- | --- |
| `scripts/simulation.gd` | State, commands, annual evolution, observations, saves |
| `data/expedition.json` | Authored systems, starting resources, route parameters |
| `scripts/main.gd` | Orbital command interface |
| `scripts/session.gd` | Shared time, module allocation, combined saves and migration |
| `scripts/surface_simulation.gd` | Surface resources, construction, power, service graph and refuge |
| `scripts/surface.gd`, `scripts/surface_world.gd` | Spatial controls/HUD and procedural 3D rendering |
| `data/surface.json` | Surface kit inventories and construction recipes |
| `scripts/prospects.gd`, `data/prospects.json` | Generated worlds, observation evidence and programme costs |
| `scripts/observatory.gd`, `scripts/prospect_map.gd` | Distant scouting, route review and destination selection |
| `scripts/space_view.gd` | Star chart and procedural viewport |
| `shaders/planet.gdshader` | Rotating globe; ice, water, clouds, and life reflect state |
| `tests/` | Simulation invariants and rendered expedition walkthrough |
| `docs/design.md` | Concept, model assumptions, boundaries, and next milestones |

## Scope

This is an early gameplay prototype. It includes two authored systems, three bodies, warming and mining factories, recovery and replacement, repairs, lifeseeding, stale remote observations, event history, and versioned saves.

Climate and industrial quantities are deliberately simplified. This is not a physical climate or propulsion solver. The globe is a procedural shader; each 3D sector is a bounded region, not a full traversable planet. Its rovers illustrate activity rather than performing physical pathfinding. Prospects generates a small neighbourhood, not a full galaxy. Quantitative radiation hazards, exposed-life viability on generated worlds, walking robots, autonomous branching policies, detailed ship construction, upgrades, sound, and multiplayer remain future work.

There is no automatic website deployment and no third-party telemetry.
