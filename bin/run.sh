#!/usr/bin/env bash

set -euo pipefail

. "config.sh"
. "external.sh"
. "libexec.sh"

for call in "$@"; do
    log "Executing $call"
    "$call"
done

