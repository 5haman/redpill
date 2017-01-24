#!/bin/sh

set -e; [ "$DEBUG" == "true" ] && set -x

#TOMLV_COMMIT=9baf8a8a9f2ed20a8e54160840c492f937eeaf9a
GO_LINT_COMMIT=32a87160691b3c96046c0c678fe57c5bef761456
GO_TOOLS_COMMIT=823804e1ae08dbb14eb807afc7db9993bc9e3cc3
RUNC_COMMIT=50a19c6ff828c58e5dab13830bd3dacde268afe5
CONTAINERD_COMMIT=2a5e70cbf65457815ee76b7e5dd2a01292d9eca8
#TINI_COMMIT=949e6facb77383876aeff8a6944dde66b3089574
#LIBNETWORK_COMMIT=0f534354b813003a754606689722fe253101bc4e
#VNDR_COMMIT=f56bd4504b4fad07a357913687fb652ee54bb3b0
#BINDATA_COMMIT=a0ff2567cfb70903282db057e799fd826784d41d

OUTDIR="/opt/build/local/docker"

build_tools() {
	git clone https://github.com/golang/tools.git "$GOPATH/src/golang.org/x/tools"
	cd "$GOPATH/src/golang.org/x/tools"
	git checkout -q $GO_TOOLS_COMMIT
	go install -v golang.org/x/tools/cmd/cover
	go install -v golang.org/x/tools/cmd/vet
	
	# Grab Go's lint tool
	git clone https://github.com/golang/lint.git "$GOPATH/src/github.com/golang/lint"
	cd /go/src/github.com/golang/lint && git checkout -q $GO_LINT_COMMIT
	go install -v github.com/golang/lint/golint
}

build_runc() {
	git clone https://github.com/docker/runc.git "$GOPATH/src/github.com/opencontainers/runc"
	cd "$GOPATH/src/github.com/opencontainers/runc"
	git checkout -q "$RUNC_COMMIT"
	make BUILDTAGS="" static
	strip --strip-all runc
	cp runc $OUTDIR/docker-runc
}

build_containerd() {
	git clone https://github.com/docker/containerd.git "$GOPATH/src/github.com/docker/containerd"
	cd "$GOPATH/src/github.com/docker/containerd"
	git checkout -q "$CONTAINERD_COMMIT"
	make static
	strip --strip-all bin/*
	cp bin/containerd $OUTDIR/docker-containerd
	cp bin/containerd-shim $OUTDIR/docker-containerd-shim
	cp bin/ctr $OUTDIR/docker-containerd-ctr
}

build_proxy() {
	cd "$GOPATH/src/github.com/docker/docker"
	source "hack/make/.binary-setup"
    	export BINARY_SHORT_NAME="docker-proxy"
	export SOURCE_PATH='./vendor/src/github.com/docker/libnetwork/cmd/proxy'
    	source "hack/make/.binary"
}	

build_docker() {
	cd "$GOPATH/src/github.com/docker/docker"
	. hack/make.sh binary-client
}	

build_dockerd() {
	cd "$GOPATH/src/github.com/docker/docker"
	make
	. hack/make.sh binary

	#source "hack/make/.binary-setup"
    	#export BINARY_SHORT_NAME="dockerd"
    	#export SOURCE_PATH='./cmd/dockerd'
    	#source "hack/make/.binary"
	
        #go install -v github.com/docker/docker/cmd/dockerd
        #go install -v github.com/docker/docker/cmd/docker
	#go build -ldflags="-static" .
	#go build -ldflags="-static" cmd/dockerd -o dockerd
        #strip --strip-all docker dockerd
}

mkdir -p $OUTDIR
#export MAKEDIR="$GOPATH/src/github.com/docker/docker/hack/make"

build_runc
build_containerd
#build_proxy
#export AUTO_GOPATH=1
#export DOCKER_GITCOMMIT=v1.12.6
#export DOCKER_BUILDTAGS="exclude_graphdriver_aufs exclude_graphdriver_devicemapper"
#unset CC

#build_docker
#build_dockerd

#export CGO_ENABLED=0
#install_proxy
