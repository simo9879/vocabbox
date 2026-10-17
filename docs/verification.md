# Prototype verification — 15 October 2026

## Delivered build

`builds/linux/play.sh` launches the exported `vocab-box.pck` with a bundled Linux x86_64 Godot 4.7.2 executable. It needs no installed speech engine or Godot editor. It is a portable engine-plus-pack build, not a release-template executable: matching export templates were unavailable. Legacy models are excluded. Godot and third-party notices are bundled.

This packaged build predates the player model change below. Its route, visual, and frame-rate results do not measure the imported character.

## Automated checks

- **523 assertions passed against both editable source and the exported pack.** These cover encounter/response validation, feedback, all 27 quality combinations (including failed retries), assistance thresholds, ordered entry/worker/produce/customer/checkout progression, duplicate bananas, finalization, optional checkout improvement, all star thresholds, reset, save maximum, malformed saves and all 37 voice references. A regression check confirms all six objectives and hints survive export.
- **Full physics-driven route passed against source and the exported pack.** The test uses ordinary Input Map movement and proximity checks, selects live UI buttons, and traverses city → supermarket → results → city. It also exercises two failed worker attempts, closing/reopening dialogue, assisted choice, optional stronger checkout, restart, cancel/confirm leaving, settings sliders and replay state.
- Camera ray/spring collision against the market wall and both vertical rotation clamps passed in the exported-pack route test. Bird follows throughout the walk; collision shapes do not include the bird.
- 41 generated mono WAV files validated: 37 spoken clips plus two ambient beds, footsteps and an interaction tone. Resource lookups passed. Speech uses a single interruptible player; answer clips only start from their replay buttons. Voice references and subtitles use the same authored text.
- Tests use isolated data directories under `/tmp`; they do not alter the player's normal save. Test failures produce a nonzero process exit code.

During packaging, the host engine's binary resource conversion produced empty packed string arrays for objectives/hints. Replacing those fields with indexed dictionaries preserved the editable resource data; the exported resource regression check now passes. Earlier headless shutdown audio warnings were eliminated in the route harness by stopping audio and allowing the audio server to settle before quitting.

## Desktop playthrough and visual checks

Completed a separate **keyboard-and-mouse playthrough of the packaged build at 1280×720**, using desktop input events and screenshots rather than directly invoking mission transitions: Play → walk to market → introduction → Alex → bananas → Sam → Jo → three-star results → scroll results → return to city. Tested a choice replay, normal dialogue closing with Escape, results scrolling and settings navigation. No runtime errors appeared in the desktop log.

Changed voice volume to 50%, closed the application, then launched a new process. Title displayed **3 / 3 best stars**; the saved voice preference remained **0.5**. The fresh launch starts from the title rather than resuming the unfinished world.

Inspected dialogue, city, shop and results at actual **1920×1080 captured image dimensions**, and 720p UI in the manual build. Live resizing to **1000×800** preserved controls with letterboxing. At 720p, all three answer rows and the close button fit simultaneously; the longer results page scrolls. Large feedback text wraps inside the panel. HUD and subtitles have dark backing for contrast; subtitle and interaction regions are separated.

Screenshots: [city](screenshots/city-1080.png), [shop](screenshots/shop-1080.png), [dialogue](screenshots/dialogue-1080.png), [results](screenshots/results-1080.png), [resized settings](screenshots/settings-resized.png), [fresh-launch saved stars](screenshots/saved-stars.png).

## Test hardware and performance

- Desktop: Fujitsu ESPRIMO P910, Intel Core i7-3770 @ 3.40 GHz.
- GPU: Intel HD Graphics 4000 (IVB GT2), Mesa 25.2.8, OpenGL 4.2 Compatibility renderer.
- RAM exposed: 14,156,556 kB; Linux kernel 7.0.0-31-generic.
- Godot: 4.7.2.stable.official.ed1daf0bf.
- Final 1080p route: **805 sampled movement frames, median 60.0 FPS, 10th percentile 57.84 FPS.** This is near the 60 FPS target, not a claim of a locked 60 FPS minimum. Samples use the reciprocal of process-frame delta while moving, excluding transitions/menu waits; this is a short route benchmark, not a long-duration soak test.
- Initial unoptimized 720p route was around 28 FPS. Static shape batching, lower-poly procedural spheres and inexpensive contact shadows replaced costly real-time directional shadows. That tradeoff is intentional for the host's integrated GPU.
- The desktop initially resized oversized windows to fit its 1680-pixel display. Final performance measurements forced the minimum window size and verified saved images were truly 1920×1080; earlier fitted-window results were not counted as 1080p acceptance evidence.

