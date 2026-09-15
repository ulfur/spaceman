# Science and open-ended simulation

Design research, September 2026. This develops the intended game; it does not describe implemented physics. The original First Rain model remains a deliberately simplified test fixture.

Implementation update: [Testbeds](testbeds.md) now exercises selected principles in a bounded chamber—gas inventory, thermal inertia, water phase changes, distinct shielding and biological requirements. Its documented approximations are narrower than the longer-term models proposed below.

## Governing principle

Use the best tractable scientific model that produces understandable decisions. Simplify resolution and presentation before discarding mass, energy, causality, or relevant timescales. State the domain and limitations of each approximation.

The campaign is an open-ended expedition simulation. The player identifies promising systems from distant evidence, decides where to travel, investigates on arrival, develops an intervention, builds its industrial foundation, observes the response, and chooses whether to persist, revise, leave, or return later. There is no required sequence of planets and no prescribed set of three correct solutions.

Reproducible simulation and open-ended play are compatible. Seeded systems and deterministic rules support debugging and saves; they do not prescribe the player's solution. Variety comes from correlated initial conditions, incomplete knowledge, interacting systems, and player choices. Any stochastic processes must represent a stated mechanism and use saved random state, not arbitrarily reward or punish an otherwise sound plan.

## Three levels of confidence

| Category | Meaning | Examples |
| --- | --- | --- |
| Established principle / demonstrated process | The underlying effect is observed or experimentally demonstrated; performance still depends on conditions. | Spectroscopy, radiative heating, electrolysis, extraction, mass transport, atmospheric chemistry. |
| Speculative engineering | Physically motivated, sometimes published, but planetary implementation is not demonstrated. | Vast sunshades, artificial upstream magnetic shields, planetary current loops, high-throughput atmospheric manufacturing. |
| Uncertain planetary intervention | Both engineering feasibility and the eventual planetary response are highly uncertain. | Attempting to alter a core dynamo through interior engineering or a giant impact. |

The interface must distinguish uncertainty about the world from uncertainty about the model or technology. More scans can constrain an atmosphere; they cannot turn an unproven engineering hypothesis into a guaranteed outcome.

## Discovery before arrival

