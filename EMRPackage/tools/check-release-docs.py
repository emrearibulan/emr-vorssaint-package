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
    if feature.get("menuTitle") != feature["name"] or feature.get("menuIcon") != "emr-triangle":
        errors.append("Use a plain menuTitle with the emr-triangle menuIcon: " + feature["name"])
    if feature["name"].endswith(" -emr"):
        errors.append("Remove the obsolete text suffix: " + feature["name"])
    if feature["name"] not in readme:
        errors.append("Document the top-level menuTitle in README: " + feature["name"])
    link = "EMRPackage/" + feature["documentation"]
    if f'[{feature["name"]}]({link})' not in readme or not (root / link).is_file():
        errors.append("Document the bundled feature in README: " + feature["name"])
if "triangular emr icon before the title" not in readme or not (root / "EMRPackage/assets/emr-mark.svg").is_file():
    errors.append("Document and include the triangular emr feature mark")
if errors:
    sys.exit("Release documentation needs attention:\n- " + "\n- ".join(errors))
print(f"Release documentation matches emr package {version} and its feature catalogue.")