## Limits

Speech is temporary eSpeak NG synthesis, not professional narration. Automated playback/resource checks and desktop replay controls were exercised; no human listening-quality review or child usability study was performed. The intended 5–10 minute first visit has not been measured with children. Art is deliberately simple original procedural artwork. Results use scrolling on smaller windows. The desktop bundle includes the larger editor-capable engine runtime because release export templates were not installed. Windows/macOS exports, controllers, touch/mobile performance and AI/speech recognition remain unverified or outside this prototype's scope.

## Player model change — source check

- The two-shoe derivative of the Fab character was inspected in a Blender color render. Rotating either foot bone moved its matching shoe while leaving the other shoe nearly stationary. Its Mixamo FBX was reimported into Blender with one 259-bone armature and both shoes attached.
- Godot 4.7.2 imported `AsianBoy_player.glb`, loaded the active player scene, and started the main scene in headless mode without a project script or asset-load error. The sandbox blocked Godot's user log/editor-settings writes; those errors did not stop the scene load.
- A temporary Linux export pack included the imported player scene, model, and texture dependencies. Godot started that pack headlessly without a scene or asset-load error.
- These were asset and headless startup checks before animation integration. The source has not had a rendered Godot playthrough or frame-rate measurement since the player model change.
- Mixamo rejected the first rigged FBX with “unable to map your existing skeleton.” The replacement `tools/mixamo/AsianBoy_unrigged_for_Mixamo.obj` was exported from the existing body mesh and inspected locally: one OBJ object, 16,466 vertices, 28,362 faces, no skeleton or material references, and a 2.122 m tall bounding box. Mixamo accepted that donor: the project owner supplied `Idle.fbx` and `Walking.fbx` exports.

## Player animation integration — asset inspection

- Blender imported both Mixamo FBXs. Idle spans frames 1–251 at 30 FPS; Walking spans frames 1–27 at 30 FPS. `tools/retarget_asian_boy_mixamo.py` transfers rotations from 52 matched Mixamo bones to the original skeleton and omits Mixamo hip translation so Godot remains responsible for movement. It removes 1,170 concealed body faces beneath the shirt to prevent visible skin clipping during bends.
- The exported `AsianBoy_animated.glb` contains the complete ten-mesh character, one skin, and named Idle and Walking clips. Godot imported it, and the player scene's AnimationPlayer exposes both clips at about 8.37 and 0.9 seconds. `scripts/player.gd` loops them and switches with a short blend based on ground speed.
- Blender renders of an [idle frame](screenshots/player-idle.png) and a [walking frame](screenshots/player-walking.png) were inspected. The large skin patches that initially appeared through the shirt were removed. A small mark remains on the white shirt. No rendered Godot playthrough, animation timing assessment in the actual game, frame-rate measurement, or Windows export has been done for this change. The Godot editor import reported only sandbox errors when writing user editor settings and opening its local socket.

## Pip model integration — asset inspection, 17 October 2026

- The supplied Yellow Chick archive contains rigged FBXs, the base-color atlas, and author instructions specifying 24 FPS. Godot 4.7.2 imported the Idle, Fly, and Feed FBXs for conversion; Blender 3.6 could not import the original FBX rig hierarchy directly. The converted GLB is about 1.4 MB and contains nine mesh parts, the embedded color atlas, and named Fly, Idle, and Talk clips.
- Blender renders of the converted Idle, Fly, and Talk poses were inspected. Feed's original whole-body motion bent the chick toward the floor, so Talk now uses only its beak rotations over Fly's wing motion. A Talk frame was inspected after this change and showed Pip airborne with raised wings. Fly's source root rise was removed after it placed the chick far above its scene origin in the render. Godot imported the current winged Talk GLB into the editable project.
- No rendered Godot gameplay, full-route check, measured frame rate, or Windows export was performed for the Pip change. The prior packaged Linux build and screenshots predate both imported character changes.

