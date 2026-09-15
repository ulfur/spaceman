# Testbeds — planetary-engineering pilot

This milestone makes the first environmental intervention playable at a scale the surface industry can affect: a sealed 16 m², 32 m³ field chamber. Build it, change its environment, introduce an archive culture, inspect its response, and decide whether to maintain, revise or abandon the experiment. It runs inside the existing surface simulation during every view, orbital wait and interstellar journey.

A successful chamber is evidence about a maintained local environment. Global atmospheric manufacturing, regional circulation, open-ground ecosystems and a full planetary-engineering view remain later work. Planetary gas inventory is enormous compared with pilot throughput; a small factory cannot simply add a bar to a world. [NASA: atmospheric inventory limits on Mars](https://www.nasa.gov/news-release/mars-terraforming-not-possible-using-present-day-technology/)

The [interface pass](interface.md) describes the current screen hierarchy and contextual controls.

## Play

Use a locally probed generated prospect. First Rain's authored Eir climate retains its original rules; it does not supply this new environmental model.

1. Land a module and build sufficient power on the surface. An ore extractor supplies shielding material; refining and fabrication can replenish service parts.
2. Choose **Build → Life support → Field testbed [9]** and place it on the service network. It costs 30 metal and 5 components, with 16 base construction hours adjusted by service efficiency.
3. Select the finished chamber and choose **Open field trial**. **Climate**, **Shielding** and **Culture** group the controls; measurement tabs switch between the chamber and its history.
4. Inspect outside conditions. Configure the thermal controller, gas train, water feed, lighting and shielding. Advance time and inspect temperature and pressure before using an archive packet.
5. **Inoculate** consumes one ship archive packet. A trial is recorded as established after at least 20 g of live culture and seven consecutive days within its screening limits. Culture can subsequently die; the recorded achievement is historical.

The rendered walkthrough uses neighbourhood 1701 and Aster b. Auto thermal control at 288 K, a regulated 0.3 bar atmosphere, water feed, grow light and a regolith canopy produce a viable enclosed trial there. This is an example under the same rules as the other generated worlds, not a required route. A canopy without powered lighting can starve the culture of usable light.

| Control | Consequence |
| --- | --- |
| Passive / Heat / Cool / Auto | No active heating, full 4 kW heating, cooling at 4 kW electrical input with COP 0.7, or bounded thermostat control |
| Temperature presets | Change the Auto setpoint; actual temperature moves through thermal inertia |
| Gas regulator: on / sealed | Run native-gas intake, venting and CO₂ separation, or close the isolation valves |
| Pressure presets | Select total chamber pressure, including water vapour; pumping has finite throughput |
| Water feed | Deliver up to 1 kg/h from surface water into the chamber's 20 kg total water inventory |
| Grow light | Reserve 0.8 kW; supplies photosynthetically usable light and heat |
| Roof shade | Reduce absorbed sunlight and UV; it does not deflect charged particles |
| UV filter | Costs 4 metal + 1 component and takes 8 operating hours; reduces UV while retaining most modelled usable light |
| Regolith canopy | Costs 4 ore + 8 metal + 2 components and takes 16 operating hours; supplies 250 kg/m² of nominal mass shielding and blocks most light |
| Chamber / Temperature / Pressure / Culture | Switch between equipment and a measured history graph; samples are retained every six logical hours |
| Pause / 1× / 10× / 50× | Logical hours per real second, shared with the surface |
| +24 h / +7 d | Advance the same expedition and every existing site |

**Space** pauses/resumes. **Escape** returns to the surface paused; **F11** toggles fullscreen. Several chambers can run different experiments on the same site and compete for the same network and supplies.

## Industrial and material accounting

A completed testbed reserves its maximum configured electrical load: 0.5 kW auxiliaries, up to 4 kW thermal equipment, 1 kW gas processing and 0.8 kW lighting. Existing construction-order power arbitration determines whether it receives that reservation. The energy counter records the controller's actual thermal electrical use plus configured auxiliaries, lighting and gas-processing draw. Unused reserved capacity is not dynamically reassigned yet.

Operation consumes 0.002 tonnes of surface components per hour as service parts, plus up to 0.05 kg/h of available liquid water as a flushing stream. These maintenance rates and the existing industrial tonnes/recipes are gameplay equipment budgets, not validated engineering specifications. Water transfers explicitly convert surface tonnes to chamber kilograms. Construction and upgrades debit actual surface inventory; an upgrade takes operating time after the debit.

The chamber initially encloses native N₂/CO₂ gas. Its gas train has finite molar throughput, reduced at low outside pressure. A separator can concentrate native CO₂ into the chamber or move excess CO₂ to a captured store. Intake, exhaust, captured carbon, water input and water waste are accounted independently. Gas separation and compression use a fixed equipment power budget; detailed process efficiency and heat recovery are not solved.

Disabled or unpowered process valves close. This milestone assumes an intact, airtight hull when isolated. Heat exchange, water phase changes and biological response continue without actuators. Hull punctures, permeability, structural failure and hardware ageing are future models; loss of service parts does not magically vent the chamber.

## Physical model

`testbed_simulation.gd` contains no scene-tree state. Its dictionary lives in the surface structure. `testbeds.gd` issues session commands and `trial_diagram.gd` displays current measurements and history. The visible 3D chamber, canopy and culture belong to the same structure on the RTS surface.

Pressure is `pV = nRT`, summing moles of inert nitrogen, CO₂, oxygen and water vapour. Temperature is absolute kelvin; volumes and masses are explicit. The pressure controller moves gas mass instead of assigning pressure directly. [NASA Glenn: ideal-gas equation of state](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/equation-of-state-ideal-gas-2/)

The thermal model uses a lumped 8 MJ/K heat capacity, heat exchange proportional to the inside/outside temperature difference, and an effective Stefan–Boltzmann radiative term. The radiative sink is the planet's equilibrium-temperature reference. Solar input uses bolometric stellar flux, a quarter-sphere mean, local exposure, roof transmission and shade. Lamps add heat; photosynthesis diverts some absorbed energy into chemical storage. A bounded implicit hourly solve avoids the instability of a large explicit `T⁴` step. All equipment/opacity coefficients are approximations; sensible heat carried by small material transfers is neglected.

Water partitions between condensed inventory and headspace vapour using a constant-latent-heat Clausius–Clapeyron approximation anchored at the water triple point. Sublimation uses a different coefficient below freezing. The energy solve includes vaporisation and fusion; melting/freezing is smoothed over one kelvin for numerical continuity. Water vapour contributes to pressure and can leave through the operating gas train. Condensation returns its mass to the chamber. This is a pure-water equilibrium approximation: salts, humidity gradients, nucleation, cloud dynamics and detailed non-ideal fluid properties are omitted. [NIST: fluid-property reference](https://webbook.nist.gov/chemistry/fluid/)

The generated ambient temperature is a grey-atmosphere screening estimate derived from the previous equilibrium temperature and a prescribed infrared optical depth. A synthetic native CO₂ mole fraction determines its atmospheric CO₂ column; the balance is nitrogen. These traits use a separate seeded stream, preserving the earlier routes, terrain and deposits. Local probe evidence exposes composition and the temperature estimate; distant catalogue views do not reveal them. This is not weather, a spectral retrieval, a runaway-greenhouse solver or a resolved climate map. Atmospheres alter outgoing thermal radiation; equilibrium temperature alone is insufficient to predict a surface environment. [NASA: greenhouse effect](https://science.nasa.gov/climate-change/faq/what-is-the-greenhouse-effect/)

## Radiation and biological limits

UV and particle exposure remain separate **screening indices**, with no sievert units or calibrated biological-dose claim. Stellar activity, bolometric flux and atmospheric column influence them. A favourable magnetic-deflection assumption changes only the particle term, which also contains a cosmic-ray component. Atmospheric and canopy attenuation use illustrative exponential scales. This is neither particle transport nor a universal law relating magnetic strength to protection or atmospheric retention. Real exposure depends on radiation energy, geometry, shielding and secondary particles. [NASA: space-radiation protection](https://science.nasa.gov/science-research/heliophysics/how-nasa-will-protect-astronauts-from-space-radiation-at-the-moon/)

Star class and age enter through Prospects' qualitative activity prior; spectrum-dependent radiative transfer, flares, seasons, rotation and regional heat transport are not integrated here. Solar photosynthetic light currently uses a fixed 45% fraction. The mean-forcing sector does not resolve a synchronous world's day/night contrast or certify a narrow habitable ring.

The archive culture is a deliberately specified gameplay phenotype, not a claim about a named terrestrial organism. Its temperature, CO₂, light, exposure and nutrient limits are data. Organic material is represented by the rounded formula CH₂O: production consumes CO₂ and water and produces organic mass and oxygen in the mass ratio `44 + 18 → 30 + 32`. Mineral nutrients transfer into a bound pool. Growth is limited by existing culture, available light/chemical energy, carbon, water, nutrients and chamber capacity. Dead material remains detritus. Respiration, decomposition, toxins, ecological competition and nutrient recycling are not simulated, so a successful trial is not proof of a self-sustaining ecosystem or human breathability.

## Time, saves and verification

Version-four saves preserve chamber material inventories, thermal state, orders, upgrades and measured history. Original orbital, First Foothold and Prospects saves migrate. Validation rejects unaccounted mass, invalid controls and observations from the future before replacing any live state.

All sites use the same hourly update during scans, surface time, orbital work and travel. A stationary interval can be skipped only after a physically unchanged hour, with equivalent regularly spaced historical samples. A testbed prevents the older refuge-only maintenance shortcut. Logical clocks and inventory accounting remain authoritative; remote experiments cannot be opened or directly controlled until the ship returns.

The test suite covers ideal-gas behaviour, separate shielding channels, thermal inertia, water phase/latent energy, photosynthetic mass balance, resource and archive allocation, finite upgrades, power loss, biological death, save continuity, malformed data, historical sampling, previous save migration and full unattended transit. The rendered walkthrough builds a real chamber, establishes a culture through its controls, removes lighting under a canopy, and returns to the physical site to observe the consequences. CI exports Web and Linux builds; interaction tests exercise native Godot under Xvfb.
