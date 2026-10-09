#!/usr/bin/env python3
"""Report changed upstream files with recorded Codex adaptations (exit 2 for review)."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


def relative_path(value):
    return (isinstance(value, str) and bool(value) and '\0' not in value
            and all(part not in ('', '.', '..') for part in value.split('/')))


def load_adaptations(path, base):
    manifest = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(manifest, dict) or type(manifest.get('version')) is not int or manifest['version'] != 1:
        raise ValueError('Expected adaptation manifest version 1')
    if manifest.get('upstream_commit') != base:
        raise ValueError('Adaptation manifest must match the synchronized upstream commit')
    if not isinstance(manifest.get('files'), list) or not manifest['files']:
        raise ValueError('Adaptation manifest files must be a nonempty list')
    adapted, sources, targets = {}, set(), set()
    for row in manifest['files']:
        if not isinstance(row, dict) or not relative_path(row.get('source')) or not relative_path(row.get('target')):
            raise ValueError('Adaptation mapping requires relative source and target file paths')
        source, target = row['source'], row['target']
        if source in sources or target in targets:
            raise ValueError(f'Duplicate adaptation mapping: {source} -> {target}')
        sources.add(source)
        targets.add(target)
        if not isinstance(row.get('source_sha256'), str) or not re.fullmatch(r'[0-9a-f]{64}', row['source_sha256']):
            raise ValueError(f'Invalid source_sha256 for {source}')
        if not isinstance(row.get('edits'), list):
            raise ValueError(f'Adaptation edits must be a list for {source}')
        for edit in row['edits']:
            if (not isinstance(edit, dict) or edit.get('kind') not in ('host', 'model', 'scope', 'metadata')
                    or not isinstance(edit.get('reason'), str) or not edit['reason'].strip()
                    or not isinstance(edit.get('old'), str) or not edit['old']
                    or not isinstance(edit.get('new'), str)
                    or type(edit.get('count')) is not int or edit['count'] < 1):
                raise ValueError(f'Invalid or unjustified adaptation for {source}')
        if row['edits']:
            adapted[source] = row
    return adapted


def git(git_dir, *args):
    result = subprocess.run(['git', f'--git-dir={git_dir}', *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise ValueError(f"Git {args[0]} failed: {result.stderr.decode('utf-8', errors='replace').strip()}")
    return result.stdout


def changes(raw):
    if not raw:
        return
    fields = raw.split(b'\0')
    if fields.pop() != b'':
        raise ValueError('Incomplete Git diff')
    index = 0
    while index < len(fields):
        status = fields[index].decode('ascii')
        index += 1
        if not re.fullmatch(r'[ADMT]|[RC][0-9]{1,3}|M[0-9]{1,3}', status):
            raise ValueError(f'Unexpected Git diff status: {status!r}')
        count = 2 if status[0] in 'RC' else 1
        paths = fields[index:index + count]
        if len(paths) != count or not all(paths):
            raise ValueError('Incomplete Git diff paths')
        index += count
        yield status, tuple(path.decode('utf-8', errors='surrogateescape') for path in paths)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--git-dir', type=Path, required=True)
    parser.add_argument('--base', required=True)
    parser.add_argument('--target', required=True)
    args = parser.parse_args()
    if not all(re.fullmatch(r'[0-9a-f]{40}', commit) for commit in (args.base, args.target)):
        raise ValueError('Expected full 40-character commit IDs')
    manifest = Path(__file__).resolve().with_name('port-adaptations.json')
    adapted = load_adaptations(manifest, args.base)
    for source, row in adapted.items():
        blob = f'{args.base}:{source}'
        if git(args.git_dir, 'cat-file', '-t', blob).strip() != b'blob':
            raise ValueError(f'Adapted baseline source is not a file: {source}')
        if hashlib.sha256(git(args.git_dir, 'cat-file', 'blob', blob)).hexdigest() != row['source_sha256']:
            raise ValueError(f'Upstream source differs from recorded baseline: {source}')
    raw = git(args.git_dir, 'diff', '--no-ext-diff', '--name-status', '-z', '--find-renames', args.base, args.target, '--')
    impacts = [(status, paths, adapted[source]) for status, paths in changes(raw)
               for source in dict.fromkeys(paths) if source in adapted]
    if not impacts:
        print('No recorded adaptations affected. This does not approve synchronization.')
        return 0
    print('ADAPTATION_REVIEW_REQUIRED')
    print(f'Baseline: {args.base}\nTarget: {args.target}')
    print('Human review required. Decide retain, revise, or remove for each adaptation before changing plugin files, the manifest, or the synced baseline.')
    for status, paths, row in impacts:
        print(f"\nChange: {status}\t" + ' -> '.join(json.dumps(path) for path in paths))
        print('Source: ' + json.dumps(row['source']))
        print('Local target: ' + json.dumps('plugins/pstack-codex/' + row['target']))
        for edit in row['edits']:
            print(f"  [{edit['kind']}] {json.dumps(edit['reason'])}")
    return 2


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, UnicodeError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