## Pip loop correction — asset inspection, 17 October 2026

- The FBX Fly tracks contained keys through 9.33 seconds even though the intended motion ends near 4.08 seconds. The earlier GLB exported those extra keys, leaving the wings motionless for several seconds. The converter now removes keys outside each clip range. An intermediate GLB's Fly keys spanned 0–3.96 seconds; Godot imported it with a 3.96-second animation length.
- Godot's glTF importer reports the animation as nonlooping. `bird.gd` sets Fly and Talk to repeat at runtime and restarts the selected clip if playback stops. This correction was checked through asset timing and editor import; a rendered in-game replay has not been performed.

## Pip wing-cycle crop — asset inspection, 17 October 2026

- The full Fly source includes a transition from idle into flight and back to idle. Its middle frames 41–65 form a one-second wing cycle: the two wing roots differ by about 0.04° at the endpoints, and their preceding frame-to-frame rotation steps match closely. The converter now samples only that interval and blends the final four frames toward the first pose for smaller head and foot differences.
- The rebuilt Fly and Talk clips both import into Godot at 1.0 second. Blender renders of Fly at frames 0, 12, and 24 showed an airborne pose throughout and matching first/last images. A Talk frame showed the same wing motion with the beak open. No rendered in-game loop or gameplay performance measurement was performed for this crop.

## Kenney city shop exteriors

- `city_shops.tscn` uses three Kenney City Kit Commercial GLB buildings with authored collision, signs, and the existing market and closed-shop interaction IDs. The supplied archive contains its CC0 `License.txt`.
- Earlier city screenshots and packaged-build results show the previous generated façades, not these models.
- The owner manually observed that the first imported shop scale made the player larger than the door. The three building instances and their collision and interaction positions were enlarged afterward; that revised scale has not yet had a rendered or manually played check.

## Kenney outdoor block

- `city_ground.tscn` now uses 28 imported Kenney road/pavement tiles, four trees, two houses, and two streetlights. `city.tscn` contains no geometry-generating script. The imported packs' included license files identify them as CC0.
- Godot 4.7.2 loaded the project in headless editor mode and ran the main scene for 120 iterations without a scene or script error. The Godot MCP started both `city.tscn` and the main project, and its debug output reported no errors.
- The physics-driven route check passed after moving the return marker and updating the route point to match the new market frontage: city → shopping → results → city, including retry, restart, exit, and settings. This was a headless check, not a rendered playthrough.
- A rendered screenshot could not be captured in this session. The Godot MCP exposes run/debug tools but no viewport image; the local X display cannot be opened from this environment. Godot's headless movie mode uses a dummy renderer and crashed when asked to read its viewport texture. The new city still needs an actual visual review and frame-rate measurement.

## Daylight scene — source check, 17 October 2026

- Both locations now instance `scenes/daylight.tscn`, which authors the procedural sky, sky ambient/reflected light, and a shadow-casting directional sun. `scripts/main.gd` no longer builds their lighting at runtime.
- Godot 4.7.2 imported the project and ran the main scene for 120 headless frames without a scene or script-load error. That direct boot emitted a resource-in-use warning during shutdown. The physics-driven full route passed through city → shop → results → city after the change and exited cleanly.
- These are headless checks. No rendered screenshot, manual visual tuning, or frame-rate measurement was possible here. The earlier 1080p FPS result predates this lighting change and does not measure the cost of directional shadows.

## City backdrop — source check, 17 October 2026

