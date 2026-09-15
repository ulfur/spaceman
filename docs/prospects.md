# Prospects — milestone 2

[Testbeds](testbeds.md) extends this foundation with synthetic native-gas composition, a grey ambient-temperature estimate, physical field experiments and version-four saves. The observation/route rules below remain in place.

Prospects adds six generated systems to the two-system First Rain fixture. Each has a candidate terrestrial planet and an industrial companion. The same observation, route, inventory and surface-production rules apply to every prospect. The generator produces illustrative synthetic systems, not a catalogue of real stars or a statistically calibrated galaxy.

## Play

From orbit choose **Prospects / observatory**. Select a star directly on the chart. Its catalogue supplies location, broad spectral class, luminosity and an age range; planetary conditions remain unknown.

| Programme | Cost | Evidence gained |
| --- | --- | --- |
| Orbit fit | 36 hours, 0.25 reactor fuel | Bounds on separation and received stellar flux |
| Spectrum | 96 hours, 0.50 reactor fuel; orbit fit first | Atmospheric spectral clue; no pressure or ground-inventory measurement |
| Activity watch | 240 hours, 0.40 reactor fuel | Qualitative sampled stellar variability; not a prediction of every future event |
| Local probe | 12 hours, 0.50 reactor fuel, 1 alloy; arrival required | Local pressure, gravity, field, rotation and a landing region's resource/solar context |

Programme durations advance the same expedition clock and all existing industrial sites. Completed programmes cannot be rerun to fish for a better result. The truth is generated from the expedition seed and never changes when an observation is purchased. The ranges are designed uncertainty bounds, not formal confidence intervals or a spectrum-retrieval calculation.

Compare transit time, fuel/propellant costs and same-route return reserves before departing. Arrival enables a local probe; probing enables **Surface operations / 3D** on the new world. The orbital view also exposes the industrial companion: its existing abstract mining factory can manufacture ship supplies, be reclaimed, and produce replacement modules. Spatial modules remain committed as in First Foothold.

The chart includes Eir and Vesper, so the original expedition and a return home remain available. New routes are not fixed mission steps. The **New expedition** control takes a seed and asks the player to confirm replacing the expedition and autosave. The same seed reconstructs the same opportunities; changing it changes stars, routes, terrain and deposits together.

## What the new evidence changes in play

The generated planet's irradiance scales its surface solar output, capped at 1.8 times the reference yield to represent a simplified equipment rating. The existing terrain exposure factor multiplies that value. The hub's baseline supply is unchanged, so dim worlds require more arrays or selective suspension of loads. No battery/day-night or radiation-damage simulation is implied.

Ore and ice richness scale the actual finite quantities in the generated landing region. A water-poor place can support useful industry while demanding a different plan for a maintained refuge. Every region uses the same construction costs, recipes, power allocation and service graph. This is the first mechanical link between scouting and the RTS layer.

Pressure, magnetic field and activity are evidence for later planetary engineering. They do not currently impose a calibrated surface dose or decide exposed-life viability. The UI keeps that viability unresolved. The legacy warming/temperature-only seeding shortcuts are disabled on generated terrestrial prospects; a protected refuge is available without claiming global habitability.

## Physical relationships and declared approximations

Received bolometric flux is `S / S_earth = (L / L_sun) / (a / AU)^2`. Planetary radius is derived from chosen mass and bulk density, and relative gravity from `M / R^2`. The displayed atmospheric column estimate is `p / g`, converting bars to pascals and Earth gravities to m/s². Equilibrium temperature uses `278.3 × [S × (1 − albedo)]^(1/4)` K, with whole-sphere redistribution and unit infrared emissivity; it is a radiative reference, not a surface climate prediction. Generated planets do not run the old climate fixture.

G, K and M main-sequence ranges, age bounds, resource priors, costs and a qualitative age/activity law live in `data/prospects.json`. Younger stars tend to be more active in this toy generator, and M-star activity declines on a longer chosen timescale. Those coefficients are gameplay priors, not fitted empirical rates. Actual observations show age and rotation matter for M-dwarf UV emission; type alone cannot specify the radiation environment. [HAZMAT VII](https://arxiv.org/abs/2011.10158)

Synchronous rotation is assigned using a deliberately simple close-orbit scenario rule, not a tidal-evolution solver. It is recorded, not treated as an automatic narrow-ring habitability penalty. Magnetic fields are sampled scenario properties, not outputs of a core-dynamo model. Photons, charged particles and atmospheric shielding remain distinct concepts; no numeric radiation protection score is invented here.

Observing methods resolve different quantities and leave degeneracies. Spectral clues do not certify an ocean or surface pressure. The game compresses instrument capabilities and time rather than simulating a particular telescope's noise or viewing geometry. [NASA: finding and characterising exoplanets](https://science.nasa.gov/exoplanets/how-we-find-and-characterize/)

An appropriate amount of received energy does not establish habitability without the right environment. Our assessment language therefore describes opportunities and unanswered questions, not a green “habitable” flag. [NASA: habitable zone](https://science.nasa.gov/exoplanets/habitable-zone/)

## Time, travel, evidence and saves

Positions lie in a 2D plane and route lengths are Euclidean light-year distances. For new routes, the old 0.07 c cruise fraction and eight-year manoeuvring allowance remain explicit advanced-propulsion placeholders. Fuel and propellant scale linearly with distance; hull wear scales with its square root. These are balancing rules, not a rocket equation or a propulsion energy budget. The original Eir–Vesper journey remains exactly 68 years with its original costs.

Observations record receipt time and the source epoch after subtracting light-travel time from the observer's current system. Local probe receipt and source time agree. Stored evidence stays dated when the ship departs. The underlying generated environmental values are static during this slice, so these epochs do not imply a hidden flare/evolution solver. Remote command delay and refresh programmes for evolving sources remain future work.

Version-three saves contain the generated seed, observation records, the expanded orbital state, fractional year and all surface sites. Worlds regenerate from the saved seed; observations do not leak physical fields they have not measured. Version-one and version-two saves are validated using their original orbital schema before new unexplored systems are added. Invalid evidence timestamps, solar context and site allocations are rejected before any live state is replaced.

Tests cover reproducibility, physical relationships, uncertainty and information access, costs and action preconditions, arbitrary routes and old-site evolution, new surface play, persistent observations, malformed saves, legacy migration, and an actual rendered mouse-driven observatory-to-surface expedition.
