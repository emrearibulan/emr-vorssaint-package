#!/bin/zsh
set -euo pipefail
EMR_PACKAGE_ROOT="${0:A:h:h}"
cd "$EMR_PACKAGE_ROOT"
exec python3 EMRPackage/tools/install.py "$@"
