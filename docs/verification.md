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

## Opposite road curb — source check, 17 October 2026

- `city_backdrop.tscn` now uses nine aligned Kenney high tiles with the same curb material along the far edge of the playable road. Their painted face points toward the road at z=13 m, and the 0.17 m top lip uses the same stripe pattern as the market side. The inner far-side sidewalk row was raised to the same 0.30 m top height, and decorative buildings, houses, skyline pieces, and trees on it were lifted to match. The existing road tiles and gameplay collision were unchanged.
- Godot 4.7.2 imported and loaded the city scene headlessly. A scene check confirmed nine evenly spaced painted tiles facing the road and nine inner sidewalk tiles at the same height. The full physics-driven city → shop → results → city route passed after the change. A rendered appearance and frame-rate check remains outstanding.

## Road asphalt detail — source check, 17 October 2026

- `materials/road_surface.tres` uses the owner-supplied CC0 Asphalt 001 image directly on the dark top faces of the existing Kenney straight, crossing, and crossroad meshes. The first generated asphalt image was too light because the shader retained much of the Kenney atlas brightness; that image was removed. The shader samples the Kenney color atlas for its painted markings, raised edges, and side faces. The asphalt image is projected in world coordinates so its scale continues across road tiles; scene transforms and collision were unchanged.
- Godot 4.7.2 imported the replacement PNG and loaded the shader and city scene headlessly. A scene check confirmed the new image and darkening parameter on all 47 city road meshes: 42 straight, one crossing, and four crossroads. The full physics-driven city → shop → results → city route passed after the replacement. A rendered color, repeat seam, and frame-rate check remains outstanding.

## Blackboard start and pause menus — 18 October 2026

- Godot 4.7.2 imported the new font, theme, and authored menu scenes successfully. The initial sandboxed editor invocation reported blocked editor settings/socket operations; the approved retry completed cleanly.
- The existing headless physics-driven full city → shop → results → city route passed, including retry, pause/settings/back/resume, restart and exit confirmation. Save writes for this run were isolated with `XDG_DATA_HOME=/tmp/vocab-ui-data`.
- A temporary headless scene check loaded both menus at 1280×720 and 1920×1080, checked their content fits inside the available scroll area, and checked initial primary-button focus. Both passed. This checks Control layout calculations, not rendered font or image appearance.
- No rendered screenshot, manual mouse/keyboard playthrough or frame-rate measurement was performed for this UI change. Review the blackboard image stretch, chalk readability and focus appearance in the editor/game before visual sign-off.

### Centered boards and authored Settings follow-up

- Title, pause, and settings boards now use 10% viewport margins, leaving the world visible around a centered board sized to 80% width and height.
- Settings now owns three authored HSliders with imported SVG chalk tracks/fills/handles and retains saved Voice/Music/Effects values, 0.05 steps, and Back/Escape navigation.
- Godot import completed cleanly on the approved retry. The headless full route passed again with the settings check updated to use the authored sliders. All three scenes passed temporary 1280×720 and 1920×1080 content-fit and primary-focus checks. At 720p, title/pause/settings content heights were 466/403/427 px inside 496 px available height.
- These are headless checks. Rendered review of the centered background and chalk slider appearance remains outstanding.

### Chalk slider track correction

- The owner's rendered Settings screenshot showed visible handles but missing tracks. The texture styleboxes had no vertical content margins, giving them zero minimum height even though their textures are 12 px tall; the earlier content-fit checks did not detect this rendering issue.
- `scenes/ui/chalk_theme.tres` now sets 6 px top and bottom content margins on both track and fill styles. A targeted Godot headless check confirmed 12 px minimum height and 12 px texture height for the slider, filled area and highlighted filled area.
- Rendered confirmation of this correction remains pending.

## Notebook objective HUD — 18 October 2026

- Godot 4.7.2 imported the owner-supplied notebook image, Patrick Hand font, authored checkbox icons, and notebook scene without import errors. Source inspection confirms the HUD label builder and its title, controls reminder, and banana counter were removed; the notebook takes objective wording from the lesson resource and completion state from the mission stage.
- No rendered or manually played check was performed for this change. Notebook placement and text legibility still need visual review at 720p and 1080p.