- `city_backdrop.tscn` adds authored, non-interactive Kenney models beyond the existing invisible play boundary: continued road and pavement, facing rows of commercial buildings, houses on both sides, a distant low-detail skyline, and trees. All models reuse the CC0 packs already recorded in `asset-credits.md`.
- Godot 4.7.2 imported the source project. The headless physics-driven city → shop → results → city route passed with retry, restart, exit, and settings checks. The route confirms gameplay still works; it does not show how the backdrop appears to a player.
- A rendered Godot screenshot and 1080p frame-rate measurement are still needed. The local X display is unavailable to this workspace, and the headless renderer produces a 64×64 dummy viewport. Prior screenshots and FPS results predate this backdrop.

## Outer city blocks and distance fog — source check, 17 October 2026

- `city_outer_blocks.tscn` adds 84 authored Kenney road/pavement instances, 26 suburban houses, 18 trees, and six low-detail skyline buildings beyond the first backdrop. The existing playable collision boundary and mission scene are unchanged. The three supplied pack licenses each state CC0.
- `daylight.tscn` now enables Godot depth fog with a sky-colored tint from 22 m to 62 m. A headless engine inspection confirmed that fog is enabled in depth mode and that the outer scene contains all expected nodes. Godot 4.7.2 imported the project, and the physics-driven city → shop → results → city route passed after these changes.
- Headless checks cannot assess the fog blend, composition, or rendering cost. A rendered visual review and 1080p frame-rate measurement remain outstanding; prior screenshots and FPS data predate the added houses, trees, and fog.

## Warm daylight palette — source check, 17 October 2026

- `daylight.tscn` now uses a cream-yellow horizon and ground haze, warmer distance fog, warm ambient fill mixed with sky light, and a warmer directional sun. The upper sky remains a softer blue. No model materials, geometry, or gameplay settings changed.
- Godot 4.7.2 loaded the scene resource headlessly and reported the authored horizon, fog, ambient mix, and sun values. A rendered color review was unavailable here; this check confirms resource loading, not the final on-screen palette or frame rate.

## Fair-weather cloud cover — source check, 17 October 2026

- `daylight.tscn` now assigns `assets/sky/fair_weather_clouds.png` to the native `ProceduralSkyMaterial.sky_cover` property. The original 2:1 image has sparse warm-white clouds on black, and the material tints their additive contribution to suit the warm daylight palette. Both city and supermarket receive the same shared sky scene.
- Godot 4.7.2 imported the PNG headlessly and loaded the shared daylight scene with the assigned 1774×887 cloud texture and warm tint. A rendered composition, wrap seam, and frame-rate review remain outstanding because the local display was unavailable.

## Raised market pavement — source and physics check, 17 October 2026

- The playable market block uses authored Kenney high pavement tiles and a sloped crossing ramp. The shared Godot `StandardMaterial3D` uses the owner's CC0 Stone Brick Pavement 003 image with world triplanar projection. Decorative low tiles in the backdrop and outer blocks use the same material.
- Godot 4.7.2 imported and loaded the scenes headlessly. Physics raycasts measured the market pavement at 0.30 m, the road at 0.13 m, and the ramp descending through 0.214 m at its midpoint. The full physics-driven city → market → results → city route passed, including movement up the ramp and entry to the raised shop.
- A rendered review of texture scale, curb appearance, seam continuity, and frame rate remains outstanding; the local headless renderer is only a 64×64 dummy viewport.

## Unified red and white curb material — source check, 17 October 2026

- The earlier `Sprite3D` strips showed visible seams between the vertical face and top lip. They were removed. `city_ground.tscn` now applies one Godot `ShaderMaterial` to each of the eight existing front-row Kenney high tiles. The shader paints aligned red/white bands on the curb face and 0.17 m of its top surface, while projecting the existing pavement image across the remainder. Tile placement, the crossing ramp, collision, and road connections were preserved.
- Godot 4.7.2 imported the project and loaded the city ground headlessly. A scene check confirmed that all eight front-row tiles use the shared shader, other pavement uses its existing standard material, and the paint-strip node is absent. The full physics-driven city → shop → results → city route passed after the material change.
- A rendered check of paint alignment, color under daylight, and frame rate is still needed; the local headless renderer produced a 64×64 dummy viewport.
