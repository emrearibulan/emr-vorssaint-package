#!/bin/zsh
# Build the emr source additions inside Vorssaint, with its normal app identity.
set -euo pipefail
cd "${0:A:h}"
export EMR_BUILD_JOBS="${EMR_BUILD_JOBS:-2}"
exec /bin/zsh ./build.sh --emr "$@"
