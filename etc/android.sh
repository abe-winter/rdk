#!/usr/bin/env bash
# build for android

set -euo pipefail

# apt-get deps:
# sudo apt install clang libx264-dev pkg-config libnlopt-dev libjpeg-dev

NDK_ROOT=~/build/android-ndk-r25c
GOOS=android GOARCH=arm64 CGO_ENABLED=1 \
	CC=clang \
	CGO_CFLAGS=-I$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include \
	CGO_LDFLAGS=-L$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/19 \
	go build \
	-tags no_tflite,no_pigpio,android \
	./web/cmd/server
# awinter@awfw13:~/repo/rdk$ export GOFLAGS="-tags=no_tflite,no_pigpio,android" && CGO_CFLAGS="-I/home/awinter/build/android-ndk-r25c/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include" go build ./web/cmd/server
# CC=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android30-clang \
# CGO_CPPFLAGS=-I$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include \