## C# speech module — 18 October 2026

- Built the plain .NET core/HTTP projects and Godot host assembly using .NET SDK 8.0.426 and Godot .NET SDK 4.7.2. Final build completed with zero warnings and errors. Tooling was downloaded to `/tmp/vocab-dotnet` and `/tmp/vocab-godot-mono`; it was not installed globally or added to the repository.
- `dotnet test vocab-box/modules/speech/Tests/VocabBox.Speech.Tests.csproj` passed **26 tests**. Coverage includes capture → transcription → evaluation ordering, quality/progression mapping, short/long recordings, empty transcripts, duplicate submissions, cancellation during recording/transcription/evaluation, stale responses after a new session, timeout cancellation/retry, vocabulary evidence validation, safe failures, WAV headers/payload, request contracts, malformed assessments, response-size limits and endpoint policy. HTTP tests use an in-memory handler, not a live vendor.
- Godot 4.7.2 .NET completed a headless editor import. The initial sandbox invocation could not initialize editor sockets or locate the temporary SDK on PATH; the approved retry with the SDK on PATH completed without import errors.
- `tests/speech_bridge.gd` passed with the real compiled C# node under Godot .NET. It checks GDScript method calls/dictionary marshalling, C# signals, configuration failures, recording/cancellation, focus-loss cancellation, empty capture handling without a language score, and private bus cleanup. The final capture implementation uses AudioEffectCapture; the final bridge run had no engine errors. Headless audio is a dummy device: this does not verify physical microphone sound.
- `tests/speech_input.gd` passed using a module double, checking that the opening E press is not recorded, repeated key presses/releases do not duplicate submissions, dialogue close rejects late replies, and narration cancels recording.
- Existing mission/evaluator/save/audio tests passed **523 checks**. The headless physics-driven city → shop → results → city route passed both with speech unconfigured and with loopback endpoint configuration enabling the module while the route selected authored answers. Both runs covered retry, restart, exit and settings. No request was sent to a live provider. Saves were isolated under `/tmp/vocab-speech-*`. The route logged existing scene UID fallback warnings for `main.gd` and `notebook_hud.gd`; it resolved both by their text paths and completed.
- The legacy Linux pack script passes shell syntax validation and deliberately rejects a .NET engine with an explanation, preventing an incomplete single-engine bundle from being presented as a speech build. No exported build was generated.
- Not verified: a rendered speech UI/playthrough, microphone hardware/permissions/device loss, actual network/vendor behavior, transcription/assessment quality, AI response suitability for children, or a Windows .NET export. No provider/backend was selected or deployed. Generated feedback currently has text presentation only unless it matches a bundled voice clip.

### CSharpier formatting follow-up

- Installed CSharpier 1.3.0 as a repository-local .NET tool and applied its default formatting across 23 C# source/project files; 15 files needed changes. CSharpier syntax-tree validation remained enabled and the subsequent formatting check passed for all 23 files.
- The formatted Godot host assembly built with zero warnings/errors, and all 26 C# tests passed. This was a formatting-only change; no additional rendered or manually played check was performed.

### Speech module readability pass

- Extracted named validation and parsing methods from the HTTP adapters, application workflow, and domain constructors. Split the Godot entry point's frame callback into recording and completed-result handling. Public ports, error codes, request and response contracts, and lesson behavior were preserved.
- CSharpier checked all 23 C# files. The Godot host assembly built with zero warnings/errors, all 26 C# tests passed, and the headless Godot .NET speech bridge reported zero failures. This did not exercise a physical microphone or live provider.

### Speech-first conversation UI — 20 October 2026

