"""Convert the three user-supplied defence WAVs; retain complete content."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--source-dir', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = root / 'assets/audio/defence'
output.mkdir(parents=True, exist_ok=True)
sources = {
    'jericho_trumpet': 'stuka_jericho_trumpet.wav',
    'air_raid_siren': 'malta_wwii_air_raid_siren.wav',
    'harrington_intro': 'colonel_harrington_wwii_radio_static.wav',
}
records = {}
for key, filename in sources.items():
    source = args.source_dir / filename
    relative = f'assets/audio/defence/{key}.ogg'
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(source),
                    '-af', 'loudnorm=I=-19:TP=-2:LRA=10', '-ar', '44100', '-ac', '1',
                    '-c:a', 'libvorbis', '-q:a', '5', str(root / relative)], check=True)
    records[key] = {'source': filename, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                    'output': relative,
                    'processing': 'mono 44100 Hz; loudnorm I=-19 TP=-2 LRA=10; libvorbis q5; complete supplied recording'}
(output / 'sources.json').write_text(json.dumps(records, indent=2) + '\n')
