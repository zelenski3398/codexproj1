#!/usr/bin/env python3
"""Export an isolated test scene without modifying the playable game/build.

Copies the real project to /tmp, changes only its initial scene to the landing-return
fixture, imports and exports. The production export still excludes all tests.
"""
import os
import pathlib
import shutil
import subprocess
import tempfile

project = pathlib.Path(__file__).resolve().parents[1]
output = project / "builds/return-test"
output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="malta-return-fixture-") as temporary:
    copied = pathlib.Path(temporary) / "project"
    shutil.copytree(project, copied, ignore=shutil.ignore_patterns(".git", ".godot", "builds", "__pycache__"))
    # Reuse matching local imports when available; exports still run in isolation.
    if (project / ".godot").is_dir():
        shutil.copytree(project / ".godot", copied / ".godot")
    configuration = copied / "project.godot"
    text = configuration.read_text()
    text = text.replace('run/main_scene="res://main.tscn"', 'run/main_scene="res://return_fixture.tscn"')
    if 'run/main_scene="res://return_fixture.tscn"' not in text:
        raise ValueError("Main scene override failed")
    configuration.write_text(text)
    shutil.copyfile(project / "tests/mission_return_web_fixture.gd", copied / "return_fixture.gd")
    (copied / "return_fixture.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://return_fixture.gd" id="1"]\n[node name="ReturnFixture" type="Node"]\nscript = ExtResource("1")\n')
    for arguments in (["--editor", "--import", "--quit"], ["--export-release", "Web", str(output / "index.html")]):
        subprocess.run([os.getenv("GODOT_BIN", "godot"), "--headless", "--path", str(copied), *arguments], check=True)
print("Isolated landing-return fixture:", output)
