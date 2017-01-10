#!/bin/bash

export GOPATH=/tmp/go
export PATH="$PATH:$GOPATH/bin"

git clone -b master --depth 1 https://github.com/yudai/gotty $GOPATH/src/github.com/yudai/gotty
cd $GOPATH/src/github.com/yudai/gotty
git submodule sync && git submodule update --init --recursive
make tools
GOOS=linux && GOARCH=arm64 && CGO_ENABLED=0 go build -a -ldflags '-extldflags "-static"' -buildmode=exe -o /tmp/gotty .
strip --strip-all /tmp/gotty
