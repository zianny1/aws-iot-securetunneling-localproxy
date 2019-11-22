#!/bin/sh
set -ex
wget https://github.com/protocolbuffers/protobuf/releases/download/v3.6.1/protobuf-all-3.6.1.tar.gz -0 /tmp/protobuf-all-3.6.1.tar.gz
tar -xvf /tmp/protobuf-all-3.6.1.tar.gz
pushd protobuf-all-3.6.1.tar.gz && mkdir build && cmake ../cmake && make && sudo make install && popd
