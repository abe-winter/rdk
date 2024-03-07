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

etc/android/prefix/%:
	TARGET_ARCH=$* etc/android/build-x264.sh

droid-rdk.%.aar: etc/android/prefix/aarch64 etc/android/prefix/x86_64
	# creates an android library that can be imported by native code
	# we clear CGO_LDFLAGS so this doesn't try (and fail) to link to linuxbrew where present
	CGO_LDFLAGS= PKG_CONFIG_PATH=$(DROID_PREFIX)/$(if $(filter arm64,$*),aarch64,x86_64)/lib/pkgconfig \
		gomobile bind -v -target android/$* -androidapi 28 -tags no_cgo \
		-o $@ ./web/cmd/droid
	rm -rf droidtmp/jni/$(if $(filter arm64,$*),arm64-v8a,x86_64)
	mkdir -p droidtmp/jni/$(if $(filter arm64,$*),arm64-v8a,x86_64)
	cp etc/android/prefix/$(if $(filter arm64,$*),aarch64,x86_64)/lib/*.so droidtmp/jni/$(if $(filter arm64,$*),arm64-v8a,x86_64)
	cd droidtmp && zip -r ../$@ jni/$(if $(filter arm64,$*),arm64-v8a,x86_64)
	cd ./services/mlmodel/tflitecpu/android/ && zip -r ../../../../$@ jni/$(if $(filter arm64,$*),arm64-v8a,x86_64)

droid-rdk.aar: droid-rdk.amd64.aar droid-rdk.arm64.aar
	# multi-platform AAR -- twice the size, but portable
	rm -rf droidtmp
	cp droid-rdk.arm64.aar $@.tmp
	unzip droid-rdk.amd64.aar -d droidtmp
	cd droidtmp && zip -r ../$@.tmp jni
	mv $@.tmp $@

clean-droid:
	# note: this doesn't clean x264 checkout
	rm -rvf droid-rdk*.aar droid-rdk*.jar etc/android/prefix droidtmp

# export PKG_CONFIG_PATH=~/viamrtsp/x264-android/lib/pkgconfig
# CC_ARCH=aarch64
# API_LEVEL=29
# NDK_ROOT=$HOME/Android/Sdk/ndk/26.1.10909125
# TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
# CC=$TOOLCHAIN/bin/$CC_ARCH-linux-android$API_LEVEL-clang

# GOOS=android GOARCH=arm64 CGO_ENABLED=1 CC=$CC \
# 	go build -v -tags no_cgo ./gostream/codec/x264
# # go build -v github.com/pion/mediadevices/pkg/codec/x264
