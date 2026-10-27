# Speech module

This GDScript module handles hold-E recording, transcription, and vocabulary assessment. `SpeechModule.tscn` is its only game-facing assessment entry point. Mission state, stars, lesson wording, narration, and dialogue UI remain outside the module. Pip's generated review audio uses a replaceable synthesis port and an ElevenLabs adapter; `scripts/pip_voice.gd` owns its playback outside the assessment workflow.

## Structure

```text
Game UI/input → SpeechModule.tscn → PracticeSpeechPort → PracticeSpeech
                                         │
                                         ├─ RecordingPort → GodotMicrophone
                                         ├─ TranscriptionPort → RealtimeTranscriber
                                         └─ EvaluationPort → DeepSeekAnswerEvaluator
```

`Core/Ports/Driving` contains the workflow contract. `Core/Ports/Driven` contains three abstract GDScript adapter contracts. `Core/Application` owns session order, cancellation, and result publication. `Core/Domain` validates lesson, audio, transcript, and assessment data. `Adapters/Godot` captures mono PCM16 microphone samples. `Adapters/ElevenLabs` streams PCM chunks to Scribe v2 Realtime. `Adapters/DeepSeek` builds and decodes vocabulary assessments. `Adapters/Http` supplies the shared HTTP transport and retains the older batch transcriber and gateway evaluator as replaceable adapters. The workflow accepts fakes in headless tests.

The module's public methods are `configure(elevenlabs_key, deepseek_key) -> bool`, `begin_answer(lesson) -> int`, `finish_answer()`, and `cancel_answer()`. It exposes `state` and `is_configured`, and emits `state_changed(state)`, `partial_transcript(text)`, `answer_ready(result)`, and `failed(code, message)`. A zero session ID or a failure signal never scores an answer. Session IDs reject results that arrive after cancel, close, or a newer answer.

## Setup

Use Godot 4.7.2; **Godot .NET and the .NET SDK are not required**. Enable audio input in `project.godot` (already configured). Put these values in the ignored repository-root `.env`, or set them as process environment variables before launching Godot. Process variables take precedence:

- `ELEVENLABS_API_KEY`: ElevenLabs API key for realtime transcription and Pip's TTS voice.
- `AI_API_KEY`: DeepSeek API key for vocabulary assessment.

The lower-left debug badge separates configuration from live transcription: it shows connection, audio streaming, interim words, a committed transcript, or a failure. It shows a shortened copy of the last recognized phrase, but no URLs or credentials. `Speech available: true` means only that the module is configured; `STT: Transcript received` confirms a completed transcription attempt. Without both provider keys, the game uses authored answer choices. With both, scored conversations show the bottom speaking prompt. Press E to open a conversation, release it, then hold E while speaking and release to submit.

The game reads the root `.env` itself. No token URL or evaluation gateway is needed for this prototype. Each key is sent only to its own provider.

## Transcription and evaluation contracts

