#!/bin/bash

docker run --rm -it -v $PWD:/root/env build_myos && \
qemu-system-x86_64 -cdrom dist/x86_64/kernel.iso  
