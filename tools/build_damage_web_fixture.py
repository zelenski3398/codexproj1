#!/usr/bin/env python3
"""Export an isolated test scene without modifying the playable game/build.

Copies the real project to /tmp, changes only its initial scene to the audio
fixture, imports and exports. The production export still excludes all tests.
"""
import os
import pathlib
import shutil
import subprocess
import tempfile

project = pathlib.Path(__file__).resolve().parents[1]
output = project / "builds/universal-damage-test"
output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="malta-damage-fixture-") as temporary:
    copied = pathlib.Path(temporary) / "project"
    shutil.copytree(project, copied, ignore=shutil.ignore_patterns(".git", ".godot", "builds", "__pycache__"))
    configuration = copied / "project.godot"
    text = configuration.read_text()
    text = text.replace('run/main_scene="res://main.tscn"', 'run/main_scene="res://universal_damage_fixture.tscn"')
    if 'run/main_scene="res://universal_damage_fixture.tscn"' not in text:
        raise ValueError("Main scene override failed")
    configuration.write_text(text)
    shutil.copyfile(project / "tests/universal_damage_web_fixture.gd", copied / "universal_damage_fixture.gd")
    (copied / "universal_damage_fixture.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://universal_damage_fixture.gd" id="1"]\n[node name="UniversalDamageFixture" type="Node3D"]\nscript = ExtResource("1")\n')
    for arguments in (["--editor", "--import", "--quit"], ["--export-release", "Web", str(output / "index.html")]):
        subprocess.run([os.getenv("GODOT_BIN", "godot"), "--headless", "--path", str(copied), *arguments], check=True)
print("Isolated damage fixture:", output)
