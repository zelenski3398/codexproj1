#!/usr/bin/env python3
"""Offline conversion of the user-supplied audio; not required to run Godot.

Usage: python3 tools/prepare_audio.py --sfx-dir /path/to/extracted-pack --theme /path/to/theme.wav
Requires numpy and ffmpeg. Originals are left untouched.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile
import wave

import numpy as np


def convert(source, destination, trim=None, crossfade=0.08, mono=True, gain=1.0):
    with wave.open(str(source)) as reader:
        rate, channels = reader.getframerate(), reader.getnchannels()
        if reader.getsampwidth() != 2:
            raise ValueError("Expected the supplied 16-bit PCM WAV files")
        samples = np.frombuffer(reader.readframes(reader.getnframes()), dtype="<i2").reshape(-1, channels).astype(np.float64) / 32768
    if trim:
        samples = samples[round(trim[0] * rate):round(trim[1] * rate)]
    if mono:
        samples = samples.mean(axis=1, keepdims=True)
    if crossfade:
        count = round(crossfade * rate)
        blend = np.linspace(0, 1, count)[:, None]
        # End-to-start overlap makes the next loop boundary continuous rather
        # than repeatedly fading the engine or gunfire down to silence.
        joined = samples[-count:] * (1 - blend) + samples[:count] * blend
        samples = np.concatenate((samples[count:-count], joined))
    samples = np.clip(samples * gain, -0.999, 0.999)
    with tempfile.TemporaryDirectory() as temporary:
        pcm = pathlib.Path(temporary) / "processed.wav"
        with wave.open(str(pcm), "wb") as writer:
            writer.setnchannels(samples.shape[1])
            writer.setsampwidth(2)
            writer.setframerate(rate)
            writer.writeframes((samples * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(pcm), "-c:a", "libvorbis", "-q:a", "5", str(destination)], check=True)
    return {"source": source.name, "sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "seconds": round(len(samples) / rate, 4), "mono": mono, "trim_seconds": trim, "crossfade_seconds": crossfade, "gain": gain}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sfx-dir", type=pathlib.Path, required=True)
    parser.add_argument("--theme", type=pathlib.Path, required=True)
    args = parser.parse_args()
    output = pathlib.Path(__file__).resolve().parents[1] / "assets/audio"
    output.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for aircraft in ("spitfire", "gladiator"):
        for sound in ("engine_idle_loop", "engine_flight_loop", "303_guns_burst"):
            name = f"{aircraft}_{sound}"
            gun = sound == "303_guns_burst"
            manifest[name + ".ogg"] = convert(args.sfx_dir / (name + ".wav"), output / (name + ".ogg"), trim=(0.13, 2.86) if gun else None, crossfade=0.025 if gun else 0.08)
    manifest["main_menu.ogg"] = convert(args.theme, output / "main_menu.ogg", crossfade=0, mono=False, gain=2.2)
    (output / "conversion.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