- Configured speech conversations now hide authored answer choices and show an authored bottom speaking prompt. Four 2D bars animate while the recorder reports `recording`; they stop during transcription, evaluation, and retry messages. The existing E press opens conversation; a later hold records and release submits. Unconfigured builds retain the authored choices. After two needs-practice replies, speech mode offers an audible model phrase without replacing the child's spoken answer.
- Godot 4.7.2 imported the project and passed the headless speech input test, the configured/unconfigured conversation wiring test, and the existing full city → shop → results → city choice route. The conversation test checks the 1280×720 logical layout: the bottom prompt is 560×92 px and does not overlap the conversation card. Rendered frames at 1280×720 and 1680×945 were reviewed; the latter was the available display's limit when 1920×1080 was requested. Both show the listening prompt and compact dialogue card clearly. These rendered checks used a module double in the city, not a live microphone or provider. The temporary Godot .NET runtime from the earlier speech verification was no longer present, so this pass did not rerun the C# bridge. A true 1920×1080 and in-market rendered check remain outstanding.

### Speech availability debug badge — 21 October 2026

- At this stage, the source project displayed `speech.available` and a reason from the GDScript controller. It reported missing Godot .NET support and missing transcription/evaluation URLs independently; no URL or token value was shown. A `true` state meant C# module setup succeeded, not that either remote service answered.
- The headless speech conversation and input tests passed. Rendered checks showed the orange disabled badge on the title screen and the green enabled badge in the module-double conversation test. The source build was tested; the old `builds/linux/vocab-box.pck` was not replaced.
- A candidate standard Linux pack exported to `/tmp` but failed at runtime because the existing scene-filter preset omitted model and UI resources loaded by the current source. It was discarded. Packaging the current project needs separate export-preset work and asset-provenance review; this badge is not available in the old launcher.

### GDScript speech module replacement — 21 October 2026

- Replaced the active C# module scene with a GDScript entry point, abstract driving/driven ports, a session workflow, Godot microphone adapter, independent HTTP transcription/evaluation adapters, and domain validation. The C# source and project files were removed from the active tree and preserved locally in ignored `.local/archive/speech-csharp-before-gd.tar.gz`. The game no longer requires Godot .NET or the .NET SDK. The debug badge now reports missing URLs or GDScript module setup failures.
- Standard Godot 4.7.2 completed a headless editor import. `tests/speech_workflow.gd`, `speech_bridge.gd`, `speech_input.gd`, and `speech_conversation.gd` passed. The workflow check covers capture → transcription → evaluation ordering, duplicate submission, cancellation, stale callbacks, vocabulary evidence, retryable failure, timeout, and WAV bytes. The bridge checks configuration, focus cancellation, empty headless capture, and private bus cleanup.
- A local loopback HTTP fixture passed `tests/speech_http.gd`, including WAV upload, evaluation JSON, endpoint policy, and cancellation of a slow request. This verifies the Godot HTTP transport without contacting a vendor. The domain was adjusted to accept integral float values from Godot's JSON parser while publishing an integer quality score.
- The existing 523-check model suite and headless physics-driven city → shop → results → city route passed. These runs used no live microphone or vendor service. Physical capture quality, actual provider scoring, child-facing generated feedback, a rendered speech route, and a speech-enabled desktop export remain unverified. The old Linux pack is unchanged and still predates the speech UI.

### ElevenLabs realtime transcription client — 21 October 2026

- Replaced the game-facing batch WAV transcriber with a Scribe v2 Realtime WebSocket adapter. The microphone now streams mono PCM16 chunks during hold-E, forwards interim words to the speaking prompt, and commits the final chunk on release. The evaluation gateway and three-level scoring contract are unchanged. The older HTTP/WAV adapter remains available behind the same transcription port.
- Godot 4.7.2 loaded the source headlessly (the sandboxed editor reported socket/settings-write errors, with no script parse errors). All six speech checks (`speech_workflow`, `speech_bridge`, `speech_input`, `speech_conversation`, `speech_http`, `speech_realtime`) and the full physics-driven city → shop → results → city route passed at that time. The earlier local realtime fixture verified token retrieval, PCM chunk streaming, interim and committed transcripts, manual commit, and cancellation. Neither test used the owner's key or contacted ElevenLabs.

