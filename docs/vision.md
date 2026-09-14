# Commander Spaceman — game direction

This records the intended game discussed after playtesting First Rain. It guides subsequent design; it is not a claim that these systems are implemented or a commitment to build them all next. `design.md` describes the existing prototype and its approximations.

The subsequent direction is explicitly an open-ended, scientifically grounded expedition simulation. See [Science and simulation](science-and-simulation.md) for observation limits, coupled environmental models, and engineering possibilities, and [Visual direction](visual-direction.md) for concept art and mockup screens.

## The experience

Spaceman is a persistent digital mind exploring, engineering, and inhabiting a changing universe. Spaceship, industrial installations, manufactured robots, and eventually vehicles are ways for that mind to act. The factory module is the seed of an industrial operation: land it, survey locally, choose where to establish it, harvest resources, manufacture equipment, and expand.

The intended game combines expedition planning, planetary engineering, and spatial industry with RTS-style interaction. Players need room to devise solutions, experiment, establish industrial worlds, and choose which places to revisit. Terraforming and lifeseeding are ambitions, not a mandatory checklist of identical Earth replacements.

The first prototype proved the development pipeline, game skeleton, and visual idea of observing a changed world from orbit. Its prescribed survey–deploy–wait–return sequence has little meaningful choice. Increasing the number of planets or adding more target-temperature buttons will not by itself solve that.

## Four connected scales, with embodiment much later

| Scale | Decisions and activity | What the interface should reveal |
| --- | --- | --- |
| Galactic / interstellar map | Choose destinations, routes, revisits, and long-term projects; compare opportunities against travel and supply costs. | Star characteristics, travel time, known opportunities, uncertainty, outposts, and dates of last contact. |
| Star system map | Survey bodies, move Spaceship, launch probes or modules, organise orbital and interplanetary logistics. | Orbits, illumination, planetary relationships, resource distribution, transit routes, and industrial dependencies. |
| Individual planet | Evaluate physical and biological viability, inspect regional conditions, choose landing regions, and plan interventions. | Resource, insolation, climate, atmosphere, radiation, terrain, and biosphere overlays with geographically meaningful differences. |
| Surface / industrial site | Land and survey, establish the module in a useful location, place equipment, assign robotic work, extract, process, manufacture, store, transport, and expand. | Actual terrain, resource deposits, structures, workers, power connections, transport routes, construction progress, and bottlenecks. |
| Embodiment — distant future | Inhabit a robot or vehicle for work and exploration; possibly directly operate a factory. | The same world and assets experienced from a first-person viewpoint. |

Each scale should expose decisions that belong there. A surface refinery's real output contributes to a planetary intervention and supports future ship operations. Returning from a trip reveals the history of the same industrial settlement. Seamless camera travel between scales is not a prerequisite; continuity of state matters first.

The No Man's Sky comparison describes the eventual experience of personally exploring these places. It does not imply building its full feature set, scope, combat, or multiplayer. Factory embodiment remains an open idea; it may mean occupying its sensors and machinery rather than walking through it.

## Habitability is a coupled problem

Planetary viability must depend on interacting conditions with actual constraints, not a single temperature or generic habitability score. The player should be able to inspect what is wrong, what can be changed, what it would cost, and what uncertainty remains.

Candidate dimensions for a progressively richer model:

- Stellar energy received, spectral character and activity; orbital distance, eccentricity, and exposure over time.
- Rotation, tidal locking, axial tilt, seasons, and the geographic distribution of light and heat.
- Magnetic environment, stellar wind and energetic radiation, atmospheric shielding, and atmospheric loss or replenishment over the relevant timescale.
- Planetary mass and gravity, atmospheric pressure and composition, greenhouse behaviour, and retention of volatiles.
- Liquid water, its distribution and cycling, terrain, accessible materials, and biological nutrients.
- Requirements of the intended organisms and ecosystem: microbial life, a diverse surface biosphere, and unprotected human habitation are different targets.

These are design dimensions to introduce when they create understandable decisions. Not all require a detailed physical solver. Regional viability should be possible: a world might support one suitable area, a subsurface ecology, or productive industry while remaining unsuitable for a global surface biosphere.

Ordinary industrial interventions should have credible limits. Some planetary characteristics are effectively fixed at the player's present technological capability. Exceptional megaprojects, if introduced later, need explicit power, material, and time costs. Every world should not be cheaply convertible into the same outcome.

### Scientific guardrails for the model

