# Commander Spaceman

**Commander Spaceman commands the spaceship Spaceship.**

He is a braincast of the original commander: a digital mind adapted to life as a ship. He travels between stars, builds industry from local resources, and gives lifeless worlds the possibility of a future.

**First Rain** is the first playable expedition. Leave a factory on a frozen world. Travel to another star. Come home to the consequences.

**First Foothold** adds a real 3D industrial sector: survey terrain, land a module, extract ore and ice, build power/refining/fabrication, and maintain an enclosed pioneer refuge. It shares the expedition clock and save, while the orbital model remains deliberately simple.

**Prospects** adds six generated systems to scout and visit. Buy orbit fits, spectra and stellar activity observations, compare dated evidence and travel reserves, then arrive, probe and open a new 3D region. Its sunlight and resource richness change actual factory output and deposits. See [Prospects controls and model](docs/prospects.md).

**Testbeds** adds a physical environmental experiment to those regions. Build a chamber, control its heat and gas inventory, supply water and shielding, and test an archive culture against the resulting conditions. The engineering console plots real measurements; the same experiment keeps evolving when you leave. See [Testbeds controls, equations and limits](docs/testbeds.md).

The **interface pass** reorganises these features into a star chart, orbital view, surface workspace and field-trial console with shared navigation and contextual controls. See [screen layout and controls](docs/interface.md).

The **physical space** pass replaces screenshot zooms with a persistent 3D scene, physical body sizes and distances, mass-dependent orbital periods and a shared geographic lighting frame. Inspect planetary families with **Moons**, then return with **Planet**. See [physical space, controls and model limits](docs/physical-space.md).

The broader goal spans a galactic map, star systems, planetary engineering, RTS-style surface industry, and eventually first-person robot embodiment. See [Game direction](docs/vision.md) for that vision and the distinction between current features and future work.

The updated concept is an open-ended expedition simulation: observe distant systems, choose where to travel, develop an industrial plan, and discover the consequences. [Science and simulation](docs/science-and-simulation.md) records scientific constraints and speculative engineering; [Visual direction](docs/visual-direction.md) translates the concept-art direction into runtime goals. The [development roadmap](docs/roadmap.md) sets the order and acceptance tests for playable milestones.

## Play

Open `project.godot` in **Godot 4.5 standard** and press **F6 on `main.tscn`**, or **F5** to run the project. No plugins, external art assets, Python service, or package installation are required. CI pins Godot 4.5; newer engine versions are not yet part of the test matrix.

```sh
godot --path .
```

The game starts paused. In orbit, use **+6 h** or **+1 / +10 / +50 yr** to advance time. Every view has a **Full screen** button; on Mac use **Control–Command–F** or **Option–Return**. If the game is embedded in Godot, stop it and disable **Embed Game on Play**, then run in its own window. Saves live in Godot's application data directory as `expedition.json`; old expedition saves migrate to the combined format.

### Try the new surface prototype

**Survey Eir III → Choose a landing site → click the globe → Reconnoitre this site**, before deploying the legacy orbital-policy factory. If your existing save already has one there, reclaim it first. Land the module near ore and ice, then open **Build [B]** and choose **Industry** or **Life support**. **Space** pauses; **1× / 10× / 50×** set simulated hours per second. **WASD / arrows** or **middle/right drag** pan, **wheel / trackpad** zoom, and **Q/E** rotate. Visible **− / + / Home** controls work while paused. **Planet** returns to geographic selection and retained site markers. **Escape** dismisses placement or selection first, then returns to orbit, paused. Hold **Shift** for repeated placement. See [surface controls and model boundaries](docs/surface-prototype.md).

A useful first production chain is solar → ore extractor + ice well → refinery → fabricator → refuge. Add enough solar capacity and inspect machine status when something stalls. Deposits and life-support supplies are finite: a refuge is not automatically sustainable forever. Module recovery and surface freight are not yet implemented in this slice.

### Scout another system

Open **Star chart** from the navigation bar. Click a star, run an **Orbit fit**, **Spectrum**, and **Activity watch** as useful, then choose **Review transit**. On arrival, a **Local probe** unlocks that planet's **Choose a landing site** action. The named **orbit** link opens the system map; select a planet or moon and **Approach orbit** for its local operations. Double-click stars to inspect their system maps. **Galaxy** and **Catalogue this field** resolve additional addressable stellar fields without moving Spaceship. Observation consumes time and fuel; a probe also consumes alloy. **Menu → New expedition** can use a chosen neighbourhood seed; that seed and the acquired evidence persist in the expedition save.

### Run a field trial

On a probed generated world, land a module, then choose **Build → Life support → Field testbed [9]** and place it on the service network. Select the finished structure and choose **Open field trial**. Use the **Climate**, **Shielding** and **Culture** tabs; let the conditions settle before committing one archive packet. Switch from **Chamber** to **Temperature**, **Pressure** or **Culture** to inspect its history. A UV filter and a regolith canopy have different effects, and an opaque shelter needs another light source.

Testbeds draw actual surface power and service parts. Losing support can kill the culture. This first engineering pilot covers a 16 m² enclosure; regional/global terraforming remains on the roadmap. Saves use version five and migrate versions one through four.

### Your first expedition