- Physical microphone capture, a live ElevenLabs transcription, the still-unimplemented AI evaluation gateway, a rendered speech playthrough, and a new desktop export remain unverified. At this earlier pass, setting `.env` alone did not enable speech because both token and evaluation URLs had to be supplied to the Godot process.

### Live STT debug badge — 21 October 2026

- Expanded the existing lower-left badge to show WebSocket connection, audio streaming, interim words, committed transcription, cancellation, and failures. A shortened last transcript remains visible after the conversation closes. Configuration and live STT status are separate, so `Speech available: true` no longer looks like proof that the service responded. The badge never shows a URL or credential.
- Headless `speech_workflow`, `speech_conversation`, and `speech_input` checks passed, as did the full physics-driven city → shop → results → city route. The loopback realtime WebSocket check confirmed that the adapter reports connection, streaming and interim text while still committing the answer. The conversation check covers failure, cancellation, stale transcript rejection, and retaining STT success if later evaluation fails. A rendered 1280×720 UI check showed the badge fully visible beside the bottom speaking prompt, with the transcript status and shortened phrase readable. These checks used doubles and local fixtures; physical microphone capture and a live ElevenLabs request remain unverified.

### Direct ElevenLabs key for the prototype — 21 October 2026

- The source game now reads `ELEVENLABS_API_KEY` from the process environment or ignored repository-root `.env`, with nonempty process values taking precedence. The realtime adapter sends it as an `xi-api-key` WebSocket handshake header. The token URL, token request, and local token broker were removed. The evaluation gateway still uses its separate URL and optional bearer token; the ElevenLabs key is never passed to it.
- Godot 4.7.2 completed a headless editor import and the `speech_workflow`, `speech_bridge`, `speech_input`, `speech_conversation`, and `speech_environment` checks with zero failures. A loopback WebSocket fixture required the handshake header, rejected token query parameters, and passed PCM streaming, partial/committed transcript, manual commit, and cancellation checks. The full headless physics-driven city → shop → results → city route passed. No check contacted ElevenLabs or printed the local key.
- The current root `.env` contains an ElevenLabs key but no evaluation URL, and no evaluation URL is set in this process. The game therefore still uses authored choices until `VOCAB_SPEECH_EVALUATION_URL` is configured. Physical microphone capture, a live ElevenLabs transcription, AI evaluation, a rendered playthrough of this direct-key build, and a new desktop export remain unverified.

### Gemini vocabulary evaluation — 22 October 2026

- Replaced the game-facing evaluation gateway with a Gemini `generateContent` adapter. It reads `AI_API_KEY`, sends the key in `X-goog-api-key`, supplies the lesson rubric and examples, requests a structured JSON result, and passes that result through the existing three-level domain validation. The gateway evaluator remains as a replaceable adapter; the game no longer requires an evaluation URL.
- Godot 4.7.2 completed a headless editor import. `speech_workflow`, `speech_bridge`, `speech_input`, `speech_conversation`, `speech_environment`, the 523-check model suite, and the choice-route headless playthrough passed. A local Gemini HTTP fixture verified header authentication, lesson request shape, assessment decoding, blocked/malformed response handling, and cancellation without reading either real provider key. The current ignored `.env` has both provider key entries, so the source game selects speech conversations.
- Initial small live Gemini requests returned HTTP 503 and then timed out. A later request through `GeminiAnswerEvaluator.gd` failed after 1.4 seconds; repeating that same Godot adapter request returned HTTP 200 after 9.8 seconds. The adapter decoded a quality-1 assessment for the authored “Where are the bananas?” answer, and `SpeechContracts.validate_assessment` accepted it. This verifies one real Gemini evaluation through the game adapter, while provider availability was inconsistent. Physical microphone capture, live ElevenLabs transcription, the full rendered speech route, and a new export remain unverified.

### DeepSeek Flash evaluation — 23 October 2026

