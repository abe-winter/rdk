#!/usr/bin/env bash
# build a static x264 distro for android

set -euxo pipefail

if [ $(uname) = Linux ]; then
	NDK_ROOT=$HOME/Android/Sdk/ndk/26.1.10909125
	HOST_OS=linux
else
	NDK_ROOT=$HOME/Library/Android/sdk/ndk/26.1.10909125
	HOST_OS=darwin
fi

API_LEVEL=29
TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/$HOST_OS-x86_64
CC=$TOOLCHAIN/bin/aarch64-linux-android$API_LEVEL-clang
# CXX=$TOOLCHAIN/bin/$CC_ARCH-linux-android$API_LEVEL-clang++
# AR=$TOOLCHAIN/bin/llvm-ar
# LD=$CC
# RANLIB=$TOOLCHAIN/bin/llvm-ranlib
# STRIP=$TOOLCHAIN/bin/llvm-strip
# NM=$TOOLCHAIN/bin/llvm-nm
SYSROOT=$TOOLCHAIN/sysroot
DIRNAME=$(realpath $(dirname $0))
PREFIX=$DIRNAME/prefix
X264_ROOT=$DIRNAME/x264

if [ ! -e $X264_ROOT ]; then
	echo checking out x264
	git clone https://code.videolan.org/videolan/x264.git -b stable $X264_ROOT
else
	echo using existing x264
fi

# todo: pass -arch armv8-a in cflags
cd $X264_ROOT && CC=$CC ./configure \
	--prefix=$PREFIX \
	--host=aarch64-linux-android \
	--cross-prefix=$TOOLCHAIN/bin/llvm- \
	--sysroot=$SYSROOT \
	--enable-shared \
	--enable-static \
	--disable-avs \
	--disable-swscale \
	--disable-lavf \
	--disable-ffms \
	--disable-gpac \
	--disable-lsmash \
&& make \
&& make install
