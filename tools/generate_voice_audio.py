"""Generate bundled Pip WAVs with his configured ElevenLabs voice.

Run: python3 tools/generate_voice_audio.py
API requests require --generate-missing; the default only uses existing local audio.
Non-Pip lines restore their newest authored recordings: NPC voice clips when present,
otherwise the original eSpeak NG backup.
"""

import argparse
import ast
import hashlib
import json
import os
import re
import shutil
import time
import urllib.error
import urllib.request
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "vocab-box/audio"
ADAPTER = ROOT / "vocab-box/modules/speech/Adapters/ElevenLabs/ElevenLabsTextToSpeech.gd"
LESSON = ROOT / "vocab-box/lessons/banana.tres"
BACKUP = ROOT / "backups/audio-espeak-2026-10-24"
NPC_BACKUP = ROOT / "backups/audio-npc-2026-10-27"
SAMPLE_RATE = 24000
OUTPUT_FORMAT = "pcm_24000"


def configured_value(name):
    """Read the process or repository .env setting used by the game."""
    value = os.environ.get(name, "")
    if value:
        return value
    path = ROOT / ".env"
    if not path.exists():
        return ""
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[7:].strip()
        if line.startswith(name + "="):
            value = line.split("=", 1)[1].strip()
            if len(value) >= 2 and value[0] in "\"'" and value[-1] == value[0]:
                value = value[1:-1]
            return value
    return ""


def adapter_constant(name):
    # Keep bundled and live Pip speech on the active GDScript voice and model.
    match = re.search(r'^const ' + re.escape(name) + r' := "([^"]+)"', ADAPTER.read_text(), re.MULTILINE)
    if not match:
        raise RuntimeError(f"Cannot find {name} in {ADAPTER}")
    return match.group(1)


def lesson_field(name):
    """Read one authored resource dictionary, whether it is written on one line or many."""
    text = LESSON.read_text()
    match = re.search(r"^" + re.escape(name) + r" = ", text, re.MULTILINE)
    if not match:
        raise RuntimeError(f"Cannot find {name} in {LESSON}")
    start = match.end()
    depth = 0
    quote = ""
    escaped = False
    # Scan to the dictionary's closing brace, ignoring braces inside quoted text.
    for index in range(start, len(text)):
        character = text[index]
        if quote:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = ""
            continue
        if character in "\"'":
            quote = character
        elif character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return ast.literal_eval(text[start:index + 1])
    raise RuntimeError(f"Cannot find the end of {name} in {LESSON}")


def non_pip_source(line):
    """Prefer the newest authored NPC recording, then the original eSpeak clip."""
    name = hashlib.sha256(line.encode("utf-8")).hexdigest() + ".wav"
    for folder in (NPC_BACKUP, BACKUP):
        if (folder / name).is_file():
            return folder / name
    return None


def speaker_lines(manifest):
    encounters = lesson_field("encounters")
    choices = [choice for encounter in encounters.values() for choice in encounter["choices"]]
    pip_only = (set(lesson_field("lines").values()) | set(lesson_field("hints").values())
                | {choice[3] for choice in choices})
    other = ({line for encounter in encounters.values() for line in (encounter["prompt"], encounter["reply"])}
             | {choice[1] for choice in choices})
    shared = {choice[1] for choice in choices if choice[2] >= 1}
    if pip_only & other or not shared <= other or set(manifest) != pip_only | other:
        raise RuntimeError("Manifest and lesson speaker assignments do not match")
    return pip_only, other, shared