- Replaced the game-facing Gemini adapter with `Adapters/DeepSeek/DeepSeekAnswerEvaluator.gd` and its request/response codec. The adapter reads the existing `AI_API_KEY`, posts to DeepSeek chat completions with bearer authentication, uses `deepseek-flash` in non-thinking JSON mode, and preserves the lesson-owned rubric and three-level domain validation. DeepSeek documentation says `deepseek-flash` currently points to V4.1 Flash and the previous V4 Flash identifier has been retired. The Gemini adapter and its fixture were removed.
- Godot 4.7.2 completed a headless editor import. The local DeepSeek fixture passed request authentication, lesson data, JSON assessment parsing, blocked/malformed/truncated responses, and cancellation without contacting DeepSeek or reading the real key. The speech bridge passed when rerun alone after one failure during a parallel test run; the older HTTP gateway adapter passed its loopback fixture. `speech_workflow`, `speech_input`, `speech_conversation`, `speech_environment`, the 523-check model suite, and the authored-choice headless playthrough passed. The full microphone → ElevenLabs → DeepSeek route and a rendered speech playthrough remain unverified.
- A live DeepSeek request using the configured key and authored worker sample was attempted but rejected by automatic approval review before execution. The review stated that building the evaluator did not explicitly authorize exporting project lesson content and a learner sample to DeepSeek. Live provider behavior therefore remains unverified; no data was sent by this attempt.

### Generated Pip review voice — 24 October 2026

- DeepSeek's assessment now includes a bounded `pip_response` written as Pip speaking directly to the child. The existing feedback and suggested wording remain visible in the dialogue for debugging. `scripts/pip_voice.gd` sends that line through an ElevenLabs TTS adapter using the owner's selected voice ID and `eleven_v4`, plays the returned MP3 on the Voice bus, and caches the sound for replay. Dialogue changes cancel pending synthesis; an audio failure leaves the score and written review intact. The authored-choice route keeps its bundled narration.
- Godot 4.7.2 completed a headless import. `speech_workflow`, `speech_bridge`, `speech_input`, `speech_conversation`, `pip_voice`, and the 523-check model suite passed. The full authored-choice route passed headlessly. The local DeepSeek fixture accepted the expanded assessment, the legacy HTTP gateway fixture still passed, and a loopback ElevenLabs TTS fixture with a generated MP3 passed request shape, fake-key authentication, decoding, malformed output, and cancellation. The loopback fixtures used fake keys and sent no request outside the machine.
- A live ElevenLabs TTS request and rendered/manual playback have not been performed in this change. The end-to-end microphone → STT → DeepSeek → Pip voice path still needs a played check with the configured services.

### Pip TTS error visibility — 24 October 2026

- Replaced the generic Pip voice failure message with HTTP status and parsed ElevenLabs `detail.code`/`detail.message`, or a named Godot transport failure. The review panel and persistent lower-left badge show the result; the badge turns red for a TTS failure. Provider detail is bounded, flattened to one line, and redacts the configured API key.
- The local ElevenLabs fixture passed successful MP3 decoding, HTTP 422 detail display, malformed audio, and cancellation. The headless conversation and Pip playback tests passed, including the on-screen error text and badge color. No live ElevenLabs request was made for this diagnostic change; the owner's actual failure cause will appear on the next in-game TTS attempt.

### Bundled ElevenLabs voice replacement — 24 October 2026

- Backed up all 37 original eSpeak NG voice WAVs, their manifest, and the original generator in `backups/audio-espeak-2026-10-24/`. The original clips were copied and byte-for-byte verified before replacement. The manifest text, hash-based filenames, ambience, footsteps, and interaction sounds remain unchanged.
- Generated all 37 manifest lines through the live ElevenLabs API with the adapter's active voice ID `pFZP5JQG7iQjIQuC4Bku` and model `eleven_v4`. The new files are valid mono, 16-bit, 24 kHz WAVs totaling 142.5 seconds; all 37 differ from the originals. The generator stages responses before promotion and can resume an interrupted run without another request for staged lines.
- Godot 4.7.2 completed a headless editor import. The headless model runner passed 523 checks, including the 37 voice resource references. This verifies import and playback references, not how the voices sound in a rendered game; listening and a new desktop export remain outstanding.
- The ElevenLabs key succeeded for synthesis but the read-only subscription endpoint returned HTTP 401, so the account's commercial-use tier was not verified. ElevenLabs says commercial rights require a paid plan; confirm that before commercial distribution.

