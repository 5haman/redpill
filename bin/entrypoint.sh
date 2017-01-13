#!/bin/bash
set -e; [ "$debug" == "true" ] && set -x

if [ $# -eq 0 ]; then
    /bin/bash
else
    "$@"
fi
