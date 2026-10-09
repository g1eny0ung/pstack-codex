#!/usr/bin/env python3
"""Check copied upstream files and the exact, documented Codex adaptations."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--upstream', type=Path, required=True, help='Extracted upstream repository at upstream.lock.json baseline')
parser.add_argument('--plugin', type=Path, help='Plugin tree to verify, defaults to this checkout')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
plugin = args.plugin or root / 'plugins/pstack-codex'
manifest = json.loads((root / 'scripts/port-adaptations.json').read_text())
lock = json.loads((root / 'upstream.lock.json').read_text())
problems = []
if manifest['version'] != 1 or manifest['upstream_commit'] != lock['last_synced_commit']:
    problems.append('Adaptation manifest must match the synchronized upstream commit')
sources = set()
targets = set()
identical = 0
for row in manifest['files']:
    source = args.upstream / row['source']
    target = plugin / row['target']
    if row['source'] in sources or row['target'] in targets:
        problems.append(f"Duplicate mapping: {row['source']} -> {row['target']}")
    sources.add(row['source'])
    targets.add(row['target'])
    if not source.is_file():
        problems.append(f'Missing upstream source: {source}')
        continue
    raw = source.read_bytes()
    if hashlib.sha256(raw).hexdigest() != row['source_sha256']:
        problems.append(f'Upstream source differs from recorded baseline: {source}')
        continue
    expected = raw.decode('utf-8')
    for edit in row['edits']:
        if edit['kind'] not in ('host', 'model', 'scope', 'metadata') or not edit['reason'].strip():
            problems.append(f"Unjustified adaptation: {row['target']}")
        if not edit['old'] or expected.count(edit['old']) != edit['count']:
            problems.append(f"Adaptation no longer matches its source: {row['target']}")
            break
        expected = expected.replace(edit['old'], edit['new'])
    if not target.is_file() or target.read_bytes() != expected.encode('utf-8'):
        problems.append(f"Unaccounted difference: {row['target']}")
    identical += not row['edits']
for skill in sorted((plugin / 'skills').iterdir()):
    if not (skill / 'SKILL.md').is_file():
        continue
    owner = 'cursor-team-kit' if skill.name in ('deslop', 'control-cli', 'control-ui') else 'pstack'
    upstream_skill = args.upstream / owner / 'skills' / skill.name
    if not upstream_skill.is_dir():
        problems.append(f'Unmapped skill: {skill.name}')
    for source in upstream_skill.rglob('*'):
        if source.is_file():
            relative = source.relative_to(args.upstream).as_posix()
            if relative not in sources and relative not in manifest['omitted']:
                problems.append(f'Unaccounted upstream file: {relative}')
    if not (skill / 'agents/openai.yaml').is_file():
        problems.append(f'Missing Codex invocation metadata: {skill.name}')
for local in plugin.rglob('*'):
    if not local.is_file() or 'node_modules' in local.parts or '__pycache__' in local.parts or local.name == '.DS_Store':
        continue
    relative = local.relative_to(plugin).as_posix()
    if relative in manifest['codex_metadata']:
        if hashlib.sha256(local.read_bytes()).hexdigest() != manifest['codex_metadata'][relative]:
            problems.append(f'Unaccounted Codex metadata change: {relative}')
    elif relative not in targets and relative not in manifest['local_only']:
        problems.append(f'Unaccounted local file: {relative}')
for relative in manifest['codex_metadata']:
    if not (plugin / relative).is_file():
        problems.append(f'Missing Codex metadata: {relative}')
for relative, omission in manifest['omitted'].items():
    if omission['kind'] not in ('host', 'scope') or not omission['reason'].strip():
        problems.append(f'Unjustified omission: {relative}')
    if '/skills/' in relative:
        local = plugin / 'skills' / relative.split('/skills/', 1)[1]
        if local.exists():
            problems.append(f'Excluded file was reintroduced: {local}')
for relative in manifest['local_only']:
    if not (plugin / relative).is_file():
        problems.append(f'Missing Codex adapter: {relative}')
for problem in problems:
    print(problem)
print(f"{len(targets)} mapped files, {identical} byte-identical, {len(manifest['omitted'])} documented omissions, {len(problems)} problems")
raise SystemExit(bool(problems))