1. **Survey Eir III**, expand **Orbital industry**, then **Deploy climate factory**. Keep its equilibrium target at **288 K**.
2. Open **Star chart**, select **Vesper**, then **Review transit → Begin transit**. Confirm the costs and factories being left behind. The journey takes **68 years**.
3. Enter **Vesper orbit → Approach orbit** with Vesper B selected, then **Survey Vesper B** and **Deploy factory module**. Advance **10 years**, then **Collect supplies**. More time means more reserves, until the deposit is exhausted.
4. Return through **Star chart → Eir → Review transit**. Eir III has kept changing during both journeys. This completes **First Rain** if the world has developed enough liquid water.
5. Enter **Eir orbit → Approach orbit** with Eir III selected, and **Introduce pioneer life**, then advance decades to watch it grow. Continue exploring, recover factories, build replacements, repair Spaceship, or experiment with a different climate target.

You begin with enough transit reserves for one round trip even without mining. Further journeys require industry. Recovering a warming factory stops its work; the atmosphere subsequently loses its greenhouse effect slowly. Extreme targets can destroy a developing biosphere.

## Builds and CI

A native macOS job tests fullscreen and window restoration in all six workspaces. Pull requests also run a headless simulation suite and an actual rendered UI expedition under Xvfb, with screenshots saved as the **expedition-checks** artifact. Successful runs also export **spaceman-web** and **spaceman-linux** artifacts in [GitHub Actions](https://github.com/ulfur/spaceman/actions).

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
godot --headless --path . --script res://tests/test_testbeds.gd
godot --headless --path . --script res://tests/test_atlas.gd
godot --headless --path . --script res://tests/test_celestial.gd
godot --path . --script res://tests/test_ui.gd -- --smoke
godot --path . --script res://tests/test_surface_ui.gd -- --smoke
godot --path . --script res://tests/test_prospects_ui.gd -- --smoke
godot --path . --script res://tests/test_testbeds_ui.gd -- --smoke
godot --path . --fixed-fps 20 --script res://tests/test_navigation_ui.gd -- --smoke
```

The last five commands need a display and write screenshots to ignored `build/`. On a Linux CI machine, prefix them with `xvfb-run -a`. Smoke mode bypasses player saves.

## Structure

| Path | Responsibility |
| --- | --- |
| `scripts/simulation.gd` | State, commands, annual evolution, observations, saves |
| `data/expedition.json` | Authored systems, starting resources, route parameters |
| `scripts/interface.gd` | Shared native UI styles, navigation, menus and layout |
| `scripts/main.gd` | Orbital command interface |
| `scripts/session.gd` | Shared time, module allocation, combined saves and migration |
| `scripts/surface_simulation.gd` | Surface resources, construction, power, service graph and refuge |
| `scripts/surface.gd`, `scripts/surface_world.gd` | Spatial controls/HUD and procedural 3D rendering |
| `data/surface.json` | Surface kit inventories and construction recipes |
| `scripts/prospects.gd`, `data/prospects.json` | Generated worlds, observation evidence and programme costs |
| `scripts/observatory.gd`, `scripts/prospect_map.gd` | Distant scouting, route review and destination selection |
| `scripts/testbed_simulation.gd`, `data/testbeds.json` | Chamber gas, heat, water phases, exposure and archive-culture model |
| `scripts/testbeds.gd`, `scripts/trial_diagram.gd` | Engineering orders, live schematic and measured history |
| `scripts/world_atlas.gd`, `data/spatial.json` | Stable world addresses, orbital fits and geographic priors |
| `scripts/system.gd`, `scripts/system_map.gd` | Planet and moon hierarchy with spatial selection |
| `scripts/regions.gd`, `scripts/region_globe.gd` | Geographic picking and persistent foothold markers |
| `scripts/navigation.gd` | Camera transitions between simulation scales |
| `scripts/space_view.gd` | Procedural planetary viewport |
| `shaders/planet.gdshader` | Rotating globe; ice, water, clouds, and life reflect state |
| `tests/` | Simulation invariants and rendered expedition walkthrough |
| `docs/design.md` | Concept, model assumptions, boundaries, and next milestones |

## Scope

This is an early gameplay prototype. It includes two authored systems plus six initial generated prospects, twenty-four initial bodies, additional stellar fields generated on demand, persistent geographic surface sites, spatial industry, distant observing programmes and local probes. The original warming/mining factories, recovery and replacement, repairs, lifeseeding, stale remote observations and event history remain available alongside versioned saves.

Climate and industrial quantities are deliberately simplified. The physical testbed is a bounded engineering model; global climate, propulsion and radiation dosimetry are not solved. The globe is a procedural shader; each 3D sector is a bounded region, not a full traversable planet. Its rovers illustrate activity rather than performing physical pathfinding. The galactic catalogue is generated lazily across a synthetic disc; active industrial sites remain 80 m and planetary terrain between them is not yet streamed. Exposed-life viability on generated worlds, walking robots, autonomous branching policies, detailed ship construction, ship upgrades, sound, and multiplayer remain future work.

There is no automatic website deployment and no third-party telemetry.


The **Living worlds** graphics pass adds native procedural planet rendering, stellar navigation feedback, continuous terrain, a detailed industrial asset kit, operating machinery and a 3D field-trial cutaway. See [visual direction](docs/visual-direction.md) for what the graphics represent and which effects are illustrative. Simulation pause also freezes working machinery; orbital inspection and route-planning feedback use presentation time.

The [spatial expedition milestone](docs/spatial-expedition.md) adds system maps, animated scale changes, geographic site selection and lazy galactic catalogue fields. See the [roadmap](docs/roadmap.md) for continuous-world streaming and the broader simulator direction.
