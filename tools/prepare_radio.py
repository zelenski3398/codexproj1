#!/usr/bin/env python3
"""Prepare a PROVIDED commander recording; never synthesizes speech.

Usage: python3 tools/prepare_radio.py /path/to/supplied-voice.mp3
Requires ffmpeg and numpy only during asset preparation. Mild speech band-pass,
normalization, quiet static and short opening/closing clicks are baked into the
mono Ogg so Godot native streaming and browser sample playback sound identical.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile
import wave

import numpy as np


def prepare(source, destination):
    rate = 44100
    decoded = subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(source),
        "-af", "highpass=f=180,lowpass=f=3800,loudnorm=I=-16:TP=-2:LRA=7",
        "-ac", "1", "-ar", str(rate), "-f", "f32le", "pipe:1",
    ], check=True, capture_output=True).stdout
    voice = np.frombuffer(decoded, dtype="<f4").astype(np.float64)
    if len(voice) == 0 or np.max(np.abs(voice)) < 0.0001:
        raise ValueError("The supplied recording contains no usable audio")
    voice_rms = float(np.sqrt(np.mean(voice ** 2)))
    prefix, suffix = round(0.08 * rate), round(0.12 * rate)
    mixed = np.pad(voice, (prefix, suffix))
    # Static RMS is 36 dB below the voice RMS, never louder than speech.
    rng = np.random.default_rng(1940)
    static = rng.normal(0, voice_rms * 10 ** (-36 / 20), len(mixed))
    envelope = np.minimum(np.arange(len(mixed)) / (rate * 0.015), 1)
    envelope *= np.minimum(np.arange(len(mixed))[::-1] / (rate * 0.015), 1)
    mixed += static * envelope
    count = round(rate * 0.018)
    click = rng.normal(0, voice_rms * 0.12, count) * np.hanning(count)
    mixed[round(rate * 0.02):round(rate * 0.02) + count] += click
    end = len(mixed) - round(rate * 0.05) - count
    mixed[end:end + count] += click
    peak = float(np.max(np.abs(mixed)))
    if peak > 0.95:
        mixed *= 0.95 / peak
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        pcm = pathlib.Path(temporary) / "radio.wav"
        with wave.open(str(pcm), "wb") as writer:
            writer.setnchannels(1)
            writer.setsampwidth(2)
            writer.setframerate(rate)
            writer.writeframes((mixed * 32767).astype("<i2").tobytes())
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(pcm),
            "-c:a", "libvorbis", "-q:a", "5", str(destination),
        ], check=True)
    return {"source": source.name, "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "seconds": len(mixed) / rate, "mono": True, "bandpass_hz": [180, 3800],
            "voice_loudness_lufs": -16, "static_relative_rms_db": -36,
            "click_seconds": 0.018, "speech_generated": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=pathlib.Path)
    args = parser.parse_args()
    output = pathlib.Path(__file__).resolve().parents[1] / "assets/audio/commander_formation_detected.ogg"
    manifest = prepare(args.source, output)
    output.with_suffix(".json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
