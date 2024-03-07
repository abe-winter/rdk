$(NDK_ROOT):
	# download ndk (used by server-android)
	cd etc && wget https://dl.google.com/android/repository/android-ndk-r26-linux.zip
	cd etc && unzip android-ndk-r26-linux.zip

.PHONY: server-android
server-android:
	GOOS=android GOARCH=arm64 CGO_ENABLED=1 \
		CC=$(shell realpath $(NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android30-clang) \
		go build -v \
		-tags no_cgo \
		-o bin/viam-server-$(BUILD_CHANNEL)-android-aarch64 \
		./web/cmd/server

# change this to just android/arm64 if you're testing locally and want faster builds
APK_ARCH ?= android/arm64

UNAME = $(shell uname)
ifeq ($(UNAME),Linux)
	PLATFORM_NDK_ROOT ?= $(HOME)/Android/Sdk/ndk/26.1.10909125
else
	PLATFORM_NDK_ROOT ?= $(HOME)/Android/Sdk/ndk/26.1.10909125
endif
DROID_CC ?= $(PLATFORM_NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android28-clang
DROID_PREFIX = $(PWD)/etc/android/prefix

droid-gostream:
	# temporary experiment
	GOOS=android CGO_ENABLED=1 GOARCH=arm64 CC=$(DROID_CC) PKG_CONFIG_PATH=$(DROID_PKG_CONFIG) \
		go build -tags no_cgo ./gostream/codec/x264

droid-rdk.amd64.aar droid-rdk.arm64.aar:
	# creates an android library that can be imported by native code
	# we clear CGO_LDFLAGS so this doesn't try (and fail) to link to linuxbrew where present
	# todo: add back tflite
	CGO_LDFLAGS= PKG_CONFIG_PATH=$(DROID_PREFIX)/aarch64/lib/pkgconfig \
		gomobile bind -v -target android/arm64 -androidapi 28 -tags no_cgo,no_tflite \
		-o droid-rdk.arm64.aar ./web/cmd/droid
	CGO_LDFLAGS= PKG_CONFIG_PATH=$(DROID_PREFIX)/x86_64/lib/pkgconfig \
		gomobile bind -v -target android/amd64 -androidapi 28 -tags no_cgo,no_tflite \
		-o droid-rdk.amd64.aar ./web/cmd/droid

droid-rdk.aar: droid-rdk.amd64.aar droid-rdk.arm64.aar
	rm -rf droidtmp
	mkdir -p droidtmp/jni/arm64-v8a droidtmp/jni/x86_64
	cp etc/android/prefix/aarch64/lib/*.so droidtmp/jni/arm64-v8a
	cp etc/android/prefix/x86_64/lib/*.so droidtmp/jni/x86_64
	unzip droid-rdk.amd64.aar -d droidtmp
	cp droid-rdk.arm64.aar $@
	cd droidtmp && zip -r ../$@ jni
	cd ./services/mlmodel/tflitecpu/android/ && zip -r ../../../../$@ jni

# export PKG_CONFIG_PATH=~/viamrtsp/x264-android/lib/pkgconfig
# CC_ARCH=aarch64
# API_LEVEL=29
# NDK_ROOT=$HOME/Android/Sdk/ndk/26.1.10909125
# TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
# CC=$TOOLCHAIN/bin/$CC_ARCH-linux-android$API_LEVEL-clang

# GOOS=android GOARCH=arm64 CGO_ENABLED=1 CC=$CC \
# 	go build -v -tags no_cgo ./gostream/codec/x264
# # go build -v github.com/pion/mediadevices/pkg/codec/x264
