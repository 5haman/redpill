#!/bin/bash

set -e; [ "$DEBUG" == "true" ] && set -x

if [ $# -eq 0 ]; then
    /bin/bash
else
    "$@"
fi