def valid_wav(path):
    if not path.is_file():
        return False
    try:
        with wave.open(str(path), "rb") as recording:
            return (recording.getnchannels() == 1 and recording.getsampwidth() == 2
                    and recording.getframerate() == SAMPLE_RATE and recording.getnframes() > SAMPLE_RATE // 10)
    except (OSError, wave.Error):
        return False


def request_pcm(text, voice_id, model, api_key):
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format={OUTPUT_FORMAT}"
    body = json.dumps({"text": text, "model_id": model}).encode("utf-8")
    request = urllib.request.Request(url, body, {
        "xi-api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "audio/pcm",
    })
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                audio = response.read()
                if len(audio) < SAMPLE_RATE // 5 or len(audio) % 2:
                    raise RuntimeError("ElevenLabs returned invalid or empty PCM audio")
                return audio
        except urllib.error.HTTPError as error:
            if error.code == 429 and attempt < 2:
                time.sleep(min(20, 2 ** (attempt + 1)))
                continue
            detail = error.read(1000).decode("utf-8", errors="replace").replace(api_key, "[redacted]")
            raise RuntimeError(f"ElevenLabs HTTP {error.code}: {detail}") from error
    raise RuntimeError("ElevenLabs rate limit persisted after retries")


def write_wav(path, pcm):
    temporary = path.with_suffix(".wav.tmp")
    with wave.open(str(temporary), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm)
    temporary.replace(path)


def promote(source, destination):
    temporary = destination.with_suffix(".wav.tmp")
    shutil.copyfile(source, temporary)
    temporary.replace(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, help="Stage only this many lines; do not replace active clips")
    parser.add_argument("--generate-missing", action="store_true", help="Request missing Pip clips from ElevenLabs")
    args = parser.parse_args()
    if args.limit is not None and args.limit < 1:
        parser.error("--limit must be positive")

    voice_id = adapter_constant("VOICE_ID")
    model = adapter_constant("MODEL")
    lines = json.loads((AUDIO / "manifest.json").read_text())
    if not isinstance(lines, list) or any(not isinstance(line, str) or not line for line in lines):
        raise RuntimeError("Audio manifest must contain nonempty strings")
    pip_only, other, shared = speaker_lines(lines)
    pip_lines = [line for line in lines if line in pip_only or line in shared]
    stage = ROOT / ".local" / f"audio-stage-{voice_id}-{model}-{OUTPUT_FORMAT}"
    stage.mkdir(parents=True, exist_ok=True)

    # Stage Pip's lines and shared practice phrases for resumable generation.
    for index, line in enumerate(pip_lines[:args.limit] if args.limit else pip_lines, 1):
        name = hashlib.sha256(line.encode("utf-8")).hexdigest() + ".wav"
        path = stage / name
        if valid_wav(path):
            print(f"[{index}/{len(pip_lines)}] staged {name}", flush=True)
            continue
        if not args.generate_missing:
            raise RuntimeError(f"Missing staged Pip clip {name}; use --generate-missing to request it from ElevenLabs")
        api_key = configured_value("ELEVENLABS_API_KEY")
        if not api_key:
            raise RuntimeError("ELEVENLABS_API_KEY is missing from the process and repository .env")
        write_wav(path, request_pcm(line, voice_id, model, api_key))
        print(f"[{index}/{len(pip_lines)}] generated {name}", flush=True)

    if args.limit is not None:
        print(f"Pilot complete; active clips unchanged. Staging directory: {stage}")
        return
    if any(not valid_wav(stage / (hashlib.sha256(line.encode("utf-8")).hexdigest() + ".wav")) for line in pip_lines):
        raise RuntimeError("Incomplete staged audio; active clips unchanged")
    if any(non_pip_source(line) is None for line in other):
        raise RuntimeError("Missing original non-Pip WAV; active clips unchanged")

    # Keep non-Pip originals at lesson paths and store Pip's shared-phrase versions separately.
    (AUDIO / "pip").mkdir(exist_ok=True)
    for line in pip_only:
        name = hashlib.sha256(line.encode("utf-8")).hexdigest() + ".wav"
        promote(stage / name, AUDIO / name)
    for line in other:
        name = hashlib.sha256(line.encode("utf-8")).hexdigest() + ".wav"
        promote(non_pip_source(line), AUDIO / name)
    for line in shared:
        name = hashlib.sha256(line.encode("utf-8")).hexdigest() + ".wav"
        promote(stage / name, AUDIO / "pip" / name)
    print(f"Installed {len(pip_only)} Pip lines, {len(shared)} Pip phrase variants, and {len(other)} original non-Pip lines")


if __name__ == "__main__":
    main()