Different instruments reveal different properties. Transits can constrain orbital periods and relative size; stellar models are needed to infer radius. Radial velocity constrains mass with inclination dependence. Direct imaging and spectroscopy provide other evidence subject to geometry, glare, clouds, and signal quality. A non-detection is not proof of absence, and spectral water does not prove a surface ocean. [NASA: finding and characterising exoplanets](https://science.nasa.gov/exoplanets/how-we-find-and-characterize/)

The following observation progression is a game-design proposal informed by those methods:

| Stage | Useful evidence | Important unknowns |
| --- | --- | --- |
| Stellar catalogue | Distance, spectrum, brightness, observed activity; existing candidate detections. | Undetected planets, long-period orbits, unobserved stellar behaviour. |
| Dedicated distant observation | Improved orbital solutions; size/mass constraints where observable; atmospheric spectral hints. | Actual surface conditions, pressure/composition degeneracies, precise water inventory, accessible resources. |
| Approach and local probes | Resolved geography, changing illumination, mapping of exposed minerals/ice, local fields and radiation. | Buried resource grades and volumes, subsurface chemistry, deep interior structure, whether life is present. |
| Surface survey | Local ground truth: deposit grade/depth, chemistry, terrain, heat flow, hazards and environmental samples. | Unsampled regions and poorly constrained interiors. |
| Pilot intervention | Measured response to a small experiment and a better-calibrated local model. | Long-term feedbacks and whether scaling up changes the response. |

Every consequential observation should carry method, timestamp, coverage, and a measured/inferred/unknown status. Report useful uncertainty intervals rather than false precision. Distant planet artwork is an explicitly labelled reconstruction until mapping resolves geography. Future remote updates travel at light speed; observations and commands are both delayed, and autonomy must cover the interval.

Observation consumes instrument availability, power, integration time, and possibly probe hardware. It should sometimes be worth spending longer looking before committing to a century-long journey. Failed terraforming prospects may still be valuable research, mining, or refuelling destinations.

## What makes an environment viable

The habitable zone describes where surface liquid water could exist given a suitable atmosphere; it is not a certificate of suitability. Stellar spectrum and activity matter in addition to received energy. Subsurface environments need their own criteria. [NASA: habitable zone](https://science.nasa.gov/exoplanets/habitable-zone/)

Keep at least these coupled quantities conceptually separate:

- Stellar flux, spectral distribution, orbital variation and exposure.
- Rotation, axial tilt, tidal state, seasons, and regional heat transport.
- Atmospheric mass, composition, pressure, clouds, temperature and loss/sink processes.
- Gravity and volatile inventory; water phase, availability and regional distribution.
- Charged-particle environment, ionising photons, surface radiation and shielding.
- Accessible energy, carbon and other required elements, nutrient cycling, and the requirements of the selected organisms.

There is no generic invulnerable microbe. Different organisms need different energy sources, chemistry and environmental ranges. Human breathability is a substantially different target from microbial persistence or a productive ecosystem. Growth must eventually encounter limitations and recycle material. [McKay: requirements and limits for life](https://pmc.ncbi.nlm.nih.gov/articles/PMC4156692/)

Natural magnetism and rotation should not become binary eligibility switches. Venus retains a dense atmosphere without an internally generated magnetic field; it has an induced field, yet is hostile to Earth-like surface life. [NASA: Venus](https://science.nasa.gov/venus/venus-facts/)

Tidal locking can produce different regional climates. Terminator habitability is one outcome, especially in some water-limited models; water-rich cases can have larger viable areas. Oceans and atmospheres can redistribute heat. [Lobo et al.](https://arxiv.org/abs/2212.06185), [Yang et al.](https://arxiv.org/abs/1902.02103)

## Stars, radiation and protection

Magnetic protection matters: a suitable field can deflect charged particles and reduce some exposures. It is not an all-purpose radiation shield. Keep ordinary stellar wind and CME plasma, energetic particle events, flare UV/X-ray photons and the galactic cosmic-ray background separate. Atmosphere, local shielding and magnetic geometry act differently on these channels. Surface dose depends on incident particle energies, atmospheric column and secondary particles, not merely a binary field flag. [Atri: stellar proton events and surface dose](https://arxiv.org/abs/1910.09871)

Star type is an important input, not a danger rating. Model luminosity and spectral distribution alongside age, rotation/activity and measured variability. Early M-dwarf observations show UV emission evolving with age and rotation; two stars with the same spectral classification need not offer equivalent conditions. Avoid both “all red dwarfs are lethal” and “habitable-zone distance makes the star safe.” [HAZMAT VII](https://arxiv.org/abs/2011.10158)

Use atmospheric column mass, approximately pressure divided by gravity, when evaluating shielding; composition also matters. A magnetic field does not directly stop UV or X-ray photons. Burial, water/regolith shielding, protected refuges, radiation-hardened equipment and operational precautions therefore remain useful alongside any artificial field. No single shield makes every exposure harmless. [NASA: space-radiation protection](https://science.nasa.gov/science-research/heliophysics/how-nasa-will-protect-astronauts-from-space-radiation-at-the-moon/)

Gameplay interpretation: observe the star before departure; improve event statistics with monitoring; distinguish peak events from chronic exposure; compare protected local life with an exposed surface biosphere. Field infrastructure, atmospheric processing and sheltered habitats are competing or complementary investments. Flares and long-term atmospheric evolution must operate on their own timescales, not arbitrary instant planet death.

## Engineering possibilities and their limits

### Local industry and atmospheric processing

Start with extraction, sorting, refining, reactors or solar power, transport, fabrication, and chemical processing. Track inputs, outputs, by-products, power, waste heat, equipment wear, and throughput. MOXIE demonstrated extracting oxygen from Martian carbon dioxide at gram-per-hour scale. Planet-scale processing is an enormous extrapolation, not a demonstrated capability. [NASA/JPL: MOXIE](https://www.jpl.nasa.gov/news/nasas-oxygen-generating-experiment-moxie-completes-mars-mission/)

Atmospheric pressure requires actual gas inventory. As an illustrative hydrostatic estimate for a thin atmosphere with approximately constant gravity:

\[
M_{\mathrm{atm}} \approx \frac{4\pi R^2 p}{g}.
\]

Using chosen round inputs of radius 6,371 km, pressure 100 kPa and gravity 9.81 m/s² gives about 5.2 × 10¹⁸ kg. This is an order-of-magnitude accounting example, not an Earth atmosphere reconstruction or a terraforming forecast. A plant producing 1,000 kg/s continuously would take roughly 165 million years to supply that mass before losses. This explains why inventory, throughput and scope must drive the game.

The accessible native CO₂ inventory on Mars is insufficient for the specific global CO₂ terraforming route evaluated by Jakosky and Edwards using present-day technology. That conclusion does not rule out every conceivable future intervention. It does rule out treating a shield or a small factory as a source of missing material. [NASA account of the inventory study](https://www.nasa.gov/news-release/mars-terraforming-not-possible-using-present-day-technology/)

### Radiative control and volatile management

Possible families include changing albedo, greenhouse-agent production, shade or reflector infrastructure, controlled volatile extraction/import, and local enclosed or sheltered ecosystems. Warming, increasing pressure, providing breathable chemistry, and establishing nutrient cycles are different tasks. A mirror can alter absorbed energy without supplying atmospheric mass.

Every project needs both an initial build/fill budget and a continuing maintenance budget. Agent lifetimes, condensation, chemical reactions, leakage and sequestration can undo an intervention after its machinery stops. A 2026 systems-analysis preprint usefully compares atmospheric mass, radiative forcing, industrial throughput and persistence; its feasibility bounds are not validated climate predictions. [Turyshev: mass, forcing and throughput constraints](https://arxiv.org/abs/2603.00402)

### Artificial magnetic environments

Magnetic fields affect charged particles and escape channels. Their net effect depends on geometry and conditions; stronger intrinsic magnetism does not universally mean lower total atmospheric escape. Model charged particles, photon exposure and atmospheric chemistry separately. [Gunell et al., 2018](https://www.herbertgunell.se/pdfpapers/GMNSSLHD18.pdf)

| Proposed method | What it could change | What the game must account for |
| --- | --- | --- |
| Buried power plants driving artificial coils | A deliberately engineered field with an actual geometry and coverage. | Conductors, current, cooling, structural stresses, power provision and maintenance. Merely burying a generator does not make a natural dynamo. |
| Upstream shield near star–planet L1 | Some charged-particle interactions and associated atmospheric-loss processes. | Position/orientation, plasma conditions, reliability, construction and continuing operation; no automatic atmosphere creation or UV protection. |
| Planetary or orbital current loops / driven plasma structures | A large artificial magnetic environment. | Planet-scale dimensions, conductor or plasma mass, field configuration, injectors or cooling, construction and failure modes. |

An upstream Mars shield has been explored in a NASA-led 2017 conference abstract. Treat it as a speculative proposal, not a technology readiness claim or a promise of restored atmosphere. [Green et al., 2017](https://www.hou.usra.edu/meetings/V2050/pdf/8250.pdf)

Published work also explores superconducting structures and driven plasma arrangements for artificial magnetospheres. These are engineering investigations, not demonstrated planetary shields. [Bamford et al.](https://arxiv.org/abs/2111.06887)

A natural dynamo requires sustained conducting-fluid motion and appropriate thermal/compositional driving. A molten core by itself does not establish that. Interior intervention would require information about heat flow, stratification and composition; adding surface heat or electricity is not a simple restart command. [NASA: geodynamo research](https://science.gsfc.nasa.gov/earth/geodesy/researchareas/136/)

Shield failure must not trigger arbitrary rapid loss of a massive atmosphere. Integrate mass loss against the inventory at rates appropriate to the star, planet and epoch. Loss, climate and ecological timescales differ.

### Redirected bodies and giant impacts

Transporting volatiles and crashing them into a planet are different operations. Impacts may deliver some material while heating the world and eroding its atmosphere. Outcome depends on mass, composition, speed, angle and target properties. Simulation results and scaling laws have a defined regime; do not apply one giant-impact formula indiscriminately to every comet. [Kegerreis et al.: atmospheric erosion by giant impacts](https://arxiv.org/abs/2007.04321)

An explicit illustrative calculation using \(E=\tfrac12mv^2\): a 1 km-radius rocky body at density 3,000 kg/m³ has mass about 1.26 × 10¹³ kg; at an assumed 10 km/s it carries 6.28 × 10²⁰ J. A hypothetical 10²⁰ kg moon at that speed carries 5 × 10²⁷ J. These are impact energies, not redirection budgets or estimates of energy reaching the core. Speeds must be consistent with gravity and any braking manoeuvre.

There is a research hypothesis that sufficiently energetic impacts can mix stratified planetary cores and change dynamo prospects. It is not a reliable engineering recipe. [Jacobson et al.: core formation and mixing](https://arxiv.org/abs/1710.01770)

The design interpretation is an extreme planetary reset: heat, volatile loss/delivery, spin, debris, orbital consequences and possible destruction of an existing biosphere. Any later dynamo outcome is uncertain. Mining and controlled transport should remain competing methods. A convenient moon is not a guaranteed magnetic-field upgrade.

## Spaceship and the cost of travel

Preserve the original fusion-powered ion/plasma propulsion ambition, but treat percent-of-light-speed operation as advanced speculative engineering requiring a credible power and mass budget. Existing ion propulsion is real: Dawn's xenon exhaust reached about 90,000 mph (roughly 40 km/s), far below the prototype's cruise speed of about 21,000 km/s. Exhaust speed is not a hard maximum ship speed, but the required mass ratio matters. [NASA/JPL: Dawn ion propulsion](https://www.jpl.nasa.gov/videos/crazy-engineering-ion-propulsion-for-the-dawn-mission/)

Before assigning final ship statistics, relate exhaust velocity, thrust, reaction mass, reactor power, waste-heat rejection, acceleration and braking. Use a rocket-equation approximation only within its stated regime. Model ship mass and payload effects, and state any assumed breakthroughs in specific power or exhaust performance. If a direct-fusion exhaust architecture fits better, make that an explicit future design choice.

For scale, the nonrelativistic kinetic energy at 0.07 c is about 2.2 × 10¹⁴ J per kilogram of moving mass. That is only a lower-order kinetic-energy estimate; it excludes reaction-mass acceleration, inefficiency and braking-system requirements. The current fixed transit costs and eight-year manoeuvring allowance are placeholders, not a validated engine design.

## A useful simulation architecture

Generate correlated systems: star properties constrain illumination and evolution; planet mass, radius and composition constrain gravity; orbital/rotational geometry drives exposure; volatile inventory and climate determine where water can persist. Resource accessibility follows geology and local conditions rather than independent random bonuses.

Keep physical state, observed evidence, the player's current model and standing orders separate. A new survey updates evidence and forecasts. It does not reroll the world. Forecasts explain assumptions and limiting factors and can change after a pilot experiment.

Use regional environmental state and spatial industrial networks, with one timeline. At low speed, show individual surveys, construction and hauling. At high speed or off-screen, integrate aggregate capacity while preserving queues, transport delays, energy limits, inventories, maintenance and failure triggers. Long advances should stop at relevant events; switching views must not create free throughput.

Expose enough detail to understand causes. A stalled project should explain its power deficit, unavailable element, transport bottleneck, bad environmental assumption or depleted reserve. The player should be able to improve a model, change an industrial plan, try a smaller ecological foothold, leave a research station, or abandon the destination.

Success can mean a persistent microbial refuge, a nutrient-cycling ecosystem, a fertile region, a stable planetary atmosphere, an autonomous industrial outpost, or new knowledge. More ambitious outcomes emerge when the necessary conditions are satisfied. They should not require a hidden mission script.

## Next experiment

First prove the reusable surface-industry implementation in one bounded 3D sector. The following slice should introduce several candidate systems and uncertain distant observations, then contrasting worlds under the same rules and pilot interventions. Authored scenarios remain valuable regression tests, not the campaign's prescribed answer set. See the [development roadmap](roadmap.md) for sequencing.

Acceptance questions: Can observation alter the destination choice? Can two players pursue different viable plans? Can a small local ecosystem be worthwhile? Can poor prospects be rationally left behind? Can the player explain why a project changed while they were away? Can a new seed produce a different expedition without writing a new solution script?
