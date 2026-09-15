# Spatial expedition

This milestone turns the view stack into a navigable spatial hierarchy and replaces the single fixed surface per planet with persistent geographic worksites.

## Play it

- In **Star chart**, double-click a star or choose **Resolve system**. The system map shows planets around a star and moons around their parent planet. Select a planet and **Approach orbit**. Local controls still require Spaceship to be in that system.
- Survey locally, then **Choose a landing site**. Click the globe to choose coordinates; drag to turn it. Orbital screening estimates compare sunlight, ore and ice. **Reconnoitre this site** opens its terrain. Select the exact seed-module cell on the ground.
- Each landed module consumes one stocked module from the ship. Starting site materials are the module payload; construction cannot use them before landing. Selecting or inspecting another region commits no module.
- **Planet** returns to geographic selection. Existing sites appear as markers and selectable coordinate buttons. Selecting one restores its retained industry and finite deposits. All retained sites advance on the shared expedition clock.
- On the surface, use **WASD / arrows**, **middle or right drag**, and **wheel / trackpad**. Visible **− / + / Home** controls make the camera recoverable. These work while paused; Q/E rotate.
- In the chart, **Galaxy** pulls back to a synthetic galactic disc. Click a location to resolve a field. At local scale, pan and choose **Catalogue this field**. **Spaceship** returns the map camera to the ship. These actions never travel the ship. Transit is still explicitly committed and consumes time, fuel, propellant and hull life.

## World and save model

A 100,000 ly diameter synthetic disc is divided into 12 ly catalogue cells. A requested cell generates six deterministic systems from the expedition seed and signed cell coordinates, independent of discovery order. The existing six prospects keep their exact generation stream. Only requested fields are instantiated and saved; unrequested cells are not allocated. This is a lazy address space, not a claim that a fully simulated galaxy is resident in memory. The current save guard permits up to 10,000 catalogued fields.

Each generated system contains the existing primary terrestrial candidate, its moon, and an outer world at a configurable orbital ratio. Eir gains inner and outer neighbours; Vesper B has an explicit parent. Added bodies use the existing survey, industry, travel and persistence systems. Remote system fits are gated by acquired photometry; environmental values remain hidden until a local probe. Outer-world environments scale irradiance by inverse-square distance but share the primary's atmospheric prior; independent planetary formation and retrieval models are future work.

Geographic candidates use a 72 × 36 grid of five-degree cells. Each candidate identifies an **80 m industrial worksite**, not a simulated five-degree area. Its terrain seed and screening priors derive from the body and geographic address. Candidates currently sample widely separated sites; terrain between sites is not streamed or traversable. The default address preserves the exact legacy terrain and factory location.

Save version 5 retains the selected geographic address, every visited site, catalogued fields and dated evidence. Versions 1–4 migrate without replacing old installations or changing their terrain. Region seed and solar context are validated against their address; invalid data is rejected before replacing live state. New orbital bodies are added during migration after the old schema validates.

## Motion and approximations

View transitions magnify the previous rendered view around the selected world, while the incoming world settles into place. The new interface remains at its final size. A transition blocks repeated navigation input and does not advance the authoritative clock. Presentation uses a bounded 0.72 s tween, not simulation years.

System orbits are circular, coplanar fits projected obliquely. Planetary periods use Kepler scaling with a spectral-class mass prior; reference orbits are authored. Positions follow expedition time, not presentation frame time. Radial spacing is logarithmically compressed and moon orbits are enlarged, as stated on the map. This is not an N-body integrator or precise ephemeris.

The galactic image is a schematic density backdrop, not an observed Milky Way catalogue. Individual actionable stars come from actual generated records. Galactic coordinates and travel costs share the same light-year frame. Immense distances are costly under the existing sublight travel model; map access does not grant instant travel.

Latitude affects a labelled annual solar screening proxy and ice priors. It does not model obliquity, seasons, tidally locked illumination patterns, weather or regional heat transport. Globe terrain is a visual reconstruction, not a stitched rendering of the local industrial meshes.

## Verification

`test_atlas.gd` covers independent regional terrain and factories, module accounting, shared clocks, malformed-address rejection, save migration, catalogue expansion, remote evidence, discovery-order determinism and parent/child orbits. `test_navigation_ui.gd` exercises rendered scale changes, globe-coordinate picking, two actual footholds, return markers, paused mouse/keyboard camera control and distant catalogue selection. Existing orbital, surface, prospect and testbed walkthroughs remain CI gates. Transition frames are captured at a fixed 20 simulation frames per second so the camera motion can be reviewed independently of software-renderer throughput. Frames and screenshots are retained with the workflow artifacts.

The next spatial milestone is continuous terrain streaming, cross-chunk industrial expansion and planet-scale camera travel. It should extend these addresses rather than introducing a second decorative world.
