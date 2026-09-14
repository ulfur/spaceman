# First Rain — design and implementation notes

## The premise

Commander Spaceman commands Spaceship. He is a modified digital copy of the biological commander, with instincts and bodily drives adapted for digital existence. He can eventually inhabit manufactured robots, but the ship and its computer are his continuous self.

Spaceship travels between systems using fusion-powered ion propulsion. It surveys worlds for terraforming and lifeseeding, commits a scarce collection of factory modules, and uses local industry to supply its own continuation. A deployed module must be reclaimed or replaced if the commander wants that capability aboard again.

Travel is a decision about time. Work can continue after departure. Revisiting a system reveals what the commander actually caused.

## The playable question

Can the player leave a frozen planet, return to rain, and feel attached to what happened?

Two authored systems make that question testable. Eir contains Eir III (terraformable) and Nacre (industrial moon). Vesper contains Vesper B (industrial ice world). Starting with two factories makes allocation visible without making the first expedition excessively punishing.

The first arrival at Eir after visiting Vesper achieves First Rain if surface water exceeds 15%. It does not end the game. Lifeseeding follows, and the player can continue to build reserves, replace factories, repair Spaceship, or alter climate policies.

## State and time

`simulation.gd` extends `RefCounted`. It has no Node dependencies. The JSON scenario provides authored conditions; all mutable state is serializable and versioned.

Every command checks its requirements before modifying state. Time is a whole calendar year. `advance(200)` executes exactly the same ordered annual updates as 200 calls to `advance(1)`. For three bodies and century-scale journeys, this is cheap and easy to verify. A call is capped at 10,000 years to bound work. The current UI exposes 1, 10, and 50-year advances.

We deliberately defer adaptive integration and event skipping. Those optimizations become worthwhile with a larger galaxy or geological timescales; tests must preserve outcomes when they are introduced.

Travel duration is `ceil(distance_ly / cruise_fraction_c) + maneuver_years`: 4.2 ly / 0.07 c + 8 = 68 years. Both systems evolve throughout transit. Ship clocks and external calendar time are identical in this prototype; relativity and actual acceleration trajectories are not simulated.

## Industrial quantities

Fuel, propellant, alloy, and deposit amounts use abstract inventory mass units, not calibrated tonnes. They are separate inventories.

- Mining consumes at most 3 deposit units per year and yields 2 propellant, 0.8 alloy, and 0.2 reactor fuel. Total inventory yield equals deposit consumed; no extraction losses are modeled yet.
- Manufactured goods remain on the body until collected locally. Recovery also collects its stores.
- A warming factory consumes at most 1.5 local deposit units per year. Each unit produces 0.65 K of equilibrium greenhouse forcing. This coefficient is a balancing abstraction.
- Building a module consumes 20 onboard alloy, 3 reactor fuel, and 5 years at a local mining factory. Ordinary extraction continues during those years; dedicated manufacturing capacity is not modeled yet.
- Repairing uses 10 onboard alloy and 2 years at a local mining factory, restoring up to 25 integrity.
- Each transit uses 18 reactor fuel, 65 propellant, and 8 integrity. Integrity must exceed 20 before departure. Costs are fixed for the one authored route and do not yet depend on ship mass.

Factories have self-contained power and maintenance provisions in this slice. Local orbital transfers and survey probes do not consume additional inventory. There is no storage capacity limit. These are explicit simplifications, not hidden simulations.

## Planetary model

Eir III starts at 244 K with no liquid surface water. Greenhouse forcing decays by 0.02 K-equivalent each year. An active warming factory adds forcing up to its equilibrium target, constrained by annual throughput and remaining feedstock. The surface relaxes toward baseline plus forcing by 18% of the temperature difference per year.

The 288 K and 300 K targets support the starter organisms. The 325 K target is intentionally dangerous. Policies stop emitting at the target equilibrium; they do not wait for surface temperature to catch up and accidentally overshoot.

Liquid water is a bounded temperature-derived proxy. Introduced life follows logistic growth under suitable temperatures (273–303 K) and sufficient water, otherwise declining by 15% annually. There is no atmospheric chemistry, hydrological conservation, detailed ecology, existing alien life, or scientific habitability claim.

The globe shader uses the observed temperature, water, and biomass. Geography is deterministic procedural noise. Rotation is visual and does not advance the simulation.

## Knowledge and history

Local observations update when time advances or commands complete. During transit, no body's observations update. Arrival reacquires all bodies in the destination system, while detailed metrics remain gated behind survey in the UI.

The chart uses the last observation of Eir III. Planet-specific event entries are hidden until the observer has a sufficiently recent observation. Internal state still tracks everything, but UI access goes through `known_body` and `known_log`.

This is an intentional local-observation approximation. Continuous delayed radio reports and signal propagation are future mechanics. Do not present stale data as current state.

History records significant events rather than every tick and retains up to 500 entries. Saves contain world state, stocks, logs, and last observations; invalid saves leave the current expedition intact.

## Presentation

A dark observation console with restrained teal telemetry and warm amber decisions. The planet is the visual center. Interface actions and their requirements should be legible; command buttons are disabled when their known requirements fail, with explanations nearby or in tooltips. A departure dialog states elapsed time, costs, and factories left working.

The current UI targets desktop landscape windows around 1280×800 and larger. Compact landscape rendering is checked at 1100×760. Phone portrait interaction and controller navigation are not finished features.

## Next milestones

1. Playtest the departure/return loop. Tune the value of waiting locally versus committing to another journey, resource pressure, and how much agency the player has before departure.
2. Add policy conditions and meaningful unattended failures, with a chronological explanation on return.
3. Add an industrial project queue, cargo limits, energy budgets, and module construction capacity.
4. Introduce another distinct terraformable world before procedural generation.
5. Add ship upgrades and delayed reports; consider seeded procedural systems once authored ones produce interesting decisions.
6. Add robot embodiment as a way to experience the results, including standing under the first storm.

Avoid expanding into combat, multiplayer, detailed surface movement, or a galaxy generator before the expedition itself is fun.

## Engine references

- [Godot command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Godot web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html): Compatibility rendering, single-threaded export, and browser storage constraints.
- [Pinned Godot 4.5 release](https://godotengine.org/download/archive/4.5-stable/)
