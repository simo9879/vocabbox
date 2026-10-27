"""Regenerate bundled ambience and effects without changing spoken clips."""

import math
import random
import struct
import wave
from pathlib import Path


OUT = Path(__file__).resolve().parents[1] / "vocab-box/audio"
rng = random.Random(12)


def synth(name, seconds, fn):
    sample_rate = 22050
    data = b"".join(
        struct.pack("<h", int(max(-1, min(1, fn(i / sample_rate))) * 32767))
        for i in range(int(sample_rate * seconds))
    )
    with wave.open(str(OUT / (name + ".wav")), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(data)


synth("step", 0.12, lambda t: rng.uniform(-1, 1) * 0.12 * math.exp(-t * 35))
synth("interact", 0.3, lambda t: 0.2 * math.sin(2 * math.pi * (660 if t < 0.12 else 880) * t) * math.exp(-t * 10))

for name in ["city", "supermarket"]:
    def ambient(t):
        notes = [261.63, 329.63, 392, 329.63, 293.66, 349.23, 440, 349.23]
        phase = t % 1.5
        note = notes[int(t / 1.5) % 8]
        melody = 0.045 * math.sin(2 * math.pi * note * t) * math.sin(math.pi * phase / 1.5) ** 2
        air = 0.012 * math.sin(2 * math.pi * 130.815 * t)
        chirp = (
            0.025 * math.sin(2 * math.pi * (1800 + 300 * math.sin(t * 18)) * t) * max(0, math.sin(t * 1.3)) ** 20
            if name == "city" else 0.008 * rng.uniform(-1, 1)
        )
        return melody + air + chirp

    synth(name, 24, ambient)

print("Generated ambience and effects WAV files")
