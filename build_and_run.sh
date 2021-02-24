#!/bin/bash

# This is a script used to Automatically build the OS

WD="/Users/mthilton/Documents/projects/Write_Your_Own_OS"

echo "Creating Build Enviornment!" 
mv $WD/bldenv/Dockerfile_autobuild $WD/bldenv/Dockerfile
docker build bldenv -t build_myos && \
echo "Done!
Building Operating System!" && \
docker run --rm -it -v $PWD:/root/env build_myos && \
echo "Done!
Removing Docker Image" && \
docker rmi build_myos -f && \
mv $WD/bldenv/Dockerfile $WD/bldenv/Dockerfile_autobuild && \
echo "Done!
Starting OS Image using Qemu!" && \
qemu-system-x86_64 -cdrom dist/x86_64/kernel.iso && \
echo "User Quit the program!"

