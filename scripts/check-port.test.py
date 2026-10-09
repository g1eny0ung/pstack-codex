#!/usr/bin/env python3
"""Exercise the port checker against complete and deliberately changed plugin trees."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--upstream', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='pstack-port-test-') as temporary:
    plugin = Path(temporary) / 'plugin'
    shutil.copytree(root / 'plugins/pstack-codex', plugin, ignore=shutil.ignore_patterns('node_modules', '__pycache__', '.DS_Store'))
    command = [sys.executable, str(root / 'scripts/check-port.py'), '--upstream', str(args.upstream.resolve()), '--plugin', str(plugin)]
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    skill = plugin / 'skills/poteto-mode/SKILL.md'
    original = skill.read_bytes()
    skill.write_bytes(original.replace(b"fix it in its own PR", b"fix it as part of the current feature", 1))
    assert skill.read_bytes() != original
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 1 and 'Unaccounted difference: skills/poteto-mode/SKILL.md' in result.stdout, result.stdout
    skill.write_bytes(original)
    copied = plugin / 'skills/principle-prove-it-works/SKILL.md'
    original = copied.read_bytes()
    copied.unlink()
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 1 and 'Unaccounted difference: skills/principle-prove-it-works/SKILL.md' in result.stdout, result.stdout
    copied.write_bytes(original)
    extra = plugin / 'skills/poteto-mode/references/unreviewed.md'
    extra.write_text('An unreviewed workflow change.\n')
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 1 and 'Unaccounted local file:' in result.stdout, result.stdout
    extra.unlink()
    metadata = plugin / 'skills/poteto-mode/agents/openai.yaml'
    original = metadata.read_bytes()
    metadata.unlink()
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 1 and 'Missing Codex invocation metadata: poteto-mode' in result.stdout, result.stdout
    metadata.write_bytes(original)
    metadata.write_bytes(original.replace(b'  allow_implicit_invocation: false', b'  # allow_implicit_invocation: false\n  allow_implicit_invocation: true'))
    assert metadata.read_bytes() != original
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 1 and 'Unaccounted Codex metadata change:' in result.stdout, result.stdout
    metadata.write_bytes(original)
    for relative in ['skills/extra-reference/playbook.md', 'unexpected.txt']:
        extra = plugin / relative
        extra.parent.mkdir(parents=True, exist_ok=True)
        extra.write_text('Unrecorded packaged file.\n')
        result = subprocess.run(command, text=True, capture_output=True)
        assert result.returncode == 1 and f'Unaccounted local file: {relative}' in result.stdout, result.stdout
        extra.unlink()
    excluded = plugin / 'skills/poteto-mode/scripts/bootstrap.ts'
    excluded.write_text('installIntoPluginCache();\n')
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 1 and 'Excluded file was reintroduced:' in result.stdout, result.stdout
print('9 port-checker scenarios passed')
