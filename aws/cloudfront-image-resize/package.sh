#!/bin/bash

rm -rf build
mkdir build

pip3 install . --target build --platform=manylinux2014_x86_64 --only-binary=:all:
(cd build && zip -r ../package.zip .)
rm -rf build
