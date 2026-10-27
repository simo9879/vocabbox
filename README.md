# Vocab Box

A small 3D English-shopping adventure for children, built with Godot 4. Explore Sunny Market with Pip, ask for help, collect bananas, chat with a shopper and check out. Authored choices are available by default. An optional [GDScript speech module](vocab-box/modules/speech/README.md) streams hold-E audio to ElevenLabs Scribe v2 Realtime and evaluates the committed answer with DeepSeek Flash when both provider keys are configured. Pip then speaks a generated review using the selected ElevenLabs voice.

## Play

On Linux x86_64 run `./builds/linux/play.sh`. This portable bundle includes its own Godot runtime and bundled voice audio. Or open `vocab-box/project.godot` in Godot 4.7.2 and press F6/F5 on the new `scenes/main.tscn` / project.

For speech debugging, run the current source project: its lower-left badge shows `speech.available`, the configuration reason, live STT status, and a shortened last transcript. The existing Linux pack is an older choice-only build and does not include that badge.

WASD or arrows move; mouse orbits; E interacts; Escape pauses/closes dialogue; H asks Pip for help; R replays Pip’s current line. Use the mouse for dialogue choices and the triangle buttons to hear an answer. Scroll results if needed. There is no jumping.

The saved best score and three volume settings live in Godot's platform user-data folder (`OS.get_user_data_dir()`). Quitting discards the current attempt. Replay and hints cannot lower your best stars.

## Source structure

- `vocab-box/scenes/`: separate city, supermarket, player, camera, bird, interactable, dialogue, main scenes.
- `vocab-box/scripts/mission.gd`: ordered state, inventory, best qualities and stars.
- `vocab-box/scripts/evaluator.gd`: authored response-evaluation boundary.
- `vocab-box/modules/speech/`: isolated GDScript speech workflow, abstract driving/driven ports, Godot entry point, ElevenLabs realtime adapter, and DeepSeek evaluation adapter.
- `vocab-box/scripts/speech_dialogue.gd`: optional speech input and dialogue integration.
- `vocab-box/lessons/banana.tres`: editable dialogue, choices, quality, feedback, objectives, hints and voice references.
- `vocab-box/scripts/save.gd`: validated local settings/best-score persistence with temporary-file replacement.
- `vocab-box/audio/`: bundled narration, ambience and effects.

The unused town asset pack, duplicate source archives, Blender backup and old prototype scene/scripts are kept under `.local/archive/` and ignored by Git. Open the configured project main scene at `vocab-box/scenes/main.tscn`.

## Verify and rebuild

```sh
# Substitute the installed Godot executable if it is not on PATH.
godot --headless --path vocab-box --editor --import --quit
godot --headless --path vocab-box --script res://tests/test_runner.gd
godot --headless --path vocab-box --script res://tests/playthrough.gd
godot --headless --path vocab-box --script res://tests/speech_workflow.gd
godot --headless --path vocab-box --script res://tests/speech_bridge.gd
godot --headless --path vocab-box --script res://tests/speech_input.gd
godot --headless --path vocab-box --script res://tests/speech_conversation.gd
# Rendered physics-driven route, UI screenshots and frame samples:
godot --path vocab-box --resolution 1280x720 --script res://tests/playthrough.gd
godot --path vocab-box --script res://tests/playthrough.gd -- --1080
GODOT_BIN=/absolute/path/to/godot tools/build_linux.sh
```

Use isolated `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` for test runs to avoid changing personal game saves. The rendered test takes about 30 seconds and saves screenshots under `/tmp/vocab-*.png`. The portable build uses the host engine executable because export templates were unavailable; a standard release export can replace it after installing matching templates.

See [specification](docs/game-spec.md), [verification](docs/verification.md), [credits](docs/asset-credits.md), and [audio generation](docs/audio-generation.md).
