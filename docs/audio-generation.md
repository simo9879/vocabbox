# Offline audio generation

From the repository root run `python3 tools/generate_audio.py`. Requires Python 3 and the host's `libespeak-ng.so.1` shared library. No microphone, cloud API, network service or runtime speech engine is used. Voice is English (`en-gb`) at 145 words/minute. Speech is intentionally temporary synthetic narration.

`vocab-box/audio/manifest.json` lists the spoken text. Each clip is named SHA-256(UTF-8 text) + `.wav`; this deterministic reference is resolved by the audio playback function. When changing lesson resource wording, update the manifest and regenerate. The test runner checks every manifest clip is importable. Do not change a subtitle without regenerating its matching voice.

The same generator writes city/shop ambience, footsteps and interaction tones from deterministic waveforms. Voice playback uses one AudioStreamPlayer: new speech replaces previous speech. Replay buttons re-use that player. Choice playback is always explicit. Three Godot audio buses control Voice, Music (ambient beds), and Effects independently.

Import after generation: `godot --headless --path vocab-box --editor --import --quit`. Runtime playback uses Godot's bundled imported WAV resources. All generated files are included in the desktop pack.
