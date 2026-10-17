#!/usr/bin/env python3
"""Prepare PROVIDED pilot recordings. No TTS; neutral prefix avoids stale tactics.

Arguments: Faith MP3, Hope MP3, Charity MP3 (roles from spoken identification).
Full takes remain available separately. Light normalization/fades only: the
provided recordings already carry their voice treatment, so do not stack the
existing commander's narrow band-pass/static over them a second time.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def prepare(source, callsign, end):
    out = ROOT / 'assets/audio/harbour/status'
    out.mkdir(parents=True, exist_ok=True)
    for kind, duration in [('full', None), ('identification', end)]:
        command = ['ffmpeg', '-v', 'error', '-y', '-i', str(source)]
        if duration is not None:
            command += ['-t', str(duration)]
        filters = 'loudnorm=I=-16:TP=-2:LRA=7,afade=t=in:d=0.015'
        if duration is not None:
            filters += f',afade=t=out:st={duration - .045}:d=0.045'
        command += ['-af', filters, '-ac', '1', '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '5', str(out / f'{callsign}_{kind}.ogg')]
        subprocess.run(command, check=True)
    manifest = {'speaker': callsign.upper(), 'source': source.name,
                'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'identification_seconds': end,
                'identification_text': f'Control, this is {callsign.title()}.',
                'processing': 'Mono; -16 LUFS normalization; 15/45 ms fades. Existing treatment retained; no added band-pass/static.',
                'speech_generated': False,
                'transcription_note': 'Role and prefix checked with local automatic recognition; full take is not used as a universal status report.'}
    (out / f'{callsign}.json').write_text(json.dumps(manifest, indent=2) + '\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('faith', type=Path)
    parser.add_argument('hope', type=Path)
    parser.add_argument('charity', type=Path)
    args = parser.parse_args()
    for name, end in [('faith', 1.70), ('hope', 1.78), ('charity', 1.88)]:
        prepare(getattr(args, name), name, end)
