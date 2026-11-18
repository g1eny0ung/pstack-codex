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
root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='pstack-port-test-') as temporary:
    plugin = Path(temporary) / 'plugin'
    shutil.copytree(root / 'plugins/pstack-codex', plugin, ignore=shutil.ignore_patterns('node_modules', '__pycache__', '.DS_Store'))
    command = [sys.executable, str(Path(__file__).resolve().with_name('check-port.py')), '--upstream', str(args.upstream.resolve()), '--plugin', str(plugin)]
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    skill = plugin / 'skills/poteto-mode/SKILL.md'
    original = skill.read_bytes()
    skill.write_bytes(original.replace(b"Apply this workflow to the current requested task.", b"Apply this workflow to every task.", 1))
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
    metadata = plugin / 'skills/poteto-mode/agents/openai.yaml'
    original = metadata.read_bytes()
    metadata.unlink()
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 1 and 'Missing Codex invocation metadata: poteto-mode' in result.stdout, result.stdout
    metadata.write_bytes(original + b'\n# Keep this metadata explicit.\n')
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    metadata.write_bytes(original)
    extra_files = [
        'skills/poteto-mode/references/unreviewed.md',
        'skills/extra-reference/playbook.md',
        'unexpected.txt',
    ]
    for relative in extra_files:
        extra = plugin / relative
        extra.parent.mkdir(parents=True, exist_ok=True)
        extra.write_text('Unrecorded packaged file.\n')
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 1, result.stdout + result.stderr
    for relative in extra_files:
        assert f'Unaccounted local file: {relative}' in result.stdout, result.stdout
        (plugin / relative).unlink()
    excluded = plugin / 'skills/poteto-mode/scripts/bootstrap.ts'
    excluded.write_text('installIntoPluginCache();\n')
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == 1 and 'Excluded file was reintroduced:' in result.stdout, result.stdout
print('7 port-checker scenarios passed')
