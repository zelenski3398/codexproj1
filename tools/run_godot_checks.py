#!/usr/bin/env python3
"""Run the complete publishing manifest, preserving failures and per-suite logs."""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def run_suite(command, output, timeout):
    script = next(token for token in command if token.startswith('res://tests/'))
    name = Path(script).stem
    log_path = output / (name + '.log')
    started = time.monotonic()
    command = [os.environ.get('GODOT_BIN', 'godot') if token == 'godot' else token
               for token in command]
    with tempfile.TemporaryDirectory(prefix='malta-check-') as temporary:
        environment = os.environ.copy()
        # Settings from other suites or previous runs cannot contaminate this one.
        for variable, folder in [('XDG_DATA_HOME', 'data'),
                                 ('XDG_CONFIG_HOME', 'config'),
                                 ('XDG_CACHE_HOME', 'cache')]:
            directory = Path(temporary) / folder
            directory.mkdir()
            environment[variable] = str(directory)
        with log_path.open('w') as log:
            try:
                process = subprocess.Popen(command, cwd=ROOT, env=environment,
                                           stdout=log, stderr=subprocess.STDOUT,
                                           start_new_session=True)
                try:
                    code = process.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                    log.write(f'CHECK ERROR: exceeded {timeout} seconds\n')
                    code = 124
            except OSError as error:
                log.write(f'CHECK ERROR: {error}\n')
                code = 127
    content = log_path.read_text(errors='replace')
    errors = [line for line in content.splitlines()
              if 'SCRIPT ERROR:' in line or 'Parse Error:' in line
              or re.match(r'^(?:ERROR: )?FAIL:', line)
              or line.startswith('CHECK ERROR:')]
    passed = code == 0 and not errors
    return {'suite': name, 'script': script, 'command': command,
            'exit_code': code, 'passed': passed,
            'seconds': round(time.monotonic() - started, 2),
            'errors': errors,
            'result_lines': [line for line in content.splitlines()
                             if 'RESULT:' in line or 'CHECKS:' in line],
            'log': log_path.name}


def save_results(output, results):
    (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    summary = ['# Godot publishing checks', '',
               '| Suite | Status | Seconds | Log |', '|---|---|---:|---|']
    for result in results:
        summary.append(f"| {result['suite']} | {'PASS' if result['passed'] else 'FAIL'} "
                       f"| {result['seconds']} | {result['log']} |")
    failed = sum(not result['passed'] for result in results)
    summary += ['', f'{len(results) - failed}/{len(results)} suites passed.', '']
    (output / 'summary.md').write_text('\n'.join(summary))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', nargs='+', help='Subset by script stem, for local diagnosis')
    parser.add_argument('--jobs', type=int, default=1)
    parser.add_argument('--timeout', type=float, default=600)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'builds/checks')
    options = parser.parse_args()
    if options.jobs < 1 or options.timeout <= 0:
        parser.error('jobs and timeout must be positive')
    commands = json.loads((ROOT / 'tests/publishing_checks.json').read_text())
    if not commands:
        parser.error('publishing manifest must not be empty')
    names = [Path(next(t for t in cmd if t.startswith('res://tests/'))).stem
             for cmd in commands]
    if len(set(names)) != len(names):
        parser.error('duplicate publishing suites')
    if options.only:
        unknown = set(options.only) - set(names)
        if unknown:
            parser.error('unknown suites: ' + ', '.join(sorted(unknown)))
        commands = [cmd for cmd, name in zip(commands, names) if name in options.only]
    output = options.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=options.jobs) as pool:
        futures = [pool.submit(run_suite, cmd, output, options.timeout) for cmd in commands]
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            results.append(result)
            print(f"{'PASS' if result['passed'] else 'FAIL'}: {result['suite']} "
                  f"({result['seconds']} s; exit {result['exit_code']})", flush=True)
            if os.environ.get('GITHUB_ACTIONS'):
                print(f"::group::{result['suite']}", flush=True)
                print((output / result['log']).read_text(errors='replace'), flush=True)
                print('::endgroup::', flush=True)
                if not result['passed']:
                    detail = result['errors'][0] if result['errors'] else f"exit {result['exit_code']}"
                    detail = detail.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
                    print(f"::error file={result['script'].removeprefix('res://')}::"
                          f"{result['suite']}: {detail}; see godot-check-logs/{result['log']}", flush=True)
            save_results(output, results)
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        with open(summary_path, 'a') as summary:
            summary.write((output / 'summary.md').read_text())
    failed = sum(not result['passed'] for result in results)
    print(f'PUBLISHING RESULT: {len(results) - failed}/{len(results)} suites passed')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
