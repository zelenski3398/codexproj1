#!/usr/bin/env python3
"""Build a forward/return poster cycle without a hard final-to-first pose jump.
Input must be the original, forward-only supplied clip (not this tool's output).
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def probe(path):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-count_frames', '-show_streams', '-show_format',
        '-of', 'json', str(path)], text=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.source.resolve() == args.output.resolve():
        parser.error('Use a separate original source; in-place input is not supported.')
    info = probe(args.source)
    video = next(s for s in info['streams'] if s['codec_type'] == 'video')
    count = int(video['nb_read_frames'])
    if count < 3:
        parser.error('At least three source frames are required.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=args.output.parent) as scratch:
        output = Path(scratch) / 'poster.ogv'
        # Each turning endpoint occurs once: 0..N-1, N-2..1, then 0 again.
        # Audio has its own independent full-length player, never this cycle.
        graph = (f'[0:v]split[f][r];[f]setpts=PTS-STARTPTS[fwd];'
                 f'[r]reverse,trim=start_frame=1:end_frame={count-1},'
                 'setpts=PTS-STARTPTS[back];'
                 '[fwd][back]concat=n=2:v=1:a=0,format=yuv420p[out]')
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                        '-filter_complex_threads', '1', '-i', str(args.source),
                        '-filter_complex', graph, '-map', '[out]', '-an',
                        '-r', video['r_frame_rate'], '-fps_mode', 'cfr',
                        '-c:v', 'libtheora', '-q:v', '7', '-threads', '1',
                        str(output)], check=True)
        result = probe(output)
        encoded = result['streams'][0]
        if len(result['streams']) != 1 or int(encoded['nb_read_frames']) != count*2-2:
            raise RuntimeError('Unexpected video frame count or embedded audio.')
        os.replace(output, args.output)
    print(json.dumps({'source_frames': count, 'loop_frames': count*2-2,
                      'duration_seconds': float(result['format']['duration']),
                      'width': encoded['width'], 'height': encoded['height']}))


if __name__ == '__main__':
    main()
