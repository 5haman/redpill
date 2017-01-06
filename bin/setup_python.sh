#!/bin/bash

. "config.sh"

# install python packages via pip
if [ ! -d $BUILD_DIR/docker-registry-ui ]; then
    git clone --depth 1 https://github.com/ARKII/docker-registry-ui $BUILD_DIR/docker-registry-ui
fi

pip3 install container-transform
cd $BUILD_DIR/docker-registry-ui
pip3 install -r requirements.txt

# cleanup
find $PY_DIR -type d | grep -E "pycache|info$" | xargs rm -rf
find $PY_DIR/encodings -type f | grep -vE "init|undef|unicode|alias|utf|latin" | xargs rm

cd $PY_DIR
rm -rf email config-3.5m ctypes/macholib distutils distutils/command/wininst-* \
       ensurepip idlelib lib2to3 pydoc_data site-packages/pip* site-packages/setuptools* \
       sqlite3 tkinter turtle* unittest venv wsgiref xml/dom \
       multiprocessing xml site-packages/pkg_resources html xmlrpc
       
cd $PY_DIR/lib-dynload
rm -f _codecs* _bz2* _lzma* _sqlite* audioop* ossaudiodev*