### Bundled voices separated by speaker — 24 October 2026

- Restored the original eSpeak NG WAVs for six NPC lines and nine answer-choice previews. The 22 Pip-only WAVs remain from the earlier ElevenLabs generation. Six clear/strong answer phrases can also be spoken by Pip as suggestions or results practice, so their already generated ElevenLabs versions are stored separately under `audio/pip/`; `scripts/main.gd` selects the version by speaker and preserves the speaker for replay.
- The last assembly reused locally staged ElevenLabs WAVs and the original backup. It made **no new ElevenLabs API requests**. `tools/generate_voice_audio.py` now requires `--generate-missing` before it can request new audio, so its default run consumes no credits.
- Verified every active root WAV matches its intended staged or backup source byte for byte, and all six Pip phrase variants match the staged files. Godot 4.7.2 imported the audio; the headless model runner passed 529 checks, including all 43 active voice paths. The headless physics-driven city → shop → results → city route passed. A rendered listening check and new desktop export remain outstanding.

### New market player-scale pass — 25 October 2026

- Scaled the authored room, imported furnishings, and ceiling fixtures together to 0.25 in `new_market.tscn`, leaving the player scene at its original 1.7 m collision height. The floor is now 15 × 15 m, the ceiling is about 6.3 m high, and the scene camera and player spawn were moved to the matching positions. The reusable fixture's light range and energy were tuned to keep the original soft lighting at the shorter distance. No models or runtime geometry were added.
- Godot 4.7.2 rendered the scene at 1280 × 720 on Intel HD Graphics 4000. Visual review showed the same market layout and shelf styling with the player close to shelf height. A separate headless physics check confirmed the player was on the floor at y = 0.125 m. This standalone scene is still outside the playable mission; no manual walk-through or frame-rate measurement was performed.

### New market character and route pass — 26 October 2026

- Connected `new_market.tscn` to the existing supermarket mission and placed Alex by the door, Sam by the visible banana display, and seated Jo with the supplied office chair behind checkout. Close rendered views at 1280 × 720 confirmed all three characters are visible at human scale; Alex and Sam have relaxed standing arms, and Jo faces the checkout. Sam's original GLB collapsed because its joint rest transforms were missing. The restored derivative reuses its own inverse bind matrices and unmodified mesh buffers.
- Godot 4.7.2 passed the headless physics-driven route after the scene and test waypoints changed. A separate headless rig check confirmed Alex's and Sam's arms move during dialogue and return to their idle poses afterward. The rendered route also passed city → worker → bananas → customer → checkout → results → city, including retry, restart, exit, and settings. The route sends movement input and selects live UI controls; it is not a manual playthrough.
- On Intel HD Graphics 4000 with OpenGL Compatibility at 1280 × 720, the rendered route recorded 765 movement samples: median **25.7 FPS**, 10th percentile **22.5 FPS**. This is below the specification's 60 FPS target and needs an art/performance pass. No new desktop bundle was exported. Exact Fab listing/creator credits for the character models and chair license/source remain pending before distribution.

### Off-target spoken answers — 26 October 2026

- The DeepSeek system instructions and the lesson speech rubric now treat the encounter target vocabulary as the expected item or topic. Asking for or discussing a different item (for example apples when the target is bananas) is graded quality 0 even when the grammar is correct; feedback names the mismatch, `suggested_wording` gives the target phrase, and Pip invites a retry with the target item. `docs/game-spec.md` records the same requirement.
- The local DeepSeek fixture now matches the current test lesson data and asserts that the off-target rule reaches the system message. Godot 4.7.2 passed the loopback DeepSeek evaluation check and the 529-check model suite. No live DeepSeek request was made, so real-model adherence to the new rule remains unverified; the fixture checks request shape, not semantic grading.