The client connects directly to ElevenLabs Scribe v2 Realtime with an `xi-api-key` WebSocket handshake header and sends 100 ms mono PCM16 chunks at the actual microphone mix rate. It uses manual commit when E is released, shows partial transcripts during recording, and passes only a committed transcript to evaluation. ElevenLabs [documents the realtime wire format and header authentication](https://elevenlabs.io/docs/api-reference/speech-to-text/v-1-speech-to-text-realtime). The old HTTP/WAV adapter remains available for tests or a future alternate module configuration.

The DeepSeek adapter posts to the [chat completions API](https://api-docs.deepseek.com/api/create-chat-completion/) with a bearer key. It uses the documented `deepseek-flash` model name, which currently routes to DeepSeek V4.1 Flash; the older V4 Flash identifier has been retired. It sends the lesson rubric in a system message and the transcript, prompt, vocabulary targets, and authored examples as JSON learner data. [JSON output mode](https://api-docs.deepseek.com/guides/json_mode/) requests this assessment shape:

```json
{
  "quality": 1,
  "feedback": "That is correct English!",
  "suggested_wording": "Excuse me, could you tell me where the bananas are?",
  "vocabulary_used": [{"word": "bananas", "evidence": "bananas"}],
  "pip_response": "Great job! You asked clearly about the bananas. Adding please would make it even friendlier!"
}
```

`quality` is 0 = needs practice, 1 = understandable, 2 = strong. The adapter extracts this JSON from DeepSeek's completed choice. The domain derives `allowed` from quality, checks vocabulary evidence against lesson targets and the transcript, and requires a bounded `pip_response`. Pip's line should praise a valid answer, offer optional improvement for quality 1, and invite a retry for quality 0. Blocked, truncated, malformed, and inconsistent responses yield operational errors without a score. The transcript is treated as learner data, not as an instruction. Actual AI judgment still needs review with live examples.

Assessment HTTP requests have no redirects and a 64 KiB response cap. The realtime connection times out after 10 seconds, DeepSeek evaluation after 30 seconds, and the committed transcript after 20 seconds. Recording stops at 30 seconds; audio shorter than 150 ms, lost frames, silence, empty transcripts, malformed responses, and network failures produce retryable operational errors without a language score. Audio stays in memory and is not saved. Pip's [TTS request](https://elevenlabs.io/docs/api-reference/text-to-speech/convert) also has no redirects, times out after 30 seconds, and accepts up to 2 MiB of MP3 audio. The active `VOICE_ID` constant is `pFZP5JQG7iQjIQuC4Bku`, with model `eleven_v4` and output format `mp3_44100_128`; the previous ID is commented beside it for a quick rollback. The generated sound plays through the Voice bus and is cached in memory for replay. TTS failure leaves the review text visible and does not change the score.

The lower-left badge also shows Pip TTS status. A failed request reports the HTTP status plus ElevenLabs error code/message, or a specific Godot network failure. The same detail appears in the review panel. Provider messages are shortened and the configured API key is redacted; the debug text is for this prototype and should be reviewed before a public release.

## Verification

From the repository root, with the standard Godot executable:

```sh
godot --headless --path vocab-box --script res://tests/speech_workflow.gd
godot --headless --path vocab-box --script res://tests/speech_bridge.gd
godot --headless --path vocab-box --script res://tests/speech_input.gd
godot --headless --path vocab-box --script res://tests/speech_conversation.gd
godot --headless --path vocab-box --script res://tests/speech_environment.gd
```

For the DeepSeek integration check, start `python3 vocab-box/tests/speech_deepseek_server.py 18975`, then run `VOCAB_SPEECH_TEST_URL=http://127.0.0.1:18975 godot --headless --path vocab-box --script res://tests/speech_deepseek.gd`. For the realtime check, start `python3 vocab-box/tests/speech_realtime_server.py 18974`, then run `VOCAB_SPEECH_TEST_WS_URL=ws://127.0.0.1:18974/v1/speech-to-text/realtime godot --headless --path vocab-box --script res://tests/speech_realtime.gd`. The older HTTP gateway adapters can still be checked with `speech_gateway_server.py` and `tests/speech_http.gd`. The realtime fixture needs Python `websockets`; none of these checks needs a vendor account. Use isolated `XDG_DATA_HOME` directories for gameplay tests to protect personal saves.

`tests/pip_voice.gd` exercises generated playback, cancellation, and cached replay with a fake synthesizer. For the ElevenLabs TTS loopback check, generate a small MP3 with `gst-launch-1.0 -q audiotestsrc num-buffers=30 wave=sine samplesperbuffer=1024 ! audio/x-raw,rate=22050,channels=1 ! lamemp3enc ! filesink location=/tmp/vocab-pip-tts-fixture.mp3`, start `python3 vocab-box/tests/pip_tts_server.py 18976 /tmp/vocab-pip-tts-fixture.mp3`, then run `VOCAB_SPEECH_TEST_URL=http://127.0.0.1:18976 godot --headless --path vocab-box --script res://tests/pip_tts.gd`. The fixture uses a fake key and makes no provider request.

The old `builds/linux/play.sh` pack predates the speech UI and remains choice-only. A new desktop export must include this dynamically loaded module scene and its scripts; the current Linux export preset also omits other required game resources, so the old pack was not replaced. The DeepSeek adapter passed a local HTTP fixture. Physical microphone capture, live ElevenLabs transcription, live DeepSeek assessment, a rendered speech playthrough, and Windows export remain unverified.
