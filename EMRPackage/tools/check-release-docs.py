#!/usr/bin/env python3
"""Validate the integrated source release instructions and feature catalogue."""
import json
from pathlib import Path
import re
import sys
root = Path(__file__).resolve().parents[2]
data = json.loads((root / 'EMRPackage/package.json').read_text())
readme = (root / 'README.md').read_text()
changelog = (root / 'EMRPackage/CHANGELOG.md').read_text()
errors = []
if f"**Version:** {data['version']}" not in readme:
    errors.append('Update README version')
branch = data['developmentBranch'] if data.get('status') == 'unreleased' else 'emr-v' + data['version']
if f'--branch {branch} ' not in readme:
    errors.append('Update README clone branch/tag')
first = re.search(r'^## (\d+\.\d+\.\d+)\b', changelog, re.M)
if not first or first.group(1) != data['version']:
    errors.append('Update the first changelog version')
if data.get('architecture') != 'integrated-source-addon' or data['app']['bundleIdentifier'] != 'com.vorssaint.utils':
    errors.append('Retain the single integrated host identity')
if data['upstream']['commit'] not in readme:
    errors.append('Document the reviewed upstream commit')
for feature in data['features']:
    link = 'EMRPackage/' + feature['documentation']
    if f"[{feature['name']}]({link})" not in readme or not (root / link).is_file():
        errors.append('Document feature: ' + feature['name'])
    if feature.get('menuTitle') != feature['name'] or feature.get('menuIcon') != 'emr-triangle':
        errors.append('Retain plain titles with the supplied logo')
if 'triangular emr icon before the title' not in readme:
    errors.append('Document top-level-only branding')
if not (root / 'Sources/Vorssaint/Extensions/emr').is_dir():
    errors.append('Keep source additions in the emr module')
if errors:
    sys.exit('\n'.join(errors))
print('Integrated source documentation and catalogue match emr ' + data['version'])
