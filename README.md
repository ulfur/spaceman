# Commander Spaceman

**Commander Spaceman commands the spaceship Spaceship.**

He is a braincast of the original commander: a digital mind adapted to life as a ship. He travels between stars, builds industry from local resources, and gives lifeless worlds the possibility of a future.

**First Rain** is the first playable expedition. Leave a factory on a frozen world. Travel to another star. Come home to the consequences.

The broader goal spans a galactic map, star systems, planetary engineering, RTS-style surface industry, and eventually first-person robot embodiment. See [Game direction](docs/vision.md) for that vision and the distinction between current features and future work.

The updated concept is an open-ended expedition simulation: observe distant systems, choose where to travel, develop an industrial plan, and discover the consequences. [Science and simulation](docs/science-and-simulation.md) records scientific constraints and speculative engineering; [Visual direction](docs/visual-direction.md) translates the concept-art direction into runtime goals. The [development roadmap](docs/roadmap.md) sets the order and acceptance tests for playable milestones.

## Play

Open `project.godot` in **Godot 4.5 standard** and press **F6 on `main.tscn`**, or **F5** to run the project. No plugins, external art assets, Python service, or package installation are required. CI pins Godot 4.5; newer engine versions are not yet part of the test matrix.

```sh
godot --path .
```

The game starts paused. Use **+1 / +10 / +50 yr** to advance local operations. **F11** toggles fullscreen. Saves are automatic after successful commands and time advances; manual save/load and a confirmed reset are also available. Saves live in Godot's application data directory as `expedition.json`.

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
godot --path . --script res://tests/test_ui.gd -- --smoke
```

The last command needs a display and writes screenshots to ignored `build/`. On a Linux CI machine, prefix it with `xvfb-run -a`. Smoke mode bypasses player saves.

## Structure

| Path | Responsibility |
| --- | --- |
| `scripts/simulation.gd` | State, commands, annual evolution, observations, saves |
| `data/expedition.json` | Authored systems, starting resources, route parameters |
| `scripts/main.gd` | Command interface and save-file I/O |
| `scripts/space_view.gd` | Star chart and procedural viewport |
| `shaders/planet.gdshader` | Rotating globe; ice, water, clouds, and life reflect state |
| `tests/` | Simulation invariants and rendered expedition walkthrough |
| `docs/design.md` | Concept, model assumptions, boundaries, and next milestones |

## Scope

This is an early gameplay prototype. It includes two authored systems, three bodies, warming and mining factories, recovery and replacement, repairs, lifeseeding, stale remote observations, event history, and versioned saves.

Climate and industrial quantities are deliberately simplified and tuned for an expedition lasting a few centuries. This is not a physical climate or propulsion solver. The globe is a procedural shader, not a navigable surface. Walking robots, a procedural galaxy, autonomous branching policies, detailed ship construction, upgrades, sound, and multiplayer are future work.

There is no automatic website deployment and no third-party telemetry.
