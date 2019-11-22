#!/bin/sh
set -ex
wget https://dl.bintray.com/boostorg/release/1.69.0/source/boost_1_69_0.tar.gz -O /tmp/boost.tar.gz
tar -xvf /tmp/boost.tar.gz
pushd boost_1_69_0 && ./bootstrap.sh --prefix=/usr && ./b2 install --prefix=/usr && popd
