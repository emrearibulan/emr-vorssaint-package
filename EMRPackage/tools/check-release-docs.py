#!/usr/bin/env python3
"""Check that release documentation matches the package being published."""
import json
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
data = json.loads((root / "EMRPackage/package.json").read_text())
readme = (root / "README.md").read_text()
changelog = (root / "EMRPackage/CHANGELOG.md").read_text()
version = data["version"]
errors = []
if f"**Version:** {version}" not in readme or f"--branch emr-v{version} " not in readme:
    errors.append("Update README version and installation tag to match package.json")
latest = re.search(r"^## (\d+\.\d+\.\d+)\b", changelog, re.MULTILINE)
if not latest or latest.group(1) != version:
    errors.append("Add the current release as the first version in EMRPackage/CHANGELOG.md")
for feature in data["features"]:
    if feature.get("menuTitle") != feature["name"] + " -emr" or feature["name"].endswith(" -emr"):
        errors.append("Top-level feature menuTitle must append exactly ' -emr': " + feature["name"])
    if feature.get("menuTitle", "") not in readme:
        errors.append("Document the displayed top-level menuTitle in README: " + feature["name"])
    link = "EMRPackage/" + feature["documentation"]
    if f'[{feature["name"]}]({link})' not in readme or not (root / link).is_file():
        errors.append("Document the bundled feature in README: " + feature["name"])
if errors:
    sys.exit("Release documentation needs attention:\n- " + "\n- ".join(errors))
print(f"Release documentation matches emr package {version} and its feature catalogue.")
