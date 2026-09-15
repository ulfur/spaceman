# Physical space

The chart, system, orbit and region views now inspect a persistent 3D scene. Changing a HUD does not capture a screenshot, replace the planet, or reset its rotation. The inspection camera can cross many orders of magnitude in range while the bodies keep their parent-relative positions and silhouettes.

## Try it

Open **System**, select Eir III and **Approach orbit**. The view opens at the planet-and-moon scale; **Focus** approaches the target and **Planet + moons** restores its neighbourhood. Drag to orbit the camera and scroll or pinch to change range. The scale bar measures distance in the focus plane. Tiny points and labels are navigation aids; the sphere geometry is not inflated to make small worlds look large.

Survey the planet and choose a landing site. The camera approaches the selected geographic hemisphere on the same sphere. Screening layers reveal solar and resource priors; **Visual** retains the physical terminator. See [command navigation](command-navigation.md). Click a location or drag to inspect the other hemisphere. **Locate site** brings the selected coordinates into view. Existing site markers return to the same saved industry. The subsequent ground handoff still opens an isolated 80 m site; it is not a continuous atmospheric descent.

In orbit, **+6 h** makes rotation and illumination easy to inspect. This advances the whole expedition, including unattended industry. The camera follows its subject when time advances; **Day side** moves the camera to a sunlit perspective without altering the lighting. Pausing stops physical rotation. Moving the camera does not advance time, move Spaceship, or consume fuel.

## Full screen

Every workspace has a visible **Full screen** button. Keyboard equivalents are **Control–Command–F** on Mac, **Option/Alt–Return**, and **F11** where the operating system delivers that key. The shortcuts also work with the expedition menu open. The controller changes the actual root window and restores windowed or maximized mode.

An editor-embedded game does not own an independent desktop window. Stop it, disable **Embed Game on Play** in Godot's Game workspace, then run in its own window. The game detects embedding arguments and explains this instead of silently ignoring the request. The standalone command-line equivalent is `godot --path /path/to/spaceman --fullscreen`. Godot's [Window documentation](https://docs.godotengine.org/en/4.5/classes/class_window.html#enum-window-mode) describes native fullscreen, including the separate desktop used on macOS.

## Coordinates and time

- Catalogue positions retain the existing synthetic, flat disc in light years. They are not a reconstruction of the real Milky Way.
- Star-relative positions use AU. GDScript scalar doubles carry coordinates; the renderer subtracts the floating origin before converting to float vectors. Camera range normalizes both positions and radii by the same factor, preserving perspective and angular size without a custom double-precision engine build.
- Circular, coplanar two-body orbits retain explicit parents. Periods are derived from semimajor axis and combined parent/body mass, using Kepler's third law. There are no perturbations, eccentricity, orbital precession, relativistic propagation or stellar proper motion yet. See [NASA's discussion of Kepler's laws](https://science.nasa.gov/solar-system/orbits-and-keplers-laws/).
- `data/celestial.json` supplies authored reference radii, masses, sidereal days and axial tilts. Generated stellar classes supply labelled mass/radius priors. Local probes expose the existing generated planet mass and radius; unprobed worlds and generated moons retain explicitly assumed sizes. The seed defines an orbital phase fit, not an acquired astrometric measurement.
- Body-fixed geographic coordinates use longitude eastward and latitude northward. Synchronous moons keep the same meridian toward their parent. Ordinary rotation follows elapsed expedition hours. Surface axes are east, up and south; transforming the stellar light into that frame makes ground illumination agree with the globe.

## Remaining simulation boundaries

The globe's terrain and clouds are procedural visual reconstructions, not measurements, climate predictions, or a rendering of the ground's industrial mesh. The surface's terrain between sites is not streamed. Existing site seeds, factory positions, deposits, inventories and saves are preserved.

Day/night rendering now follows geometry. Industrial solar generation and testbed irradiance still use their existing mean-exposure budgets. Batteries, diurnal power scheduling, weather, resolved seasons and climate feedback are necessary before instantaneous sunlight can drive those budgets consistently. This change does not pretend to complete that physical model.

Reference bodies are fictional scenario choices. Stellar type alone is not enough to precisely measure stellar mass, radius or a planet's radiation environment. Remote observations stay behind their existing evidence gates; the camera is an inspection tool, not a probe or a transfer trajectory.

## Verification

`test_celestial.gd` checks parent-relative distances, mass-dependent periods, orbit closure, synchronous rotation, geography including seams and poles, illumination, coordinate precision, evidence gates, save continuity and Mac shortcut recognition. The rendered navigation test checks shared mesh continuity and geographic camera approaches, actual lunar separation, geographic picking, matching surface lighting, two retained factories and distant catalogue resolution. `test_display_ui.gd` exercises the visible button and Control–Command–F with a menu open on all six workspaces. CI runs it on both Linux and a native macOS runner.
