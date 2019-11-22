#!/bin/sh
set -ex
git clone https://github.com/catchorg/Catch2.git Catch2
#all we need is a header file out of the repository so no build
pushd Catch2 && cmake -Bbuild -H. -DBUILD_TESTING=OFF && cmake --build build/ --target install && popd
#pushd Catch2 && mkdir build && cd build && cmake .. && make && make install && popd
