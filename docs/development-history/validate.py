#!/usr/bin/env python3
"""Validate this historical documentation snapshot without changing the game.
Run from any directory: python docs/development-history/validate.py
Mermaid rendering is a separate check; see validation.md.
"""
from pathlib import Path
import collections
import json
import re
import subprocess
import urllib.parse

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

def git(*arguments):
    return subprocess.check_output(['git', *arguments], cwd=ROOT, text=True).strip()

def anchors(text):
    result = set(re.findall(r'<a id="([^"]+)"', text))
    counts = collections.Counter()
    for heading in re.findall(r'^#{1,6} +(.+)$', text, re.M):
        anchor = re.sub(r'[^\w\- ]', '', heading.lower()).replace(' ', '-')
        number = counts[anchor]
        counts[anchor] += 1
        result.add(anchor + ('-' + str(number) if number else ''))
    return result

errors = []
count_links = 0
files = sorted(HERE.rglob('*.md')) + [ROOT / 'docs/WWII-Malta-Development-Complete.md']
for file in files:
    text = file.read_text()
    for target in re.findall(r'\]\(([^)]+)\)', text):
        if re.match(r'https?://', target):
            continue
        count_links += 1
        path, _, fragment = target.partition('#')
        destination = (file.parent / urllib.parse.unquote(path)).resolve() if path else file
        if not destination.exists():
            errors.append(f'{file.name}: missing {target}')
        elif fragment and destination.suffix == '.md' and fragment not in anchors(destination.read_text()):
            errors.append(f'{file.name}: missing anchor {target}')
        elif fragment and destination.suffix != '.md' and re.fullmatch(r'L\d+', fragment):
            if int(fragment[1:]) > len(destination.read_text().splitlines()):
                errors.append(f'{file.name}: source line beyond EOF {target}')

stats = json.loads((HERE / 'statistics.json').read_text())
evidence = json.loads((HERE / 'commit-evidence.json').read_text())
shas = {record['sha'] for record in evidence}
reachable = set(git('rev-list', stats['head']).splitlines())
if len(evidence) != len(shas) or shas != reachable:
    errors.append('Commit manifest is duplicated or does not cover snapshot history exactly')
reference = (HERE / '14-commit-reference.md').read_text()
for sha in shas:
    if f'<a id="{sha[:7]}"></a>' not in reference or sha not in reference:
        errors.append(f'Missing per-commit reference: {sha}')
    record = next(c for c in evidence if c['sha'] == sha)
    parents = git('show', '-s', '--format=%P', sha).split()
    changed = [line.split('\t') for line in git('diff-tree', '--root', '--no-commit-id', '--name-status', '-r', sha).splitlines()]
    if record['parents'] != parents or record['files'] != changed:
        errors.append(f'Commit parents/path inventory differs from Git: {sha}')

sources = {p.name: p.read_text().strip() for p in (HERE / 'diagrams').glob('*.mmd')}
blocks = [block.strip() for file in files for block in re.findall(r'```mermaid\n(.*?)\n```', file.read_text(), re.S)]
for name, source in sources.items():
    if source not in blocks:
        errors.append(f'Diagram source has no matching rendered Markdown block: {name}')
for block in blocks:
    if block not in sources.values():
        errors.append('Embedded Mermaid block differs from all maintained diagram sources')
if len(sources) != stats['unique_diagrams']:
    errors.append('Unique diagram count differs from statistics')

paths = git('ls-tree', '-r', '--name-only', stats['head']).splitlines()
for key, actual in [('tracked_files', len(paths)), ('gdscript', sum(p.endswith('.gd') for p in paths)), ('scenes', sum(p.endswith('.tscn') for p in paths)), ('resources', sum(p.endswith('.tres') for p in paths))]:
    if stats[key] != actual:
        errors.append(f'Incorrect snapshot statistic: {key}')
activity = collections.Counter()
for record in evidence:
    import datetime
    activity[datetime.datetime.fromisoformat(record['date']).astimezone(datetime.timezone.utc).date().isoformat()] += 1
if dict(activity) != stats['daily']:
    errors.append('Daily activity differs from Git timestamp evidence')

# Pattern checks are a limited safeguard, not a claim of exhaustive secret detection.
secret_patterns = [r'gh[pousr]_[A-Za-z0-9]{30,}', r'github_pat_[A-Za-z0-9_]{50,}', r'AKIA[0-9A-Z]{16}', r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----']
for file in HERE.rglob('*'):
    if file.is_file() and file.suffix in {'.md', '.json', '.mmd', '.csv', '.svg'}:
        if any(re.search(pattern, file.read_text()) for pattern in secret_patterns):
            errors.append(f'Potential credential/key material: {file.name}')

report = dict(markdown_files=len(files), local_links=count_links, commits=len(evidence), unique_mermaid_sources=len(sources), embedded_mermaid_blocks=len(blocks), errors=errors)
print(json.dumps(report, indent=2))
raise SystemExit(1 if errors else 0)