Magnetic protection belongs in the model, but an intrinsic magnetic field is not a universal atmosphere-retention prerequisite. Venus has a dense atmosphere without an internally generated field and instead has an induced magnetic field. It is not a habitable counterexample; it demonstrates that atmosphere, magnetic environment, and habitability cannot be collapsed into one binary gate. [NASA: Venus facts](https://science.nasa.gov/venus/venus-facts/)

Tidal locking need not restrict a planet to a narrow habitable terminator. Climate modelling finds terminator habitability particularly relevant to some water-limited worlds; water-rich cases can support larger habitable areas. Treat this as a family of possible regional climates. [Lobo et al.: Terminator Habitability](https://arxiv.org/abs/2212.06185)

Atmospheric and oceanic heat transport can redistribute energy between the permanent day and night sides. Coupled climate models find that ocean dynamics can substantially warm a tidally locked world's nightside, with the balance between oceanic and atmospheric transport depending on stellar flux. For gameplay, this supports a tractable regional heat-transport model rather than a fixed tidal-lock penalty. [Yang et al.: Ocean Dynamics and the Inner Edge of the Habitable Zone](https://arxiv.org/abs/1902.02103)

## Local industry is where the plan becomes tangible

The target surface loop is:

1. Inspect orbital information and choose a provisional landing region.
2. Land the module, survey locally, and resolve deposits, terrain, hazards, and useful access routes.
3. Choose the establishment site with enough information to make a meaningful placement decision.
4. Construct extraction, power, processing, storage, and transport capacity.
5. Use real inputs and output queues to manufacture equipment, planetary infrastructure, ship supplies, repairs, upgrades, or replacement modules.
6. Expand, change priorities, and configure autonomy so the settlement can function while the commander is elsewhere.

Decisions should emerge from location and capacity. A deposit can be rich but poorly situated; solar access can conflict with resource proximity; a new atmospheric plant competes with ship resupply for manufacturing time. Producing a resource does not make it instantly available everywhere.

The module itself remains recoverable. The fate of expanded infrastructure, reclamation costs, and the capability lost during recovery need deliberate design. The current prototype's immediate recovery is not the final rule.

An unattended site must execute an actual standing plan with constraints. Its output and failures should be explainable on return. Event history should help the player understand a failed supply route or exhausted deposit, and successful automation should earn freedom to explore.

## Time and attention

The preferred direction to prototype is continuously advancing, pausable time with selectable speed, familiar from city builders and RTS management games. Exact rates and the default starting speed remain tuning decisions. Local construction and transport need visible progress while the player plans other work.

Maintain one authoritative simulation timeline across all locations and views. Separate integration frequencies are compatible with that; separate contradictory clocks are not. Changing camera scale alone must not alter production, resource balances, project completion, or elapsed time.

Surface work and centuries of travel require different levels of simulation detail. At ordinary speed, individual jobs and movement can be represented. At high acceleration or while unloaded, aggregate production and logistics must still respect capacity, travel delays, resource availability, power, and stopping conditions. A blocked transport route cannot become productive just because its scene is unloaded.

Preserve state when returning to detailed simulation. Use explicit acceleration controls and bounded, interruptible long advances. Important events may pause or reduce speed according to player settings. Exact determinism is preferable within the chosen model; any approximation introduced for very large time advances needs a documented error bound and tests against the detailed model.

Leaving should provide access to worthwhile new opportunities while autonomous projects continue. Waiting locally is also a valid choice. Travel must earn its place through exploration, logistics, and the passage of deep time.

## Interface and atmosphere

The current console is a functional sketch. The target is a stronger, more distinctive science-fiction interface with a clear visual hierarchy, readable telemetry, and direct spatial interaction.

- Give each scale a focused workspace and meaningful map overlays. Avoid filling every view with the same columns of buttons.
- Let players select objects, inspect them, see available contextual actions, preview construction placement, and issue work orders spatially.
- Show power, material flows, connections, job queues, and bottlenecks where the player is acting.
- Keep navigation, selected object, commander location or embodiment, current time, and time controls consistent across scales.
- Make changes visible in atmosphere, terrain, water, ecosystems, industrial activity, and history. Visual polish includes motion, transitions, effects, and eventually sound.
- Mark unknown, estimated, and old information clearly. A detailed planetary overlay must not silently reveal what has not been surveyed or recently observed.
- Preserve Spaceman's dry, restrained personality and the loneliness and curiosity of long expeditions.

## First bounded experiment and what follows

First Foothold implements one bounded 3D sector on Eir III, connected to the orbital overview: terrain and deposits, a landable module, surveying, power, an aggregate service network, construction and repeating manufacturing batches, an enclosed microbial refuge, and pause/speed controls. It shares expedition time and saves. Its limits, including committed surface modules and no physical rover pathfinding, are recorded in the [implementation notes](surface-prototype.md).

After playtesting that interaction, build a small sandbox of contrasting candidate worlds and a reusable set of industrial and environmental rules. The player should gather distant evidence, choose an expedition, make consequential placement and production decisions, see a bottleneck, revise a plan, and watch real outputs influence the world. There is no fixed puzzle solution or required number of routes. The existing authored journey remains useful as a regression fixture and a test of autonomy.

The [roadmap](roadmap.md) separates these milestones. Detailed galactic generation, full planetary terrain, first-person exploration and the entire habitability model remain later work; they are not hidden behind the current sector's visuals.