### Authored NPC voices — 27 October 2026

- Replaced the eSpeak NG voices of the six NPC lines with the owner's six MP3 recordings: `alex_1`/`alex_2` for Alex's prompt and reply, `sam_1`/`sam_2` for Sam, and `jo_1`/`jo_2` for Jo. Each file was decoded to mono, 16-bit, 22.05 kHz WAV and gain-matched to about −20.5 dBFS RMS with peaks below −1 dBFS; Jo's sources were 10 dB quieter than the others and were raised by 7.4 dB. The active filenames stay SHA-256 of the lesson text, so `lessons/banana.tres` `voice_paths` and the manifest are unchanged.
- The untouched MP3s and the normalized WAVs are preserved in `backups/audio-npc-2026-10-27/`. `tools/generate_voice_audio.py` now restores those recordings ahead of the eSpeak backup for the six NPC lines, and `lesson_field` reads one-line or multi-line lesson dictionaries so the current reformatted `banana.tres` still parses. A default generator run made no API requests and left all six active NPC WAVs byte-identical to the new recordings.
- Godot 4.7.2 completed the headless editor import and the 529-check model suite passed. The headless playthrough did not complete because an unrelated concurrent UI change removed the "Let's ask" button it presses, so audio playback and the voices themselves were not heard in a rendered game; a listening check remains outstanding.
- The owner did not state the source service or licence of the six MP3s, so their redistribution terms are recorded as unverified in `docs/asset-credits.md`.

### Windows prototype bundle — 27 October 2026

- `tools/build_windows.sh` imports the project, runs the 529-check model suite, exports the `Windows Desktop` preset in release mode with the installed Godot 4.7.2 official templates, writes engine notices and credits next to the executable, and archives the folder. The preset now records `../builds/windows/vocab-box.exe`, fills the Windows file properties (product "Vocab Box", description "A little adventure in English", company "Vocab Box prototype", version 0.1.0.0), and leaves the console wrapper off.
- Output: `builds/vocab-box-windows-x86_64.zip` (302 MB) containing `windows/vocab-box.exe` (105 MB), `vocab-box.pck` (538 MB), `README.txt`, `ASSET-CREDITS.md`, and `GODOT-LICENSES.txt`. The executable is x86_64, uses the GUI subsystem, and is unsigned. The `.pck` stays separate because the preset exports it unembedded, so the two files must remain side by side.
- The 529-check suite passed against the editable source and again against the exported `.pck` (`--main-pack`). This also covers the audio manifest, where one entry had gone stale: Sam's owner-supplied recording says "In my opinion, Bananas make a tasty snack. Have a lovely day!", so `lessons/banana.tres` (`reply` and `voice_paths`), the manifest line, and the clip filename (SHA-256 of the new text) now agree. `python3 tools/generate_voice_audio.py --limit 1` validated the manifest/lesson speaker sets without replacing active clips.
- The 538 MB payload comes from source-resolution art: `models/market` alone is 338 MB (`fruit_stand.glb` 56 MB with a 33 MB JPEG, `pineapple.glb` 32 MB, `office_chair.glb` 30 MB) plus `AsianBoy_animated.glb` at 51 MB. The exporter does not downscale assets, so reducing size needs a texture/mesh import pass, which this change did not attempt.
- Because the preset exports all resources, the pack also contains the compiled `tests/` scripts (172 KB of source). They are inert at runtime but are shipped for now; the curated scene filter used by the Linux preset is known to miss resources loaded by the current source.
- Not verified: the executable has never been started on Windows, so rendering, audio devices, OpenGL 3.3 driver behaviour, SmartScreen handling, and the played route are unconfirmed on the delivery platform. The icon is still the project's default Godot logo, the character-model and chair credits listed in `docs/asset-credits.md` remain pending before distribution, and the shared build runs in authored-choice mode because no API keys ship with it.
